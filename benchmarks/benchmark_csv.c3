// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module routing_benchmarks;

import std::io;
import std::io::path;
import std::io::file;
import std::time;
import std::core::mem::allocators;

const CSV_TIMING_DEFAULT_PATH = "out/routing_benchmarks_timing.csv";
const CSV_MEMORY_DEFAULT_PATH = "out/routing_benchmarks_memory.csv";
const CSV_TIMING_HEADER       = "benchmark,elapsed_ns";
const CSV_MEMORY_HEADER       = "benchmark,label,allocs,bytes,allocs_per_op,bytes_per_op,peak_bytes,checksum,leaked_allocs,leaked_bytes";

File timing_file;
File memory_file;
bool timing_ready;
bool memory_ready;
Clock csv_clock;

fn bool csv_open(String output_path, String header, File* file)
{
	if (try dir = output_path.path_tdirname())
	{
		if (catch err = path::mkdir(dir, true)) return false;
	}
	File? file_opt = file::open(output_path, "w");
	if (catch err = file_opt) return false;
	*file = file_opt;
	io::fprintfn(file, "%s", header);
	return true;
}

fn void csv_init(String timing_path = CSV_TIMING_DEFAULT_PATH, String memory_path = CSV_MEMORY_DEFAULT_PATH)
{
	timing_ready = csv_open(timing_path, CSV_TIMING_HEADER, &timing_file);
	memory_ready = csv_open(memory_path, CSV_MEMORY_HEADER, &memory_file);
}

fn void csv_shutdown()
{
	if (timing_ready)
	{
		timing_file.close();
		timing_ready = false;
	}
	if (memory_ready)
	{
		memory_file.close();
		memory_ready = false;
	}
}

fn void csv_write_timing(String benchmark, NanoDuration elapsed)
{
	if (!timing_ready) return;
	io::fprintfn(&timing_file, "%s,%d", benchmark, elapsed);
}

macro void start_timed()
{
	csv_clock = clock::now();
	@start_benchmark();
}

macro void end_timed()
{
	NanoDuration elapsed = csv_clock.mark();
	@end_benchmark();
	csv_write_timing($$FUNC, elapsed);
}

struct AllocSnapshot
{
	sz allocs;
	sz bytes;
}

fn AllocSnapshot alloc_snapshot(TrackingAllocator* tracker)
{
	return { .allocs = tracker.total_allocation_count(), .bytes = tracker.total_allocated() };
}

fn AllocSnapshot alloc_used(TrackingAllocator* tracker, AllocSnapshot before)
{
	return {
		.allocs = tracker.total_allocation_count() - before.allocs,
		.bytes = tracker.total_allocated() - before.bytes
	};
}

macro void log_memory_stats(String label, TrackingAllocator* tracker, AllocSnapshot before, sz ops, usz checksum)
{
	if (!memory_ready) return;
	AllocSnapshot used = alloc_used(tracker, before);
	io::fprintfn(
		&memory_file,
		"%s,%s,%d,%d,%f,%f,%d,%d,%d,%d",
		$$FUNC,
		label,
		used.allocs,
		used.bytes,
		(double)used.allocs / (double)ops,
		(double)used.bytes / (double)ops,
		tracker.max_allocated(),
		checksum,
		tracker.allocation_count(),
		tracker.allocated()
	);
}