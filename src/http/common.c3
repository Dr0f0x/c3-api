// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module c3api::http;

<*
 HTTP parsing and protocol faults.
*>
faultdef
	NO_DATA, REQUEST_TOO_LARGE, MALFORMED_REQUEST, UNSUPPORTED_VERSION, UNIMPLEMENTED, TLS_ON_HTTP_PORT
;

<*
 Fault raised when an HTTP method token cannot be parsed.
*>
faultdef INVALID_VERB;

<*
 Fault raised when a Content-Length header is malformed.
*>
faultdef INVALID_CONTENT_LENGTH;