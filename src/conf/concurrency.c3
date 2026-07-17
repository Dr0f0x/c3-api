module c3api::config;

import std::collections::object;
import std::time;

import c3api::log;
import c3api::concurrency;


struct ConcurrencyConfig
{
	ConcurrencyMode mode;

	struct thread_pool
	{
		uint max_threads;
		uint queue_capacity;
		Duration keep_alive_ms;
	}
}

const ConcurrencyConfig DEFAULT_CONCURRENCY_CONFIG = {
	.mode = ConcurrencyMode.THREAD_POOL,
	.thread_pool = { .max_threads = 32, .queue_capacity = 10000, .keep_alive_ms = (Duration)30 * time::SEC, },
};

<*
 Copy another concurrency config into this instance.

 @param [&in] other : "Source concurrency config"
 @param [&inout] allocator : "Unused, kept for API consistency"
*>
fn void ConcurrencyConfig.from_other(&self, ConcurrencyConfig* other, Allocator allocator)
{
	self.mode = other.mode;
}

<*
 Parse concurrency configuration from a JSON object.

 @param [&inout] allocator : "Unused, kept for API consistency"
 @param [&in] concurrency_obj : "JSON object containing concurrency settings"
*>
fn void ConcurrencyConfig.parse_from_object(&self, Allocator allocator, Object* concurrency_obj)
{
	@pool()
	{
		if (try mode = concurrency_obj.get_string("mode"))
		{
			self.mode = concurrency::from_string(mode) ?? DEFAULT_CONCURRENCY_CONFIG.mode;
		}
		else
		{
			self.mode = DEFAULT_CONCURRENCY_CONFIG.mode;
		}

		switch (self.mode)
		{
			case ConcurrencyMode.THREAD_POOL:
				Object* thread_pool_obj = concurrency_obj.get_or_create_obj("thread_pool");

				self.thread_pool.max_threads = thread_pool_obj.get_uint(
					"max_threads"
				) ?? DEFAULT_CONCURRENCY_CONFIG.thread_pool.max_threads;

				self.thread_pool.queue_capacity = thread_pool_obj.get_uint(
					"queue_capacity"
				) ?? DEFAULT_CONCURRENCY_CONFIG.thread_pool.queue_capacity;

				self.thread_pool.keep_alive_ms = (Duration)thread_pool_obj.get_long(
					"keep_alive_ms"
				) * time::MS ?? DEFAULT_CONCURRENCY_CONFIG.thread_pool.keep_alive_ms;
			case ConcurrencyMode.THREAD_PER_REQUEST:
			// nothing to handle
		}
	};
}

<*
 Free resources owned by this concurrency config.

 ConcurrencyConfig currently owns no dynamic memory.

 @param [&inout] allocator : "Unused, kept for API consistency"
*>
fn void ConcurrencyConfig.free(&self, Allocator allocator)
{
	// No dynamic memory to free for ConcurrencyConfig
}
