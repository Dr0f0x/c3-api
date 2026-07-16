module c3api::routing;

import std::io;
import c3api::http;

<*
 Supported HTTP methods in the routing layer.
*>
enum RouteMethod (Printable)
{
	GET,
	PATCH,
	POST,
	PUT,
	DELETE,
	HEAD,
}

<*
 Convert a route method enum value to its uppercase HTTP token.

 @return "Uppercase method token such as GET or POST"
*>
fn String RouteMethod.to_constant_string(&self) @dynamic
{
	switch (*self)
	{
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
		case HEAD:
			return "HEAD";
	}
}


<*
 Returned when an HTTP verb has no routing equivalent.
*>
faultdef UNSUPPORTED_HTTP_VERB;

<*
 Convert an [HttpVerb] to a routing [RouteMethod].

 @param verb : "HTTP verb to convert"

 @return "The corresponding routing method, or UNSUPPORTED_HTTP_VERB~ if the verb is not routable"
*>
fn RouteMethod? from_http_verb(HttpVerb verb)
{
	switch (verb)
	{
		case HttpVerb.GET: return RouteMethod.GET;
		case HttpVerb.PATCH: return RouteMethod.PATCH;
		case HttpVerb.POST: return RouteMethod.POST;
		case HttpVerb.PUT: return RouteMethod.PUT;
		case HttpVerb.DELETE: return RouteMethod.DELETE;
		case HttpVerb.HEAD: return RouteMethod.HEAD;

		default:
			return UNSUPPORTED_HTTP_VERB~;
	}
}
