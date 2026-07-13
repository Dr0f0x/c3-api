module c3api;

faultdef INVALID_VERB;

enum HttpVerb {
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