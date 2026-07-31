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

const ulong MAX_READ_SIZE = /* 5 MiB */ 1024 * 1024 * 5;

<*
 Parsed HTTP request container.
*>
struct HttpRequest
{
	HttpVerb method;
	String uri;

	headers::HttpHeaders headers;
	params::HttpQueryParams query;
	args::HttpPathArguments args;

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
	self.args.init(allocator);

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
	self.args.argument_map.clear();

	self.body = { };

	self.bytes.clear();
}

<*
 Read and parse an HTTP/1.1 request from a socket.

 @param [in] socket : "The socket to read request bytes from"
 @require socket != null : "Socket must be valid"
*>
fn void? HttpRequest.read(HttpRequest* self, TcpSocket* socket)
{
	@pool()
	{
		char[256] buffer;
		while (true)
		{
			sz? bytes_read = socket.read(&buffer);
			if (catch bytes_read)
			{
				return http::NO_DATA~;
			}

			if (bytes_read == 0)
			{
				break;
			}

			self.bytes.push_all(buffer[:bytes_read]);

			if ((ulong)self.bytes.size >= MAX_READ_SIZE)
			{
				return http::REQUEST_TOO_LARGE~;
			}

			// Stop reading once the HTTP header terminator is present
			bool found_header_terminator = false;

			if (self.bytes.size >= 4)
			{
				for (sz i = 0; i + 3 < self.bytes.size; i++)
				{
					if (self.bytes[i] == '\r' && self.bytes[i + 1] == '\n' && self.bytes[i + 2] == '\r'
						&& self.bytes[i + 3] == '\n')
					{
						found_header_terminator = true;
						break;
					}
				}
			}

			if (found_header_terminator)
			{
				break;
			}
		}

		if (self.bytes.size == 0) return http::NO_DATA~;

		if (self.bytes.size >= 3 && self.bytes[0] == 0x16 && self.bytes[1] == 0x03)
		{
			return http::TLS_ON_HTTP_PORT~;
		}

		bool found_header_terminator = false;
		sz header_end                = 0;

		sz i = 0;
		for (; i + 3 < self.bytes.size; i++)
		{
			if (self.bytes[i] == '\r' && self.bytes[i + 1] == '\n' && self.bytes[i + 2] == '\r'
				&& self.bytes[i + 3] == '\n')
			{
				header_end = i;
				found_header_terminator = true;
				break;
			}
		}

		if (!found_header_terminator) return http::MALFORMED_REQUEST~;

		sz body_end = self.bytes.size;
		if (self.bytes.entries[body_end-1] == '\0')
		{
			body_end--;
		}
		
		char[] body = self.bytes.entries[header_end + 4..body_end-1];

		List{String} header_lines;
		String headers = (String)self.bytes.entries[:header_end];
		header_lines.init_with_array(tmem, headers.tsplit("\r\n"));

		String[] status_line = header_lines.pop_first()!.tsplit(" ");
		if (status_line.len != 3) return http::MALFORMED_REQUEST~;

		String version = status_line[2];
		if (version != "HTTP/1.1") return http::UNSUPPORTED_VERSION~;

		self.method = http::parse_verb(status_line[0])!;
		self.uri = status_line[1];

		sz query_start = self.uri.index_of_char('?') ?? -1;
		if (query_start >= 0)
		{
			String query = self.uri[query_start + 1..];
			self.query.set_from_last_uri_segment(query)!;

			self.uri = self.uri[0..query_start - 1];
		}

		self.headers.set_from_lines(header_lines)!;
		self.body = body;
	};
}

<*
 Free owned request resources.

 @param [&inout] self : "The request to free"
*>
fn void HttpRequest.free(HttpRequest* self)
{
	self.headers.free();
	self.query.free();
	self.args.free();
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

	len += formatter.print(", arguments: ")!;
	len += formatter.printf("%s", self.args)!;

	len += formatter.print(", params: ")!;
	len += formatter.printf("%s", self.query)!;

	len += formatter.print(", headers: ")!;
	len += formatter.printf("%s", self.headers)!;

	len += formatter.print(", body_size: ")!;
	len += formatter.printf("%d", self.body.len)!;

	return len += formatter.print(" }")!;
}


