module c3api::log;

import std::io;
import std::time;
import std::collections::list;

<*
 Logging interface for writing plain and structured messages.
*>
interface Logger
{
	<*
	 Write a trace-level message.

	 @param [in] message : "Human-readable log message"
	 @param [in] fields : "Optional structured context"
	*>
	fn void trace(String message, Field ...fields);

	<*
	 Write a debug-level message.

	 @param [in] message : "Human-readable log message"
	 @param [in] fields : "Optional structured context"
	*>
	fn void debug(String message, Field ...fields);

	<*
	 Write an info-level message.

	 @param [in] message : "Human-readable log message"
	 @param [in] fields : "Optional structured context"
	*>
	fn void info(String message, Field ...fields);

	<*
	 Write a warn-level message.

	 @param [in] message : "Human-readable log message"
	 @param [in] fields : "Optional structured context"
	*>
	fn void warn(String message, Field ...fields);

	<*
	 Write an error-level message.

	 @param [in] message : "Human-readable log message"
	 @param [in] fields : "Optional structured context"
	*>
	fn void error(String message, Field ...fields);

	<*
	 Write a fatal-level message.

	 @param [in] message : "Human-readable log message"
	 @param [in] fields : "Optional structured context"
	*>
	fn void fatal(String message, Field ...fields);

	<*
	 Write a trace-level formatted and structured message.

	 @param [in] format_msg : "Format-string template for text output"
	 @param [in] struct_msg : "Structured message value for JSON output"
	 @param [in] fields : "Optional structured context"
	*>
	fn void tracef(String format_msg, String struct_msg, Field ...fields);

	<*
	 Write a debug-level formatted and structured message.

	 @param [in] format_msg : "Format-string template for text output"
	 @param [in] struct_msg : "Structured message value for JSON output"
	 @param [in] fields : "Optional structured context"
	*>
	fn void debugf(String format_msg, String struct_msg, Field ...fields);

	<*
	 Write an info-level formatted and structured message.

	 @param [in] format_msg : "Format-string template for text output"
	 @param [in] struct_msg : "Structured message value for JSON output"
	 @param [in] fields : "Optional structured context"
	*>
	fn void infof(String format_msg, String struct_msg, Field ...fields);

	<*
	 Write a warn-level formatted and structured message.

	 @param [in] format_msg : "Format-string template for text output"
	 @param [in] struct_msg : "Structured message value for JSON output"
	 @param [in] fields : "Optional structured context"
	*>
	fn void warnf(String format_msg, String struct_msg, Field ...fields);

	<*
	 Write an error-level formatted and structured message.

	 @param [in] format_msg : "Format-string template for text output"
	 @param [in] struct_msg : "Structured message value for JSON output"
	 @param [in] fields : "Optional structured context"
	*>
	fn void errorf(String format_msg, String struct_msg, Field ...fields);

	<*
	 Write a fatal-level formatted and structured message.

	 @param [in] format_msg : "Format-string template for text output"
	 @param [in] struct_msg : "Structured message value for JSON output"
	 @param [in] fields : "Optional structured context"
	*>
	fn void fatalf(String format_msg, String struct_msg, Field ...fields);

	<*
	 Register a sink and the enabler used to filter entries for that sink.

	 @param [&in] sink : "Sink that receives matching entries"
	 @param enabler : "Filter callback used to decide if a sink writes an entry"
	*>
	fn void add_sink(LogSink sink, EnablerFunc enabler);
}

<*
 Immutable log entry snapshot dispatched to sinks.
*>
struct LogEntry
{
	LogLevel level;
	String fmt_msg;
	String strct_msg;
	DateTime timestamp;
	Field[] fields;
}

<*
 Internal sink registration that binds a sink with its enabler.
*>
struct LogSinkRegistration
{
	LogSink sink;
	EnablerFunc enabler;
}

<*
 Default logger implementation used by the API.
*>
struct C3ApiLogger (Logger)
{
	List{LogSinkRegistration} sinks;

	Allocator allocator;
}

<*
 Initialize the logger with an allocator.

 @param [&inout] allocator : "Allocator used by internal collections"
 @return "Initialized logger instance"
*>
fn C3ApiLogger* C3ApiLogger.init(&self, Allocator allocator)
{
	self.allocator = allocator;
	return self;
}

<*
 Write a plain message at the given level.

 @param level : "Severity level for the entry"
 @param [in] message : "Human-readable log message"
 @param [in] fields : "Optional structured context"
*>
fn void C3ApiLogger.log(&self, LogLevel level, String message, Field ...fields)
{
	LogEntry entry = {
		.level = level,
		.fmt_msg = message,
		.strct_msg = message,
		.timestamp = datetime::now(),
		.fields = fields
	};
	foreach (LogSinkRegistration registration : self.sinks)
	{
		if (registration.enabler(&entry))
		{
			registration.sink.write(&entry);
		}
	}
}

<*
 Write a formatted and structured message at the given level.

 @param level : "Severity level for the entry"
 @param [in] format_msg : "Format-string template for text output"
 @param [in] struct_msg : "Structured message value for JSON output"
 @param [in] fields : "Optional structured context"
*>
fn void C3ApiLogger.logf(&self, LogLevel level, String format_msg, String struct_msg, Field ...fields)
{
	LogEntry entry = {
		.level = level,
		.fmt_msg = format_msg,
		.strct_msg = struct_msg,
		.timestamp = datetime::now(),
		.fields = fields
	};
	foreach (LogSinkRegistration registration : self.sinks)
	{
		if (registration.enabler(&entry))
		{
			registration.sink.write(&entry);
		}
	}
}

<*
 Write a trace-level message.

 @param [in] message : "Human-readable log message"
 @param [in] fields : "Optional structured context"
*>
fn void C3ApiLogger.trace(&self, String message, Field ...fields) @dynamic
{
	self.log(LogLevel.TRACE, message, ...fields);
}

<*
 Write a debug-level message.

 @param [in] message : "Human-readable log message"
 @param [in] fields : "Optional structured context"
*>
fn void C3ApiLogger.debug(&self, String message, Field ...fields) @dynamic
{
	self.log(LogLevel.DEBUG, message, ...fields);
}

<*
 Write an info-level message.

 @param [in] message : "Human-readable log message"
 @param [in] fields : "Optional structured context"
*>
fn void C3ApiLogger.info(&self, String message, Field ...fields) @dynamic
{
	self.log(LogLevel.INFO, message, ...fields);
}

<*
 Write a warn-level message.

 @param [in] message : "Human-readable log message"
 @param [in] fields : "Optional structured context"
*>
fn void C3ApiLogger.warn(&self, String message, Field ...fields) @dynamic
{
	self.log(LogLevel.WARN, message, ...fields);
}

<*
 Write an error-level message.

 @param [in] message : "Human-readable log message"
 @param [in] fields : "Optional structured context"
*>
fn void C3ApiLogger.error(&self, String message, Field ...fields) @dynamic
{
	self.log(LogLevel.ERROR, message, ...fields);
}

<*
 Write a fatal-level message.

 @param [in] message : "Human-readable log message"
 @param [in] fields : "Optional structured context"
*>
fn void C3ApiLogger.fatal(&self, String message, Field ...fields) @dynamic
{
	self.log(LogLevel.FATAL, message, ...fields);
}

<*
 Write a trace-level formatted and structured message.

 @param [in] format_msg : "Format-string template for text output"
 @param [in] struct_msg : "Structured message value for JSON output"
 @param [in] fields : "Optional structured context"
*>
fn void C3ApiLogger.tracef(&self, String format_msg, String struct_msg, Field ...fields) @dynamic
{
	self.logf(LogLevel.TRACE, format_msg, struct_msg, ...fields);
}

<*
 Write a debug-level formatted and structured message.

 @param [in] format_msg : "Format-string template for text output"
 @param [in] struct_msg : "Structured message value for JSON output"
 @param [in] fields : "Optional structured context"
*>
fn void C3ApiLogger.debugf(&self, String format_msg, String struct_msg, Field ...fields) @dynamic
{
	self.logf(LogLevel.DEBUG, format_msg, struct_msg, ...fields);
}

<*
 Write an info-level formatted and structured message.

 @param [in] format_msg : "Format-string template for text output"
 @param [in] struct_msg : "Structured message value for JSON output"
 @param [in] fields : "Optional structured context"
*>
fn void C3ApiLogger.infof(&self, String format_msg, String struct_msg, Field ...fields) @dynamic
{
	self.logf(LogLevel.INFO, format_msg, struct_msg, ...fields);
}

<*
 Write a warn-level formatted and structured message.

 @param [in] format_msg : "Format-string template for text output"
 @param [in] struct_msg : "Structured message value for JSON output"
 @param [in] fields : "Optional structured context"
*>
fn void C3ApiLogger.warnf(&self, String format_msg, String struct_msg, Field ...fields) @dynamic
{
	self.logf(LogLevel.WARN, format_msg, struct_msg, ...fields);
}

<*
 Write an error-level formatted and structured message.

 @param [in] format_msg : "Format-string template for text output"
 @param [in] struct_msg : "Structured message value for JSON output"
 @param [in] fields : "Optional structured context"
*>
fn void C3ApiLogger.errorf(&self, String format_msg, String struct_msg, Field ...fields) @dynamic
{
	self.logf(LogLevel.ERROR, format_msg, struct_msg, ...fields);
}

<*
 Write a fatal-level formatted and structured message.

 @param [in] format_msg : "Format-string template for text output"
 @param [in] struct_msg : "Structured message value for JSON output"
 @param [in] fields : "Optional structured context"
*>
fn void C3ApiLogger.fatalf(&self, String format_msg, String struct_msg, Field ...fields) @dynamic
{
	self.logf(LogLevel.FATAL, format_msg, struct_msg, ...fields);
}

<*
 Register a sink and the enabler used to filter entries for that sink.

 @param [&in] sink : "Sink that receives matching entries"
 @param enabler : "Filter callback used to decide if a sink writes an entry"
*>
fn void C3ApiLogger.add_sink(&self, LogSink sink, EnablerFunc enabler) @dynamic
{
	LogSinkRegistration registration;
	registration.sink = sink;
	registration.enabler = enabler;
	self.sinks.push(registration);
}

<*
 Free logger-owned resources.
*>
fn void C3ApiLogger.free(&self)
{
	self.sinks.free();
}
