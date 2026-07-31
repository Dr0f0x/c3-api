// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module c3api @private;

import c3api::config;
import c3api::context;

struct BuiltinMiddleware
{
	config::Config* conf;
	log::Logger log;
}

fn RequestFlow BuiltinMiddleware.cors(&self, Allocator allocator, Context* ctx, HttpRequest* req, HttpResponse* res)
{
	if (req.method == HttpVerb.OPTIONS)
	{
		res.headers.set_header_value("Access-Control-Allow-Origin", self.conf.cors.allow_origin);
		res.headers.set_header_value("Access-Control-Allow-Methods", self.conf.cors.allow_methods);
		res.headers.set_header_value("Access-Control-Allow-Headers", self.conf.cors.allow_headers);
	}
	return RequestFlow.CONTINUE;
}

fn RequestFlow BuiltinMiddleware.logging(&self, Allocator allocator, Context* ctx, HttpRequest* req, HttpResponse* res)
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

	self.log.infof(
		"%s %s | %s | %s | %s | %s | %s",
		"request",
		log::_enum("method", &req.method),
		log::_string("uri", &req.uri),
		log::_string("user_agent", &user_agent_str),
		log::_string("content_type", &content_type_str),
		log::_string("content_length", &content_length_str)
	);

	return RequestFlow.CONTINUE;
}





