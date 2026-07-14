module c3api::config;

import std::io;
import std::io::os;
import std::io::file;
import std::io::path;
import std::collections::object;
import std::encoding::json;
import std::core::string;

<*
 Application configuration.

 Contains network binding settings and nested feature-specific config sections.
*>
struct Config
{
	String address;
	uint port;

	CorsConfig cors;
	LoggingConfig logging;
}

const Config DEFAULT_CONFIG = {
	.address = "127.0.0.1",
	.port = 8080,
	.cors = DEFAULT_CORS_CONFIG,
	.logging = DEFAULT_LOGGING_CONFIG
};

<*
 Copy another config into this config instance.

 Performs deep copies for owned string fields using the provided allocator.

 @param [&in] other : "Source config to copy from"
 @param [&inout] allocator : "Allocator used for copied string fields"
*>
fn void Config.from_other(&self, Config* other, Allocator allocator)
{
	self.address = other.address.copy(allocator);
	self.port = other.port;

	CorsConfig cors;
	cors.from_other(&other.cors, allocator);
	self.cors = cors;

	LoggingConfig logging;
	logging.from_other(&other.logging, allocator);
	self.logging = logging;
}

<*
 Load configuration from `config.json` in the current working directory.

 Falls back to [DEFAULT_CONFIG] if loading or parsing fails.

 @param [&inout] allocator : "Allocator used for parsed and copied config fields"
 @param create_if_missing : "When true, writes a default config file if missing"
*>
fn void Config.from_file(&self, Allocator allocator, bool create_if_missing = true)
{
	@pool()
	{
		Path? cwd = path::tcwd();
		if (catch error = cwd)
		{
			io::eprintfn("Failed to get current working directory: %s", error);
			self.from_other(&DEFAULT_CONFIG, allocator);
			return;
		}
		Path? file = cwd.tappend("config.json");
		if (catch error = file)
		{
			io::eprintfn("Failed to get config file path: %s", error);
			self.from_other(&DEFAULT_CONFIG, allocator);
			return;
		}

		if (!path::is_file(file))
		{
			if (create_if_missing)
			{
				if (catch error = write_to_file(&DEFAULT_CONFIG))
				{
					io::eprintfn("Failed to write default config: %s", error);
				}
				self.from_other(&DEFAULT_CONFIG, allocator);
				return;
			}
			else
			{
				io::eprintfn("Config file not found: %s", file);
				self.from_other(&DEFAULT_CONFIG, allocator);
				return;
			}
		}

		if (catch error = self.parse_from_file(allocator, file))
		{
			io::eprintfn("Failed to parse config: %s", error);
			self.from_other(&DEFAULT_CONFIG, allocator);
			return;
		}
	};
}

<*
 Write a config instance to `config.json` in the current working directory.

 @param [&in] config : "Config data to serialize and write"
*>
fn void? write_to_file(Config* config)
{
	@pool()
	{
		Path path = path::tcwd()!;
		path = path.tappend("config.json")!;

		File file = file::open_path(path, "w")!;

		String json_str = json::marshal(tmem, *config, indent: Indent.SPACE_2);
		file.write(json_str)!!;
		file.flush()!;
		file.close()!;
	};
}

<*
 Parse a config file and populate this config instance.

 @param [&inout] allocator : "Allocator used for copied string fields"
 @param [in] path : "Path to the config JSON file"
*>
fn void? Config.parse_from_file(&self, Allocator allocator, Path path)
{
	@pool()
	{
		File file = file::open_path(path, "r")!;

		sz size       = file::get_size(path)!;
		char[] buffer = alloc::new_array(tmem, char, size + 1);
		defer alloc::free(tmem, buffer);

		sz read = file.read(buffer)!!;
		buffer[read] = 0;

		String content = (String)buffer[:read];
		Object* json   = json::tparse(content)!!;
		file.close()!;

		String parsed_address = json.get_string("address") ?? DEFAULT_CONFIG.address;

		self.address = parsed_address.copy(allocator);
		self.port = json.get_uint("port") ?? DEFAULT_CONFIG.port;

		CorsConfig cors;
		cors.parse_from_object(allocator, json.get_or_create_obj("cors"));
		self.cors = cors;

		LoggingConfig logging;
		logging.parse_from_object(allocator, json.get_or_create_obj("logging"));
		self.logging = logging;
	};
}

<*
 Free dynamically allocated resources owned by this config instance.

 @param [&inout] allocator : "Allocator used for previously allocated fields"
*>
fn void Config.free(&self, Allocator allocator)
{
	alloc::free(allocator, self.address);
	self.cors.free(allocator);
	self.logging.free(allocator);
}
