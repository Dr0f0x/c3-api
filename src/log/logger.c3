module c3api::log;

import std::io;
import std::time;
import std::collections::list;

interface Logger
{
	fn void trace(String message, Field ...fields);

	fn void debug(String message, Field ...fields);

	fn void info(String message, Field ...fields);

	fn void warn(String message, Field ...fields);

	fn void error(String message, Field ...fields);

	fn void fatal(String message, Field ...fields);

	fn void tracef(String format_msg, String struct_msg, Field ...fields);

	fn void debugf(String format_msg, String struct_msg, Field ...fields);

	fn void infof(String format_msg, String struct_msg, Field ...fields);

	fn void warnf(String format_msg, String struct_msg, Field ...fields);

	fn void errorf(String format_msg, String struct_msg, Field ...fields);

	fn void fatalf(String format_msg, String struct_msg, Field ...fields);

	fn void add_sink(LogSink sink, EnablerFunc enabler);
}

struct LogEntry
{
	LogLevel level;
	String fmt_msg;
	String strct_msg;
	DateTime timestamp;
	Field[] fields;
}

struct LogSinkRegistration
{
	LogSink sink;
	EnablerFunc enabler;
}

struct C3ApiLogger (Logger)
{
	List{LogSinkRegistration} sinks;

	Allocator allocator;
}

fn C3ApiLogger* C3ApiLogger.init(&self, Allocator allocator)
{
	self.allocator = allocator;
	return self;
}

fn void C3ApiLogger.log(&self, LogLevel level, String message, Field ...fields)
{
	LogEntry entry = { .level = level, .fmt_msg = message, .strct_msg = message, .timestamp = datetime::now(), .fields = fields };
	foreach (LogSinkRegistration registration : self.sinks)
	{
		if (registration.enabler(&entry))
		{
			registration.sink.write(&entry);
		}
	}
}

fn void C3ApiLogger.logf(&self, LogLevel level, String format_msg, String struct_msg, Field ...fields)
{
	LogEntry entry = { .level = level, .fmt_msg = format_msg, .strct_msg = struct_msg, .timestamp = datetime::now(), .fields = fields};
	foreach (LogSinkRegistration registration : self.sinks)
	{
		if (registration.enabler(&entry))
		{
			registration.sink.write(&entry);
		}
	}
}

fn void C3ApiLogger.trace(&self, String message, Field ...fields) @dynamic
{
	self.log(LogLevel.TRACE, message, ...fields);
}

fn void C3ApiLogger.debug(&self, String message, Field ...fields) @dynamic
{
	self.log(LogLevel.DEBUG, message, ...fields);
}

fn void C3ApiLogger.info(&self, String message, Field ...fields) @dynamic
{
	self.log(LogLevel.INFO, message, ...fields);
}

fn void C3ApiLogger.warn(&self, String message, Field ...fields) @dynamic
{
	self.log(LogLevel.WARN, message, ...fields);
}

fn void C3ApiLogger.error(&self, String message, Field ...fields) @dynamic
{
	self.log(LogLevel.ERROR, message, ...fields);
}

fn void C3ApiLogger.fatal(&self, String message, Field ...fields) @dynamic
{
	self.log(LogLevel.FATAL, message, ...fields);
}

fn void C3ApiLogger.tracef(&self, String format_msg, String struct_msg, Field ...fields) @dynamic
{
	self.logf(LogLevel.TRACE, format_msg, struct_msg, ...fields);
}

fn void C3ApiLogger.debugf(&self, String format_msg, String struct_msg, Field ...fields) @dynamic
{
	self.logf(LogLevel.DEBUG, format_msg, struct_msg, ...fields);
}

fn void C3ApiLogger.infof(&self, String format_msg, String struct_msg, Field ...fields) @dynamic
{
	self.logf(LogLevel.INFO, format_msg, struct_msg, ...fields);
}

fn void C3ApiLogger.warnf(&self, String format_msg, String struct_msg, Field ...fields) @dynamic
{
	self.logf(LogLevel.WARN, format_msg, struct_msg, ...fields);
}

fn void C3ApiLogger.errorf(&self, String format_msg, String struct_msg, Field ...fields) @dynamic
{
	self.logf(LogLevel.ERROR, format_msg, struct_msg, ...fields);
}

fn void C3ApiLogger.fatalf(&self, String format_msg, String struct_msg, Field ...fields) @dynamic
{
	self.logf(LogLevel.FATAL, format_msg, struct_msg, ...fields);
}

fn void C3ApiLogger.add_sink(&self, LogSink sink, EnablerFunc enabler) @dynamic
{
	LogSinkRegistration registration;
	registration.sink = sink;
	registration.enabler = enabler;
	self.sinks.push(registration);
}
