module c3api::http;

import std::io;
import std::net;
import std::collections;
import std::core::string;

const ulong MAX_READ_SIZE = /* 5 MiB */ 1024 * 1024 * 5;

<*
 Parsed HTTP request container.
*>
struct HttpRequest
{
	HttpVerb method;
	String uri;

	HttpHeaders headers;
	HttpQueryParams query;
	HttpPathArguments args;

	char[] body;

	List{char} bytes;
}

faultdef
	NO_DATA, REQUEST_TOO_LARGE, MALFORMED_REQUEST, UNSUPPORTED_VERSION, UNIMPLEMENTED, TLS_ON_HTTP_PORT;

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
		while (try sz bytes_read = socket.read(&buffer))
		{
			self.bytes.push_all(buffer[:bytes_read]);

			if ((ulong)self.bytes.size >= MAX_READ_SIZE) return http::REQUEST_TOO_LARGE~;
			if (bytes_read < 256) break;
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

		self.bytes[header_end] = '\0';

		char[] body = self.bytes.entries[header_end + 4..self.bytes.size];

		List{String} header_lines;
		header_lines.init_with_array(tmem, ((ZString)self.bytes.entries).str_view().tsplit("\r\n"));

		String[] status_line = header_lines.pop_first()!.tsplit(" ");
		if (status_line.len != 3) return http::MALFORMED_REQUEST~;

		String version = status_line[2];
		if (version != "HTTP/1.1") return http::UNSUPPORTED_VERSION~;

		self.method = parse_verb(status_line[0])!;
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
