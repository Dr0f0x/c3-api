module c3api::log;

alias EnablerFunc = fn bool(LogEntry* entry);

fn bool min_level_trace_enabler(LogEntry* entry)
{
	return entry.level >= LogLevel.TRACE;
}

fn bool min_level_debug_enabler(LogEntry* entry)
{
	return entry.level >= LogLevel.DEBUG;
}

fn bool min_level_info_enabler(LogEntry* entry)
{
	return entry.level >= LogLevel.INFO;
}

fn bool min_level_warn_enabler(LogEntry* entry)
{
	return entry.level >= LogLevel.WARN;
}

fn bool min_level_error_enabler(LogEntry* entry)
{
	return entry.level >= LogLevel.ERROR;
}

fn bool min_level_fatal_enabler(LogEntry* entry)
{
	return entry.level >= LogLevel.FATAL;
}

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