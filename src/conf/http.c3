// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module c3api::config::http;

import std::collections::object;
import std::time;

<*
 HTTP configuration.

 Controls HTTP server behavior, including request tracing and
 connection keep-alive settings.
*>
struct HttpConfig
{
	bool trace_enabled;

	struct keep_alive
	{
		bool enabled;
		uint max_requests_per_connection;
		Duration idle_timeout_ms;
	}
}

const HttpConfig DEFAULT_HTTP_CONFIG = {
	.trace_enabled = false,
	.keep_alive = { .enabled = true, .max_requests_per_connection = 500, .idle_timeout_ms = (Duration)10 * time::SEC, }
};

<*
 Copy another HTTP configuration into this instance.

 @param [&in] other : "Source HTTP configuration"
 @param [&inout] allocator : "Unused, kept for API consistency"
*>
fn void HttpConfig.from_other(&self, HttpConfig* other, Allocator allocator)
{
	self.trace_enabled = other.trace_enabled;

	self.keep_alive.enabled = other.keep_alive.enabled;
	self.keep_alive.max_requests_per_connection = other.keep_alive.max_requests_per_connection;
	self.keep_alive.idle_timeout_ms = other.keep_alive.idle_timeout_ms;
}

<*
 Parse HTTP configuration from a JSON object.

 Reads request tracing and keep-alive settings from the supplied
 JSON object. Missing values fall back to the defaults.

 @param [&inout] allocator : "Unused, kept for API consistency"
 @param [&in] http_obj : "JSON object containing HTTP settings"
*>
fn void HttpConfig.parse_from_object(&self, Allocator allocator, Object* http_obj)
{
	@pool()
	{
		self.trace_enabled = http_obj.get_bool("trace_enabled") ?? false;

		Object* keep_alive_obj = http_obj.get_or_create_obj("keep_alive");
		self.keep_alive.enabled = keep_alive_obj.get_bool("enabled") ?? DEFAULT_HTTP_CONFIG.keep_alive.enabled;
		self.keep_alive.max_requests_per_connection = keep_alive_obj.get_uint(
			"max_requests_per_connection"
		) ?? DEFAULT_HTTP_CONFIG.keep_alive.max_requests_per_connection;
		self.keep_alive.idle_timeout_ms = (Duration)keep_alive_obj.get_long(
			"idle_timeout_ms"
		) * time::MS ?? DEFAULT_HTTP_CONFIG.keep_alive.idle_timeout_ms;
	};
}


<*
 Free resources owned by this HTTP configuration.

 HttpConfig currently owns no dynamic memory.

 @param [&inout] allocator : "Unused, kept for API consistency"
*>
fn void HttpConfig.free(&self, Allocator allocator)
{
	// No dynamic memory to free for HttpConfig
}





