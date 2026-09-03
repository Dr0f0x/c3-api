// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module c3api::http::v1;

import std::net::tcp;
import std::collections::list;
import std::io;

import c3api::http::response;

<*
 Serialize and write an HTTP/1.1 response.
 @param res : "Response to serialize"
 @param socket : "Destination socket"
 @return "Success or a socket write error"
*>
fn void? write_response(HttpResponse* res, TcpSocket* socket)
{
	@pool()
	{
		List{char} bytes;
		bytes.init(tmem, 256);

		bytes.push_all(string::tformat("HTTP/1.1 %d %s\r\n", res.status.code, res.status.message));
		Formatter formatter;

		if (res.body.len > 0)
		{
			res.headers.set_header_values("Content-Length", string::tformat("%d", res.body.len));
		}

		res.headers.@each(; String key, List{String} values)
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

		if (res.body.len > 0)
		{
			write_all(socket, res.body)!;
		}
	};
}

<*
 Write a complete byte array to the Socket

 @param [&in] socket : " The Socket to write to"
 @param [in] bytes : "array of bytes to write"
 @return "Success or a socket write error"
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