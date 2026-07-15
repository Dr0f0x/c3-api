module c3api::http;

import std::io;
import std::net;
import std::collections;
import std::core::string;
import std::core::dstring;

<*
 HTTP response container.
*>
struct HttpResponse (Printable)
{
	HttpStatus status;
	HttpHeaders headers;
	char[] body;

	List{char} bytes;
}

fn HttpResponse* HttpResponse.init(&self, Allocator allocator)
{
	self.status = HttpStatus.UNKNOWN;
	self.headers.init(allocator);
	self.body = { };
	self.bytes.init(allocator, 256);
	return self;
}

<*
 Serialize and write this response to a socket.

 Writes the status line, headers and optional body.

 @param [&inout] self : "The response to write"
 @param [in] socket : "Destination socket"
 @require socket != null : "Socket must be valid"
*>
fn void? HttpResponse.write(HttpResponse* self, TcpSocket* socket)
{
	@pool()
	{
		self.bytes.push_all(string::tformat("HTTP/1.1 %d %s\r\n", self.status.code, self.status.message));
		Formatter formatter;

		if (self.body.len > 0)
		{
			self.headers.set_header_values("Content-Length", string::tformat("%d", self.body.len));
		}

		self.headers.@each(; String key, List{String} values)
		{
			foreach (value : values)
			{
				self.bytes.push_all(string::tformat("%s: %s\r\n", key, value));
			}
		};

		if (self.headers.len() > 0)
		{
			self.bytes.push_all("\r\n");
		}

		socket.write(self.bytes.array_view())!;

		if (self.body.len > 0)
		{
			socket.write(self.body)!;
		}
	};
}

<*
 Free owned response resources.

 @param [&inout] self : "The response to free"
*>
fn void HttpResponse.free(HttpResponse* self)
{
	self.headers.free();
	self.bytes.free();

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