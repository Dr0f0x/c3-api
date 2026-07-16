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
POST_TEST_OBSERVE_SECONDS = 60


# ---------------------------
# Monitoring
# ---------------------------

samples = []
stop_monitor = False


def monitor_process(proc: psutil.Process):
    proc.cpu_percent()

    while not stop_monitor:
        try:
            memory_mb = proc.memory_info().rss / (1024 * 1024)
            cpu = proc.cpu_percent()

            ts = time.time()

            samples.append(
                {"timestamp": ts, "memory_mb": memory_mb, "cpu_percent": cpu}
            )

            print(f"[MONITOR] MEM={memory_mb:8.2f} MB  CPU={cpu:6.2f}%")

        except psutil.NoSuchProcess, psutil.AccessDenied:
            break

        time.sleep(SAMPLE_INTERVAL)


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

    try:
        print("Starting server...")

        server = subprocess.Popen(
            [SERVER_EXE], creationflags=subprocess.CREATE_NEW_CONSOLE
        )

        time.sleep(3)

        if server.poll() is not None:
            print(f"Server failed to start. Exit code: {server.returncode}")
            return

        print("Server started successfully.")

        process = psutil.Process(server.pid)

        baseline_memory = process.memory_info().rss / (1024 * 1024)

        print(f"Baseline memory: {baseline_memory:.2f} MB")

        monitor_thread = threading.Thread(
            target=monitor_process, args=(process,), daemon=True
        )

        monitor_thread.start()

        print("Running Bombardier...")

        bombardier = subprocess.Popen(
            BOMBARDIER_CMD, creationflags=subprocess.CREATE_NO_WINDOW
        )

        if bombardier.poll() is not None:
            print(f"Bombardier failed to start. Exit code: {bombardier.returncode}")
            return

        while bombardier.poll() is None:
            time.sleep(0.5)

        print(f"\nWatching memory for {POST_TEST_OBSERVE_SECONDS}s after load...")
        time.sleep(POST_TEST_OBSERVE_SECONDS)

        stop_monitor = True
        monitor_thread.join()

        print("\n=== BOMBARDIER OUTPUT ===\n")
        if bombardier:
            print(bombardier.stdout)
            print(bombardier.stderr)

        peak_memory = max(x["memory_mb"] for x in samples)
        final_memory = samples[-1]["memory_mb"]

        print("\n========== LEAK CHECK ==========")
        print(f"Baseline Memory : {baseline_memory:.2f} MB")
        print(f"Peak Memory     : {peak_memory:.2f} MB")
        print(f"Final Memory    : {final_memory:.2f} MB")
        print(f"Difference      : {final_memory - baseline_memory:.2f} MB")

        if final_memory <= baseline_memory * 1.10:
            print("PASS: Memory returned near baseline.")
        elif final_memory <= baseline_memory * 1.30:
            print("WARNING: Moderate residual memory growth.")
        else:
            print("FAIL: Possible memory leak.")

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

        if monitor_thread.is_alive():
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
