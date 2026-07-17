module c3api::config;

import std::collections::object;
import c3api::log;

<*
 Logging configuration.

 Defines the minimum log level emitted by the application.
*>
struct LoggingConfig
{
	struct console
	{
		bool enabled;
		log::LogLevel min_level;
	}
	struct file
	{
		bool enabled;
		log::LogLevel min_level;
	}
}

const LoggingConfig DEFAULT_LOGGING_CONFIG = {
	.console = { .enabled = true, .min_level = log::LogLevel.INFO, },
	.file = { .enabled = false, .min_level = log::LogLevel.INFO, }
};

<*
 Copy another logging config into this instance.

 @param [&in] other : "Source logging config"
 @param [&inout] allocator : "Unused, kept for API consistency"
*>
fn void LoggingConfig.from_other(&self, LoggingConfig* other, Allocator allocator)
{
	self.console.enabled = other.console.enabled;
	self.console.min_level = other.console.min_level;
	self.file.enabled = other.file.enabled;
	self.file.min_level = other.file.min_level;
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
		Object* console_obj = logging_obj.get_or_create_obj("console");
		self.console.enabled = console_obj.get_bool("enabled") ?? DEFAULT_LOGGING_CONFIG.console.enabled;

		if (try console_min_level = console_obj.get_string("min_level"))
		{
			self.console.min_level = log::from_string(console_min_level) ?? DEFAULT_LOGGING_CONFIG.console.min_level;
		}
		else
		{
			self.console.min_level = DEFAULT_LOGGING_CONFIG.console.min_level;
		}

		Object* file_obj = logging_obj.get_or_create_obj("file");
		self.file.enabled = file_obj.get_bool("enabled") ?? DEFAULT_LOGGING_CONFIG.file.enabled;

		if (try file_min_level = file_obj.get_string("min_level"))
		{
			self.file.min_level = log::from_string(file_min_level) ?? DEFAULT_LOGGING_CONFIG.file.min_level;
		}
		else
		{
			self.file.min_level = DEFAULT_LOGGING_CONFIG.file.min_level;
		}
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
