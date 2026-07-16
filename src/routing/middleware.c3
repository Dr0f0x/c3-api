module c3api::routing;

import c3api::http;

enum RequestFlow
{
	CONTINUE,
	INTERRUPT,
}

alias MiddlewareFunc = fn RequestFlow(Allocator allocator, HttpRequest*, HttpResponse*);