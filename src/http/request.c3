// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module c3api::http::request;

import std::io;
import std::net;
import std::collections;
import std::core::string;

import c3api::http::headers;
import c3api::http::params;
import c3api::http::args;
import c3api::http::v1;
import c3api::encoding;
import c3api::encoding::form;
import c3api::encoding::xml;
import c3api::encoding::json;

<*
 Parsed HTTP request container.
*>
struct HttpRequest
{
	HttpVerb method;
	String uri;

	headers::HttpHeaders headers;
	params::HttpQueryParams query;
	args::HttpPathParams params;

	char[] body;

	List{char} bytes;
}

<*
 Initialize an HTTP request container with an allocator.

 @param [&inout] allocator : "Allocator to use for internal allocations"
 @return "The initialized request container"
*>
fn HttpRequest* HttpRequest.init(&self, Allocator allocator)
{
	self.method = HttpVerb.UNKNOWN;
	self.uri = "";
	self.headers.init(allocator);
	self.query.init(allocator);
	self.params.init(allocator);

	self.body = { };
	self.bytes.init(allocator, 256);
	return self;
}

fn void HttpRequest.reset(HttpRequest* self)
{
	self.method = HttpVerb.UNKNOWN;
	self.uri = "";

	self.headers.header_map.clear();
	self.query.param_map.clear();
	self.params.param_map.clear();

	self.body = { };

	self.bytes.clear();
}

<*
 Read and parse an HTTP/1.1 request from a socket.

 @param [in] socket : "The socket to read request bytes from"
 @require socket != null : "Socket must be valid"
*>
fn void? HttpRequest.read(HttpRequest* self, TcpSocket* socket, ulong max_read_size, sz version)
{
	switch (version)
	{
		case 1:
			http::v1::read_request(self, socket, max_read_size)!;
		default:
			return http::UNSUPPORTED_VERSION~;
	}
}

<*
 Free owned request resources.

 @param [&inout] self : "The request to free"
*>
fn void HttpRequest.free(HttpRequest* self)
{
	self.headers.free();
	self.query.free();
	self.params.free();
	self.bytes.free();

	self.uri = "";
	self.body = { };
	self.method = HttpVerb.UNKNOWN;
}

fn sz? HttpRequest.to_format(&self, Formatter* formatter) @dynamic
{
	sz len = formatter.print("HttpRequest { ")!;

	len += formatter.print("method: ")!;
	len += formatter.printf("%s", self.method)!;

	len += formatter.print(", uri: ")!;
	len += formatter.print(self.uri)!;

	len += formatter.print(", path params: ")!;
	len += formatter.printf("%s", self.params)!;

	len += formatter.print(", query params: ")!;
	len += formatter.printf("%s", self.query)!;

	len += formatter.print(", headers: ")!;
	len += formatter.printf("%s", self.headers)!;

	len += formatter.print(", body_size: ")!;
	len += formatter.printf("%d", self.body.len)!;

	return len += formatter.print(" }")!;
}

<*
 @require Type::kind == STRUCT : "Expected a struct type"
 @require json::may_serialize(Type) : "Expected a serializable type"
*>
fn Type*? from_json(HttpRequest* req, Allocator allocator)<Type>
{
	Type* obj = alloc::new(allocator, Type);
	encoding::bind_json{Type}(allocator, obj, req.body)!;
	return obj;
}

<*
 @require Type::kind == STRUCT : "Expected a struct type"
 @require xml::may_serialize(Type) : "Expected a serializable type"
*>
fn Type*? from_xml(HttpRequest* req, Allocator allocator)<Type>
{
	Type* obj = alloc::new(allocator, Type);
	encoding::bind_xml{Type}(allocator, obj, req.body)!;
	return obj;
}

<*
 @require Type::kind == STRUCT : "Expected a struct type"
 @require form::may_serialize(Type) : "Expected a serializable type"
*>
fn Type*? from_form(HttpRequest* req, Allocator allocator)<Type>
{
	Type* obj = alloc::new(allocator, Type);
	if (req.method == HttpVerb.GET)
	{
		encoding::bind_form_query_params{Type}(allocator, obj, &req.query)!;
	}
	else
	{
		encoding::bind_form{Type}(allocator, obj, req.body)!;
	}
	return obj;
}
