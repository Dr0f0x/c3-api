module c3api::log;

enum LogLevel : int (String name, String name_upper)
{
	TRACE { "Trace", "TRACE" },
	DEBUG { "Debug", "DEBUG" },
	INFO  { "Info", "INFO" },
	WARN  { "Warn", "WARN" },
	ERROR { "Error", "ERROR" },
	FATAL { "Fatal", "FATAL" }
}
