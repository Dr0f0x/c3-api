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
}

fn HttpResponse* HttpResponse.init(&self, Allocator allocator)
{
	self.status = HttpStatus.UNKNOWN;
	self.headers.init(allocator);
	self.body = { };
	return self;
}

<*
 Serialize and write this response to a socket.

 Writes the status line, headers and optional body.

 @param [&inout] self : "The response to write"
 @param [in] socket : "Destination socket"
 @require socket != null : "Socket must be valid"
*>
fn void? HttpResponse.write(&self, TcpSocket* socket)
{
	@pool()
	{
		List{char} bytes;
		bytes.init(tmem, 256);

		bytes.push_all(string::tformat("HTTP/1.1 %d %s\r\n", self.status.code, self.status.message));
		Formatter formatter;

		if (self.body.len > 0)
		{
			self.headers.set_header_values("Content-Length", string::tformat("%d", self.body.len));
		}

		self.headers.@each(; String key, List{String} values)
		{
			// set cookie needs to be handled differently (each value on new line)
			if (key == "Set-Cookie")
			{
				foreach (value : values)
				{
					bytes.push_all(string::tformat("%s: %s\r\n", key, value));
				}
			}
			else
			{
				DString vals = dstring::temp();

				bool first = true;
				foreach (value : values)
				{
					if (!first) vals.append(", ");
					vals.append(value);
					first = false;
				}

				bytes.push_all(string::tformat("%s: %s\r\n", key, vals.str_view()));
			}
		};

		bytes.push_all("\r\n");

		write_all(socket, bytes.array_view())!;

		if (self.body.len > 0)
		{
			write_all(socket, self.body)!;
		}
	};
}

faultdef NO_DATA_WRITTEN;

<*
 Write a complete byte array to the Socket

 @param [&in] socket : " The Socket to write to"
 @param [in] bytes : "array of bytes to write"
*>
fn void? write_all(Socket* socket, char[] bytes) @private
{
	sz total = 0;

	while (total < bytes.len)
	{
		sz written = socket.write(bytes[total..])!;
		total += written;
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
