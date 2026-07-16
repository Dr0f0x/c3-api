module c3api::log;

<*
 Log severity levels in ascending order.

 The string fields provide display-friendly and uppercase names.
*>
enum LogLevel : int (String name, String name_upper)
{
	TRACE { "Trace", "TRACE" },
	DEBUG { "Debug", "DEBUG" },
	INFO  { "Info", "INFO" },
	WARN  { "Warn", "WARN" },
	ERROR { "Error", "ERROR" },
	FATAL { "Fatal", "FATAL" }
}

faultdef INVALID_LOG_LEVEL;

<*
 Parse an loglevel token into a [LogLevel].

 @param [in] str : "The loglevel token from the request line"
 @return "A parsed [LogLevel] value"
*>
fn LogLevel? from_string(String str)
{
	switch (str)
	{
		case "Trace": return LogLevel.TRACE;
		case "Debug": return LogLevel.DEBUG;
		case "Info": return LogLevel.INFO;
		case "Warn": return LogLevel.WARN;
		case "Error": return LogLevel.ERROR;
		case "Fatal": return LogLevel.FATAL;
		default:
			return INVALID_LOG_LEVEL~;
	}
}
