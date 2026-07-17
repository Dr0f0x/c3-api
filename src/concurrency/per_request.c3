module c3api::concurrency;

import std::thread;

import c3api::log;

struct PerRequestDispatcher
{
	concurrency::ThreadPool threads;

	log::Logger log;
}


fn void? PerRequestDispatcher.init(&self, Allocator allocator, log::Logger log)
{
	self.log = log;
}


fn void? PerRequestDispatcher.dispatch(&self, RequestProcessFunc process_fn, ProcessContext* context)
{
	thread::Thread thread;

	if (catch err = thread.create((ThreadFn)process_fn , context))
	{
		self.log.errorf("Thread creation failed: %s", "thread creation failed", log::_error(&err));
		return err~;
	}

	if (catch err = thread.detach())
	{
		// dont rethrow error here as thread is already running
		self.log.errorf("Couldnt detach thread %s", "Thread detaching failed", log::_error(&err));
	}
}

fn void PerRequestDispatcher.destroy(&self)
{
	// no-op
}
