module c3api::config;

import std::collections::object;
import c3api::log;

<*
 Logging configuration.

 Defines the minimum log level emitted by the application.
*>
struct LoggingConfig
{
	log::LogLevel level;
}

const LoggingConfig DEFAULT_LOGGING_CONFIG = {
	.level = log::LogLevel.INFO,
};

<*
 Copy another logging config into this instance.

 @param [&in] other : "Source logging config"
 @param [&inout] allocator : "Unused, kept for API consistency"
*> 
fn void LoggingConfig.from_other(&self, LoggingConfig* other, Allocator allocator)
{
	self.level = other.level;
}

<*
 Parse logging configuration from a JSON object.

 @param [&inout] allocator : "Unused, kept for API consistency"
 @param [&in] logging_obj : "JSON object containing logging settings"
*>
fn void LoggingConfig.parse_from_object(&self, Allocator allocator, Object* logging_obj)
{
	@pool()
	{
		self.level = logging_obj.get_enum(log::LogLevel, "level") ?? DEFAULT_LOGGING_CONFIG.level;
	};
}

<*
 Free resources owned by this logging config.

 LoggingConfig currently owns no dynamic memory.

 @param [&inout] allocator : "Unused, kept for API consistency"
*>
fn void LoggingConfig.free(&self, Allocator allocator)
{
	// No dynamic memory to free for LoggingConfig
}