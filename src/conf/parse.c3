module c3api::config @private;

import c3api::log;
import c3api::concurrency;

faultdef INVALID_LOG_LEVEL;

<*
 Parse an loglevel token into a [LogLevel].

 @param [in] str : "The loglevel token from the request line"
 @return "A parsed [LogLevel] value"
*>
fn LogLevel? parse_log_level(String str)
{
	switch (str)
	{
		case "TRACE": return LogLevel.TRACE;
		case "DEBUG": return LogLevel.DEBUG;
		case "INFO": return LogLevel.INFO;
		case "WARN": return LogLevel.WARN;
		case "ERROR": return LogLevel.ERROR;
		case "FATAL": return LogLevel.FATAL;
		default:
			return INVALID_LOG_LEVEL~;
	}
}

faultdef INVALID_CONCURRENCY_MODE;

fn ConcurrencyMode? parse_concurrency_mode(String str)
{
	switch (str)
	{
		case "THREAD_POOL": return ConcurrencyMode.THREAD_POOL;
		case "THREAD_PER_REQUEST": return ConcurrencyMode.THREAD_PER_REQUEST;
		default:
			return INVALID_CONCURRENCY_MODE~;
	}
}