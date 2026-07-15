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
