// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module c3api::concurrency::pool;

import std::time;
import std::thread;
import std::io;

import c3api::log;

struct PoolDispatcher
{
	pool::ThreadPool threads;

	log::Logger log;
}

fn void? PoolDispatcher.init(
	&self,
	Allocator allocator,
	int max_threads,
	sz queue_capacity,
	Duration keep_alive,
	log::Logger logger
)
{
	self.threads.init(allocator, max_threads, queue_capacity, keep_alive,)!;
	self.log = logger;
}


fn void? PoolDispatcher.dispatch(&self, ThreadPoolTaskFn process_fn, void* context)
{
	return self.threads.add_task(process_fn, context);
}

fn void? PoolDispatcher.try_dispatch(&self, ThreadPoolTaskFn process_fn, void* context)
{
	return self.threads.try_add_task(process_fn, context);
}

fn void PoolDispatcher.destroy(&self)
{
	self.threads.destroy();
}
