module c3api::log;

<*
 Log entry filter callback used by log sinks.

 Return true to allow writing the entry to a sink, false to skip it.
*>
alias EnablerFunc = fn bool(LogEntry* entry);

fn bool min_level_trace_enabler(LogEntry* entry) @private
{
	return entry.level >= LogLevel.TRACE;
}

fn bool min_level_debug_enabler(LogEntry* entry) @private
{
	return entry.level >= LogLevel.DEBUG;
}

fn bool min_level_info_enabler(LogEntry* entry) @private
{
	return entry.level >= LogLevel.INFO;
}

fn bool min_level_warn_enabler(LogEntry* entry) @private
{
	return entry.level >= LogLevel.WARN;
}

fn bool min_level_error_enabler(LogEntry* entry) @private
{
	return entry.level >= LogLevel.ERROR;
}

fn bool min_level_fatal_enabler(LogEntry* entry) @private
{
	return entry.level >= LogLevel.FATAL;
}

<*
 Create an enabler that only allows entries at or above the provided level.

 @param min_level : "Minimum log level required to pass"
 @return "An enabler function matching the chosen threshold"
*>
fn EnablerFunc min_level_enabler(LogLevel min_level)
{
	switch (min_level)
	{
		case LogLevel.TRACE: return &min_level_trace_enabler;
		case LogLevel.DEBUG: return &min_level_debug_enabler;
		case LogLevel.INFO:  return &min_level_info_enabler;
		case LogLevel.WARN:  return &min_level_warn_enabler;
		case LogLevel.ERROR: return &min_level_error_enabler;
		case LogLevel.FATAL: return &min_level_fatal_enabler;
	}
}