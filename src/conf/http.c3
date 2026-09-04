// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module c3api::config;

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
	ulong max_read_size;

	struct keep_alive
	{
		bool enabled;
		uint max_requests_per_connection;
		Duration idle_timeout_ms;
	}
}

const HttpConfig DEFAULT_HTTP_CONFIG = {
	.trace_enabled = false,
	.max_read_size = 1024 * 1024 * 5, /* 5 MiB */
	.keep_alive = {
		.enabled = true,
		.max_requests_per_connection = 500,
		.idle_timeout_ms = (Duration)((10 * time::SEC) / time::MS),
	}
};

<*
 Copy another HTTP configuration into this instance.

 @param [&in] other : "Source HTTP configuration"
 @param [&inout] allocator : "Unused, kept for API consistency"
*>
fn void HttpConfig.from_other(&self, HttpConfig* other, Allocator allocator)
{
	self.trace_enabled = other.trace_enabled;
	self.max_read_size = other.max_read_size;

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
		self.trace_enabled = get_or_default{bool}(http_obj, "trace_enabled", DEFAULT_HTTP_CONFIG.trace_enabled);
		self.max_read_size = get_or_default{ulong}(http_obj, "max_read_size", DEFAULT_HTTP_CONFIG.max_read_size);

		Object* keep_alive_obj = http_obj.get_or_create_obj("keep_alive");

		self.keep_alive.enabled = get_or_default{bool}(
			keep_alive_obj,
			"enabled",
			DEFAULT_HTTP_CONFIG.keep_alive.enabled
		);

		self.keep_alive.max_requests_per_connection = get_or_default{uint}(
			keep_alive_obj,
			"max_requests_per_connection",
			DEFAULT_HTTP_CONFIG.keep_alive.max_requests_per_connection
		);

		self.keep_alive.idle_timeout_ms = (Duration)get_or_default{long}(
			keep_alive_obj,
			"idle_timeout_ms",
			(long)(DEFAULT_HTTP_CONFIG.keep_alive.idle_timeout_ms / time::MS)
		)
			* time::MS;
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