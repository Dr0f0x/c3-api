module c3api::http;

import std::io;

<*
 Fault raised when an HTTP method token cannot be parsed.
*>
faultdef INVALID_VERB;

<*
 Supported HTTP request methods.
*>
enum HttpVerb (Printable)
{
	UNKNOWN,
	HEAD,
	GET,
	PATCH,
	POST,
	PUT,
	DELETE,
	OPTIONS,
	TRACE,
	CONNECT
}

fn String HttpVerb.to_constant_string(&self) @dynamic
{
	switch (*self)
	{
		case UNKNOWN:
			return "UNKNOWN";
		case HEAD:
			return "HEAD";
		case GET:
			return "GET";
		case PATCH:
			return "PATCH";
		case POST:
			return "POST";
		case PUT:
			return "PUT";
		case DELETE:
			return "DELETE";
		case OPTIONS:
			return "OPTIONS";
		case TRACE:
			return "TRACE";
		case CONNECT:
			return "CONNECT";
	}
}

<*
 Parse an HTTP verb token into a [HttpVerb].

 @param [in] verb : "The request method token from the request line"
 @return "A parsed [HttpVerb] value"
*>
fn HttpVerb? parse_verb(String verb)
{
	switch (verb)
	{
		case "HEAD": return HttpVerb.HEAD;
		case "GET": return HttpVerb.GET;
		case "PATCH": return HttpVerb.PATCH;
		case "POST": return HttpVerb.POST;
		case "PUT": return HttpVerb.PUT;
		case "DELETE": return HttpVerb.DELETE;
		case "OPTIONS": return HttpVerb.OPTIONS;
		case "TRACE": return HttpVerb.TRACE;
		case "CONNECT": return HttpVerb.CONNECT;
		default:
			return http::INVALID_VERB~;
	}
}