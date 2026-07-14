module c3api::http;

<*
 Fault raised when an HTTP method token cannot be parsed.
*>
faultdef INVALID_VERB;

<*
 Supported HTTP request methods.
*>
enum HttpVerb {
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