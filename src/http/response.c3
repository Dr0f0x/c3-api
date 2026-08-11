// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module c3api::http::response;

import std::io;
import std::net;
import std::collections;
import std::core::string;
import std::core::dstring;

import c3api::http::headers;
import c3api::http::v1;
import c3api::encoding::form;
import c3api::encoding::xml;
import c3api::encoding::json;
<*
 HTTP response container.
*>
struct HttpResponse (Printable)
{
	HttpStatus status;
	headers::HttpHeaders headers;
	char[] body;
}

fn HttpResponse* HttpResponse.init(&self, Allocator allocator)
{
	self.status = HttpStatus.UNKNOWN;
	self.headers.init(allocator);
	self.body = { };
	return self;
}

fn void HttpResponse.reset(HttpResponse* self)
{
	self.status = HttpStatus.UNKNOWN;
	self.headers.header_map.clear();
	self.body = { };
}

<*
 Serialize and write this response to a socket.

 Writes the status line, headers and optional body.

 @param [&inout] self : "The response to write"
 @param [in] socket : "Destination socket"
 @require socket != null : "Socket must be valid"
*>
fn void? HttpResponse.write(&self, TcpSocket* socket, sz version)
{
	switch (version)
	{
		case 1:
			v1::write_response(self, socket)!;
		default:
			return http::UNSUPPORTED_VERSION~;
	}
}

<*
 Free owned response resources.

 @param [&inout] self : "The response to free"
*>
fn void HttpResponse.free(&self)
{
	self.headers.free();

	self.status = HttpStatus.UNKNOWN;
	self.body = { };
}

fn sz? HttpResponse.to_format(&self, Formatter* formatter) @dynamic
{
	sz len = formatter.print("HttpResponse { ")!;

	len += formatter.print("status: ")!;
	len += formatter.printf("%s", self.status)!;

	len += formatter.print(", headers: ")!;
	len += formatter.printf("%s", self.headers)!;

	len += formatter.print(", body_size: ")!;
	len += formatter.printf("%d", self.body.len)!;

	return len += formatter.print(" }")!;
}

<*
 Set a plain text response body and Content-Type.

 @param allocator : "Allocator used to copy the text body"
 @param value : "Text response body"
*>
fn void as_text(HttpResponse* res, Allocator allocator, Printable value)<Type>
{
	res.headers.set_header_value("Content-Type", "text/plain; charset=utf-8");
	res.body = string::format(allocator, "%s", value);
}

<*
 Set a JSON response body and Content-Type.

 @param allocator : "Allocator used for the JSON payload"
 @param value : "Value to marshal as JSON"
 @param indent : "Indentation preference"
 @require Type::kind == STRUCT
 @require json::may_serialize(Type) : "Expected a serializable type"
*>
fn void as_json(HttpResponse* res, Allocator allocator, Type* value, json::Indent indent = json::Indent.NONE)<Type>
{
	res.headers.set_header_value("Content-Type", "application/json; charset=utf-8");
	res.body = json::marshal_json(allocator, *value, indent: indent);
}

<*
 Set an XML response body and Content-Type.

 @param allocator : "Allocator used for the XML payload"
 @param value : "Value to marshal as XML"
 @param root : "Root element name"
 @require Type::kind == STRUCT
 @require xml::may_serialize(Type) : "Expected a serializable type"
*>
fn void as_xml(HttpResponse* res, Allocator allocator, Type* value, String root = "response")<Type>
{
	res.headers.set_header_value("Content-Type", "application/xml; charset=utf-8");
	res.body = xml::marshal_xml(allocator, *value, root);
}

<*
 Set a form-encoded response body and Content-Type.

 @param allocator : "Allocator used for the form payload"
 @param value : "Value to marshal as form data"
 @require Type::kind == STRUCT
 @require form::may_serialize(Type) : "Expected a serializable type"
*>
fn void as_form(HttpResponse* res, Allocator allocator, Type* value)<Type>
{
	res.headers.set_header_value("Content-Type", "application/x-www-form-urlencoded; charset=utf-8");
	res.body = form::marshal_form(allocator, *value);
}