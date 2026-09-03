// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module c3api::http::v1;

import std::net::tcp;
import std::collections::list;

import c3api::http::request;
import c3api::http::headers;

<*
 Find the next CRLF sequence in a byte buffer.
 @param bytes : "Byte buffer to search"
 @param start : "Starting offset"
 @return "Offset of CRLF or -1 when absent"
*>
fn sz find_crlf(List{char}* bytes, sz start) @private
{
	if (start < 0 || start + 1 >= bytes.size) return -1;

	for (sz i = start; i + 1 < bytes.size; i++)
	{
		if (bytes.entries[i] == '\r' && bytes.entries[i + 1] == '\n')
		{
			return i;
		}
	}

	return -1;
}

<*
 Find the CRLFCRLF sequence that terminates HTTP headers.
 @param bytes : "Byte buffer to search"
 @param start : "Starting offset"
 @return "Offset of the header terminator or -1 when absent"
*>
fn sz find_header_terminator(List{char}* bytes, sz start = 0) @private
{
	if (bytes.size < 4 || start < 0) return -1;

	for (sz i = start; i + 3 < bytes.size; i++)
	{
		if (bytes.entries[i] == '\r' && bytes.entries[i + 1] == '\n' && bytes.entries[i + 2] == '\r'
			&& bytes.entries[i + 3] == '\n')
		{
			return i;
		}
	}

	return -1;
}

<*
 Parse a Content-Length header value.
 @param value : "Content-Length field value"
 @return "Parsed length or INVALID_CONTENT_LENGTH~"
*>
fn ulong? parse_content_length(String value) @private
{
	ulong parsed = 0;
	foreach (char ch : value.trim())
	{
		if (ch < '0' || ch > '9') return http::INVALID_CONTENT_LENGTH~;
		parsed = parsed * 10 + (ulong)(ch - '0');
	}
	return parsed;
}

<*
 Get the declared content length from HTTP headers.
 @param headers : "Headers to inspect"
 @return "Declared length, zero when absent, or INVALID_CONTENT_LENGTH~"
*>
fn ulong? get_content_length(headers::HttpHeaders* headers) @private
{
	if (try values = headers.get_header_values("Content-Length"))
	{
		foreach (String value : values)
		{
			return parse_content_length(value)!;
		}
	}

	return 0;
}

<*
 Check whether headers request chunked transfer encoding.
 @param headers : "Headers to inspect"
 @return "True when Transfer-Encoding includes chunked"
*>
fn bool has_chunked_transfer_encoding(headers::HttpHeaders* headers) @private
{
	if (try values = headers.get_header_values("Transfer-Encoding"))
	{
		foreach (String value : values)
		{
			foreach (String encoding : value.tsplit(","))
			{
				encoding = encoding.trim();
				if (encoding == "chunked" || encoding == "Chunked")
				{
					return true;
				}
			}
		}
	}

	return false;
}

<*
 Parse a hexadecimal HTTP chunk size.
 @param value : "Chunk size line, optionally with extensions"
 @return "Parsed size or MALFORMED_REQUEST~"
*>
fn ulong? parse_chunk_size(String value) @private
{
	String trimmed = value.trim();
	sz ext_start   = trimmed.index_of_char(';') ?? -1;
	if (ext_start >= 0)
	{
		trimmed = trimmed[0..ext_start - 1].trim();
	}

	if (trimmed == "") return http::MALFORMED_REQUEST~;

	ulong parsed = 0;
	foreach (char ch : trimmed)
	{
		parsed *= 16;
		switch (ch)
		{
			case '0'..'9':
				parsed += (ulong)(ch - '0');
			case 'a'..'f':
				parsed += (ulong)(ch - 'a' + 10);
			case 'A'..'F':
				parsed += (ulong)(ch - 'A' + 10);
			default:
				return http::MALFORMED_REQUEST~;
		}
	}

	return parsed;
}

<*
 Read another socket buffer into a request.
 @param self : "Request receiving bytes"
 @param socket : "Socket to read"
 @param max_read_size : "Maximum permitted request size"
 @return "Success or a read/size error"
*>
fn void? read_more(HttpRequest* self, TcpSocket* socket, ulong max_read_size) @private
{
	char[256] buffer;
	sz? bytes_read = socket.read(&buffer);
	if (catch bytes_read)
	{
		return http::NO_DATA~;
	}

	if (bytes_read == 0)
	{
		return http::NO_DATA~;
	}

	self.bytes.push_all(buffer[:bytes_read]);
	if ((ulong)self.bytes.size >= max_read_size)
	{
		return http::REQUEST_TOO_LARGE~;
	}
}

<*
 Read request bytes until the header terminator is present.
 @param self : "Request receiving bytes"
 @param socket : "Socket to read"
 @param max_read_size : "Maximum permitted request size"
 @return "Header terminator offset or a parsing error"
*>
fn sz? read_headers(HttpRequest* self, TcpSocket* socket, ulong max_read_size) @private
{
	while (true)
	{
		sz header_end = find_header_terminator(&self.bytes);
		if (header_end >= 0)
		{
			return header_end;
		}

		if (catch err = read_more(self, socket, max_read_size))
		{
			return http::MALFORMED_REQUEST~;
		}
	}
}

<*
 Parse a request line and header section.
 @param self : "Request to populate"
 @param header_end : "Offset of the header terminator"
 @return "Success or a malformed/unsupported request error"
*>
fn void? parse_request_head(HttpRequest* self, sz header_end) @private
{
	@pool()
	{
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
	};
}

<*
 Read a body with a declared content length.
 @param self : "Request receiving the body"
 @param socket : "Socket to read"
 @param max_read_size : "Maximum permitted request size"
 @param body_start : "Offset where the body begins"
 @param content_length : "Declared body length"
 @return "Success or a read/size error"
*>
fn void? read_fixed_length_body(
	HttpRequest* self,
	TcpSocket* socket,
	ulong max_read_size,
	sz body_start,
	ulong content_length
) @private
{
	ulong expected_total = (ulong)body_start + content_length;
	while ((ulong)self.bytes.size < expected_total)
	{
		read_more(self, socket, max_read_size)!;
	}

	if (content_length == 0)
	{
		self.body = { };
		return;
	}

	self.body = self.bytes.entries[body_start..(sz)(expected_total - 1)];
}

<*
 Read and decode a chunked HTTP body.
 @param self : "Request receiving the decoded body"
 @param socket : "Socket to read"
 @param max_read_size : "Maximum permitted request size"
 @param body_start : "Offset where chunk data begins"
 @return "Success or a malformed/read/size error"
*>
fn void? read_chunked_body(HttpRequest* self, TcpSocket* socket, ulong max_read_size, sz body_start) @private
{
	sz cursor       = body_start;
	sz write_cursor = body_start;

	while (true)
	{
		sz chunk_line_end;
		while ((chunk_line_end = find_crlf(&self.bytes, cursor)) < 0)
		{
			read_more(self, socket, max_read_size)!;
		}

		ulong chunk_size = parse_chunk_size((String)self.bytes.entries[cursor..chunk_line_end - 1])!;
		cursor = chunk_line_end + 2;

		if (chunk_size == 0)
		{
			while (true)
			{
				while (self.bytes.size < cursor + 2)
				{
					read_more(self, socket, max_read_size)!;
				}

				// Empty trailer section ends with a single CRLF after the final 0-size chunk.
				if (self.bytes.entries[cursor] == '\r' && self.bytes.entries[cursor + 1] == '\n')
				{
					break;
				}

				// Non-empty trailers are regular header lines terminated by an empty CRLF line.
				if (find_header_terminator(&self.bytes, cursor) >= 0)
				{
					break;
				}

				read_more(self, socket, max_read_size)!;
			}

			if (write_cursor == body_start)
			{
				self.body = { };
			}
			else
			{
				self.body = self.bytes.entries[body_start..write_cursor - 1];
			}
			return;
		}

		ulong chunk_end = (ulong)cursor + chunk_size;
		while ((ulong)self.bytes.size < chunk_end + 2)
		{
			read_more(self, socket, max_read_size)!;
		}

		for (sz i = 0; i < (sz)chunk_size; i++)
		{
			self.bytes.entries[write_cursor + i] = self.bytes.entries[cursor + i];
		}
		write_cursor += (sz)chunk_size;
		cursor = (sz)chunk_end;

		if (self.bytes.entries[cursor] != '\r' || self.bytes.entries[cursor + 1] != '\n')
		{
			return http::MALFORMED_REQUEST~;
		}

		cursor += 2;
	}
}

<*
 Read and parse a complete HTTP/1.1 request.
 @param req : "Request to populate"
 @param socket : "Socket to read"
 @param max_read_size : "Maximum permitted request size"
 @return "Success or an HTTP parsing error"
*>
fn void? read_request(HttpRequest* req, TcpSocket* socket, ulong max_read_size)
{
	@pool()
	{
		sz header_end = read_headers(req, socket, max_read_size)!;

		if (req.bytes.size == 0) return http::NO_DATA~;

		if (req.bytes.size >= 3 && req.bytes.entries[0] == 0x16 && req.bytes.entries[1] == 0x03)
		{
			return http::TLS_ON_HTTP_PORT~;
		}

		parse_request_head(req, header_end)!;

		sz body_start = header_end + 4;
		if (has_chunked_transfer_encoding(&req.headers))
		{
			read_chunked_body(req, socket, max_read_size, body_start)!;
		}
		else
		{
			ulong content_length = get_content_length(&req.headers)!;
			read_fixed_length_body(req, socket, max_read_size, body_start, content_length)!;
		}
	};
}