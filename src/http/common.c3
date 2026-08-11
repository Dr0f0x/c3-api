module c3api::http;


faultdef
	NO_DATA, REQUEST_TOO_LARGE, MALFORMED_REQUEST, UNSUPPORTED_VERSION, UNIMPLEMENTED, TLS_ON_HTTP_PORT
;

<*
 Fault raised when an HTTP method token cannot be parsed.
*>
faultdef INVALID_VERB;

faultdef INVALID_CONTENT_LENGTH;