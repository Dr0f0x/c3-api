// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module c3api::routing::middleware;

import c3api::http;
import c3api::context;

<*
 Middleware callback signature used by router and group pipelines.

 Invoked as part of the request processing pipeline. The middleware decides
 whether to continue by calling `ctx.next(...)`; omitting the call stops the
 pipeline before the remaining middleware and the final handler.

 @param [&inout] self : "Owning instance if the middleware was registered as a member function, otherwise null"
 @param [&inout] allocator : "Allocator available for request-scoped allocations"
 @param [&inout] ctx : "Request context"
 @param [&inout] request : "Incoming HTTP request"
 @param [&inout] response : "HTTP response being built"
*>
alias MiddlewareFunc = fn void(
	void* self = null,
	Allocator allocator,
	MiddlewareContext* ctx,
	HttpRequest* request,
	HttpResponse* response,
);

<*
 Type-safe middleware callback signature.

 Equivalent to `MiddlewareFunc`, but with a strongly typed `self` pointer
 for member-function middleware.

 @param [&inout] self : "Owning instance if registered as a member function"
 @param [&inout] allocator : "Allocator available for request-scoped allocations"
 @param [&inout] ctx : "Request context"
 @param [&inout] request : "Incoming HTTP request"
 @param [&inout] response : "HTTP response being built"
*>
alias MiddlewareFuncGen <Type> = fn void(
	Type* self = null,
	Allocator allocator,
	MiddlewareContext* ctx,
	HttpRequest* request,
	HttpResponse* response,
);

<*
 Registered middleware entry.

 Stores a middleware callback together with an optional context object.
 If the middleware was registered as a member function, `self` points to
 the owning instance. For standalone functions, `self` is `null`.
*>
struct RegisteredMiddleware
{
	void* self; /* Owning instance for member-function middleware, or null */
	MiddlewareFunc middleware; /* Middleware callback */
}