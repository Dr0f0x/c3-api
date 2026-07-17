module c3api::concurrency;

enum ConcurrencyMode
{
	THREAD_POOL,
	THREAD_PER_REQUEST,
}

faultdef INVALID_CONCURRENCY_MODE;

fn ConcurrencyMode? from_string(String str)
{
	switch (str)
	{
		case "THREAD_POOL": return ConcurrencyMode.THREAD_POOL;
		case "THREAD_PER_REQUEST": return ConcurrencyMode.THREAD_PER_REQUEST;
		default:
			return INVALID_CONCURRENCY_MODE~;
	}
}