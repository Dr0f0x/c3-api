module c3api::log;

import std::io;
import std::time;
import std::collections::list;

interface Logger
{
	fn void trace(String message);

	fn void debug(String message);

	fn void info(String message);

	fn void warn(String message);

	fn void error(String message);

	fn void fatal(String message);

	fn void tracef(String format, args...);

	fn void debugf(String format, args...);

	fn void infof(String format, args...);

	fn void warnf(String format, args...);

	fn void errorf(String format, args...);

	fn void fatalf(String format, args...);

	fn void add_sink(LogSink sink, EnablerFunc enabler);
}

struct LogEntry
{
	LogLevel level;
	String message;
	DateTime timestamp;
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

fn void C3ApiLogger.log(&self, LogLevel level, String message)
{
	LogEntry entry = { .level = level, .message = message, .timestamp = datetime::now() };
	foreach (LogSinkRegistration registration : self.sinks)
	{
		if (registration.enabler(&entry))
		{
			registration.sink.write(&entry);
		}
	}
}

fn void C3ApiLogger.logf(&self, LogLevel level, String format, args...)
{
	LogEntry entry = {
		.level = level,
		.message = string::format(self.allocator, format, ...args),
		.timestamp = datetime::now()
	};
	foreach (LogSinkRegistration registration : self.sinks)
	{
		if (registration.enabler(&entry))
		{
			registration.sink.write(&entry);
		}
	}
}

fn void C3ApiLogger.trace(&self, String message) @dynamic
{
	self.log(LogLevel.TRACE, message);
}

fn void C3ApiLogger.debug(&self, String message) @dynamic
{
	self.log(LogLevel.DEBUG, message);
}

fn void C3ApiLogger.info(&self, String message) @dynamic
{
	self.log(LogLevel.INFO, message);
}

fn void C3ApiLogger.warn(&self, String message) @dynamic
{
	self.log(LogLevel.WARN, message);
}

fn void C3ApiLogger.error(&self, String message) @dynamic
{
	self.log(LogLevel.ERROR, message);
}

fn void C3ApiLogger.fatal(&self, String message) @dynamic
{
	self.log(LogLevel.FATAL, message);
}

fn void C3ApiLogger.tracef(&self, String format, args...) @dynamic
{
	self.logf(LogLevel.TRACE, format, ...args);
}

fn void C3ApiLogger.debugf(&self, String format, args...) @dynamic
{
	self.logf(LogLevel.DEBUG, format, ...args);
}

fn void C3ApiLogger.infof(&self, String format, args...) @dynamic
{
	self.logf(LogLevel.INFO, format, ...args);
}

fn void C3ApiLogger.warnf(&self, String format, args...) @dynamic
{
	self.logf(LogLevel.WARN, format, ...args);
}

fn void C3ApiLogger.errorf(&self, String format, args...) @dynamic
{
	self.logf(LogLevel.ERROR, format, ...args);
}

fn void C3ApiLogger.fatalf(&self, String format, args...) @dynamic
{
	self.logf(LogLevel.FATAL, format, ...args);
}

fn void C3ApiLogger.add_sink(&self, LogSink sink, EnablerFunc enabler) @dynamic
{
	LogSinkRegistration registration;
	registration.sink = sink;
	registration.enabler = enabler;
	self.sinks.push(registration);
}
