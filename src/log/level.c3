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
