module c3api::concurrency;

import std::time;
import std::thread;
import std::io;

import c3api::log;

struct PoolDispatcher
{
	concurrency::ThreadPool threads;

	log::Logger log;
}

alias RequestProcessFunc = fn void(ProcessContext* context);

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


fn void? PoolDispatcher.dispatch(&self, RequestProcessFunc process_fn, ProcessContext* context)
{
	return self.threads.add_task((ThreadPoolTaskFn)process_fn, context);
}

fn void? PoolDispatcher.try_dispatch(&self, RequestProcessFunc process_fn, ProcessContext* context)
{
	return self.threads.try_add_task((ThreadPoolTaskFn)process_fn, context);
}

fn void PoolDispatcher.destroy(&self)
{
	self.threads.destroy();
}
