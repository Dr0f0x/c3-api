module c3api::routing;

import c3api::http;

<*
 Control signal returned by middleware execution.
*>
enum RequestFlow
{
	CONTINUE,
	INTERRUPT,
}

<*
 Middleware callback signature used by router and group pipelines.

 @param [&inout] allocator : "Allocator available for request-scoped work"
 @param [&inout] request : "Incoming request being processed"
 @param [&inout] response : "Response being built"
 @return "CONTINUE to keep processing, INTERRUPT to stop"
*>
alias MiddlewareFunc = fn RequestFlow(Allocator allocator, Context* ctx, HttpRequest* request, HttpResponse* response);
