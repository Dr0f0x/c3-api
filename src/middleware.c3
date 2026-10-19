// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module c3api @private;

import std::io;
import std::time;
import std::time::clock;

import c3api::config;
import c3api::context;

<*
 Built-in middleware implementations provided by the framework.

 The CORS middleware adds the configured cross-origin headers to OPTIONS
 requests, while the logging middleware reports each request once the
 pipeline has completed.
*>
struct BuiltinMiddleware
{
	config::Config* conf;
	log::Logger log;
}

<*
 Built-in CORS middleware.

 Populates the configured `Access-Control-Allow-*` headers for OPTIONS
 requests and continues the pipeline.

 @param [&inout] self : "Builtin middleware state holding the server config"
 @param [&inout] allocator : "Allocator available during the request processing"
 @param [&inout] ctx : "Middleware-facing request context"
 @param [&inout] req : "Incoming HTTP request"
 @param [&inout] res : "HTTP response being built"
*>
fn void BuiltinMiddleware.cors(&self, Allocator allocator, MiddlewareContext* ctx, HttpRequest* req, HttpResponse* res)
{
	if (req.method == HttpVerb.OPTIONS)
	{
		res.headers.set_header_value("Access-Control-Allow-Origin", self.conf.cors.allow_origin);
		res.headers.set_header_value("Access-Control-Allow-Methods", self.conf.cors.allow_methods);
		res.headers.set_header_value("Access-Control-Allow-Headers", self.conf.cors.allow_headers);
	}
	ctx.next(allocator, req, res);
}

<*
 Built-in request logging middleware.

 Collects request metadata, continues the pipeline, and logs the method, URI,
 user agent, content type, content length, and elapsed time after the rest of
 the pipeline has finished.

 @param [&inout] self : "Builtin middleware state holding the server logger"
 @param [&inout] allocator : "Allocator available during the request processing"
 @param [&inout] ctx : "Middleware-facing request context"
 @param [&inout] req : "Incoming HTTP request"
 @param [&inout] res : "HTTP response being built"
*>
fn void BuiltinMiddleware.logging(&self, Allocator allocator, MiddlewareContext* ctx, HttpRequest* req, HttpResponse* res)
{
	DString user_agent     = dstring::temp();
	DString content_type   = dstring::temp();
	DString content_length = dstring::temp();

	if (try values = req.headers.get_header_values("User-Agent"))
	{
		foreach (i, value : values)
		{
			if (i != 0) user_agent.append(", ");
			user_agent.append(value);
		}
	}

	if (try values = req.headers.get_header_values("Content-Type"))
	{
		foreach (i, value : values)
		{
			if (i != 0) content_type.append(", ");
			content_type.append(value);
		}
	}

	if (try values = req.headers.get_header_values("Content-Length"))
	{
		foreach (i, value : values)
		{
			if (i != 0) content_length.append(", ");
			content_length.append(value);
		}
	}

	String user_agent_str     = user_agent.len() ? user_agent.str_view() : "-";
	String content_type_str   = content_type.len() ? content_type.str_view() : "-";
	String content_length_str = content_length.len() ? content_length.str_view() : "-";

	Clock start = clock::now();
	ctx.next(allocator, req, res);
	long elapsed_ms = start.to_now().to_ms();

	self.log.infof(
		"%s | %s | %s | %s | %s | %d ms",
		"request",
		log::_enum("method", &req.method),
		log::_string("uri", &req.uri),
		log::_string("user_agent", &user_agent_str),
		log::_string("content_type", &content_type_str),
		log::_string("content_length", &content_length_str),
		log::_long("elapsed_ms", &elapsed_ms)
	);
}