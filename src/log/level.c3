module c3api::log;

enum LogLevel : int (String name)
{
	TRACE { "Trace" },
	DEBUG { "Debug" },
	INFO  { "Info" },
	WARN  { "Warn" },
	ERROR { "Error" },
	FATAL { "Fatal" }
}
