import subprocess
import threading
import time
import statistics
import argparse
import csv
import psutil

SERVER_EXE = "./build/c3api-demo.exe"

BOMBARDIER_CMD = [
    "bombardier",
    "-c",
    "200",
    "-d",
    "3m",
    "-l",
    "http://localhost:8080/v1/example/john",
]

SAMPLE_INTERVAL = 1.0
POST_TEST_OBSERVE_SECONDS = 30

samples = []
stop_monitor = False


def monitor_process(proc: psutil.Process):
    proc.cpu_percent()

    while not stop_monitor:
        try:
            memory_mb = proc.memory_info().rss / (1024 * 1024)
            cpu = proc.cpu_percent()
            threads = proc.num_threads()

            samples.append(
                {
                    "timestamp": time.time(),
                    "memory_mb": memory_mb,
                    "cpu_percent": cpu,
                    "threads": threads,
                }
            )

            print(
                f"[MONITOR] MEM={memory_mb:8.2f} MB  CPU={cpu:6.2f}%  THREADS={threads}"
            )

        except psutil.NoSuchProcess, psutil.AccessDenied:
            break

        time.sleep(SAMPLE_INTERVAL)


def average_recent_memory(seconds):
    now = time.time()

    values = [x["memory_mb"] for x in samples if now - x["timestamp"] <= seconds]

    return statistics.mean(values) if values else 0


def memory_growth_analysis(samples, ignore_seconds=15):
    if len(samples) < 10:
        return 0, False

    start = samples[0]["timestamp"] + ignore_seconds

    values = [x for x in samples if x["timestamp"] >= start]

    if len(values) < 10:
        return 0, False

    times = [x["timestamp"] - values[0]["timestamp"] for x in values]

    memory = [x["memory_mb"] for x in values]

    n = len(times)

    mean_x = statistics.mean(times)
    mean_y = statistics.mean(memory)

    numerator = sum((times[i] - mean_x) * (memory[i] - mean_y) for i in range(n))

    denominator = sum((times[i] - mean_x) ** 2 for i in range(n))

    if denominator == 0:
        return 0, False

    slope = numerator / denominator

    # MB per minute
    growth_per_minute = slope * 60

    # Require sustained growth
    leak = growth_per_minute > 5

    return growth_per_minute, leak


def thread_growth_analysis(samples, ignore_seconds=15):
    if len(samples) < 10:
        return 0, False

    start = samples[0]["timestamp"] + ignore_seconds

    values = [x for x in samples if x["timestamp"] >= start]

    if len(values) < 10:
        return 0, False

    times = [x["timestamp"] - values[0]["timestamp"] for x in values]

    threads = [x["threads"] for x in values]

    n = len(times)

    mean_x = statistics.mean(times)
    mean_y = statistics.mean(threads)

    numerator = sum((times[i] - mean_x) * (threads[i] - mean_y) for i in range(n))

    denominator = sum((times[i] - mean_x) ** 2 for i in range(n))

    if denominator == 0:
        return 0, False

    slope = numerator / denominator

    # threads per minute
    growth_per_minute = slope * 60

    # sustained thread creation
    leak = growth_per_minute > 1

    return growth_per_minute, leak


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--csv",
        metavar="FILE",
        help="Write metrics to the specified CSV file",
    )

    args = parser.parse_args()

    global stop_monitor

    bombardier = None
    server = None
    monitor_thread = None

    try:
        print("Starting server...")

        server = subprocess.Popen(
            [SERVER_EXE], creationflags=subprocess.CREATE_NEW_CONSOLE
        )

        time.sleep(3)

        if server.poll() is not None:
            print(f"Server failed to start. Exit code: {server.returncode}")
            return

        process = psutil.Process(server.pid)

        print("Server started successfully.")

        baseline_memory = process.memory_info().rss / (1024 * 1024)
        baseline_threads = process.num_threads()

        print(f"Baseline memory: {baseline_memory:.2f} MB")

        monitor_thread = threading.Thread(
            target=monitor_process, args=(process,), daemon=True
        )

        monitor_thread.start()

        print("Running Bombardier...")

        bombardier = subprocess.Popen(
            BOMBARDIER_CMD, creationflags=subprocess.CREATE_NEW_CONSOLE
        )

        if bombardier.poll() is not None:
            print(f"Bombardier failed to start. Exit code: {bombardier.returncode}")
            return

        while bombardier.poll() is None:
            time.sleep(0.5)

        print(f"Watching after load for {POST_TEST_OBSERVE_SECONDS}s...")
        time.sleep(POST_TEST_OBSERVE_SECONDS)

        stop_monitor = True
        monitor_thread.join()

        peak_memory = max(x["memory_mb"] for x in samples)
        final_memory = samples[-1]["memory_mb"]
        peak_threads = max(x["threads"] for x in samples)
        final_threads = samples[-1]["threads"]

        print("\n=== BOMBARDIER OUTPUT ===\n")
        if bombardier:
            print(bombardier.stdout)
            print(bombardier.stderr)

        print("\n========== MEMORY CHECK ==========")
        print(f"Baseline Memory : {baseline_memory:.2f} MB")
        print(f"Peak Memory     : {peak_memory:.2f} MB")
        print(f"Final Memory    : {final_memory:.2f} MB")
        print(f"Difference      : {final_memory - baseline_memory:.2f} MB")

        print("\n========== THREAD CHECK ==========")
        print(f"Baseline threads : {baseline_threads}")
        print(f"Peak threads     : {peak_threads}")
        print(f"Final threads    : {final_threads}")
        print(f"Difference      : {final_threads - baseline_threads}")

        thread_growth_rate, possible_thread_leak = thread_growth_analysis(samples)

        print("\n========== THREAD TREND ==========")
        print(f"Thread growth rate: {thread_growth_rate:.2f} threads/min")

        if possible_thread_leak:
            print("FAIL: Threads are continuously increasing.")
        else:
            print("PASS: Thread count appears stable.")

        growth_rate, possible_leak = memory_growth_analysis(samples)
        print("\n========== MEMORY TREND ==========")
        print(f"Memory growth rate: {growth_rate:.2f} MB/min")

        if possible_leak:
            print("FAIL: Memory is continuously increasing.")
        else:
            print("PASS: Memory appears stable.")

        avg_cpu = statistics.mean(x["cpu_percent"] for x in samples)
        avg_mem = statistics.mean(x["memory_mb"] for x in samples)

        print("\nCPU / Memory Summary")
        print("---------------------")
        print(f"Average CPU : {avg_cpu:.2f}%")
        print(f"Average MEM : {avg_mem:.2f} MB")

    except KeyboardInterrupt:
        print("\nInterrupted by user.")

    finally:
        stop_monitor = True

        if monitor_thread is not None and monitor_thread.is_alive():
            monitor_thread.join(timeout=2)

        if bombardier is not None and bombardier.poll() is None:
            print("Stopping Bombardier...")
            bombardier.terminate()

            try:
                bombardier.wait(timeout=5)
            except subprocess.TimeoutExpired:
                bombardier.kill()

        if server and server.poll() is None:
            print("Stopping server...")
            server.terminate()

            try:
                server.wait(timeout=5)
            except subprocess.TimeoutExpired:
                server.kill()

        print("Cleanup complete.")

        if server:
            server.terminate()

        if args.csv:
            with open(args.csv, "w", newline="") as f:
                writer = csv.DictWriter(
                    f,
                    fieldnames=[
                        "timestamp",
                        "memory_mb",
                        "cpu_percent",
                    ],
                )

                writer.writeheader()
                writer.writerows(samples)

            print(f"\nMetrics written to: {args.csv}")


if __name__ == "__main__":
    main()
