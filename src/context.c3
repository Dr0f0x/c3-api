// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module c3api::context;

import std::io;
import std::collections::map;
import c3api::http::request;
import c3api::http::response;
import c3api::routing::middleware;
import c3api::routing::handler;

struct Context (Printable)
{
	HashMap{typeid, void*} objects;
	HashMap{String, void*} map;

	RegisteredMiddleware[] middlewares;
	RegisteredHandler* handler;
	uint middleware_idx;
}

<*
 Handler-facing view of the request pipeline.

 Exposes the shared request state without access to pipeline setup or
 continuation, so route handlers cannot advance the middleware chain.
*>
struct HandlerContext (Printable)
{
	Context* context;
}

<*
 Server-facing view of the initial context.

 Exposes the handler-facing state used to seed every request context, without
 access to pipeline setup or continuation.
*>
struct ServerContext (Printable)
{
	Context* context;
}

<*
 Middleware-facing view of the request pipeline.

 Adds `next()` on top of the handler-facing API so middleware can advance
 the chain.
*>
struct MiddlewareContext (Printable)
{
	Context* context;
}

fn Context* Context.init(&self, Allocator allocator)
{
	self.objects.init(allocator);
	self.map.init(allocator);
	return self;
}

<*
 Copy all registered objects from another context.

 Existing entries with the same type id will be overwritten.

 @param [&in] other : "Source context to copy registrations from"
*>
fn void Context.add_from(&self, Context* other)
{
	other.objects.@each_entry(; map::Entry{typeid, void*}* entry)
	{
		self.objects.set(entry.key, entry.value);
	};
	other.map.@each_entry(; map::Entry{String, void*}* entry)
	{
		self.map.set(entry.key, entry.value);
	};
}

macro void Context.register(&self, $Type, value)
{
	$assert $Typeof(value) == $Type*;
	self.objects.set($Type, value);
}


macro Context.resolve(&self, $Type)
{
	void*? value = self.objects.get($Type);

	if (catch value) return NOT_FOUND~;

	return ($Type*)value;
}

<*
 Store the middleware chain and terminal handler for a request.

 Internal setup entry used by the request processing pipeline, not exposed
 through the handler or middleware facing context views.

 @param [&inout] self : "Pipeline state to configure"
 @param middlewares : "Middleware callbacks in execution order"
 @param handler : "Terminal handler, or null for middleware-only pipelines"
*>
fn void Context.setup_handling(&self, RegisteredMiddleware[] middlewares, RegisteredHandler* handler)
{
	self.middlewares = middlewares;
	self.handler = handler;
	self.middleware_idx = 0;
}

<*
 Advance the pipeline to the next middleware or the terminal handler.

 Middleware callbacks are invoked with a `MiddlewareContext` view and the
 terminal handler with a `HandlerContext` view. Calls beyond the end of the
 chain are a no-op.

 @param [&inout] self : "Pipeline state to advance"
 @param [&inout] allocator : "Allocator available during the request processing"
 @param [&inout] req : "Incoming HTTP request"
 @param [&inout] res : "Response being built"
*>
fn void Context.next(&self, Allocator allocator, HttpRequest* req, HttpResponse* res)
{
	if (self.middleware_idx < self.middlewares.len)
	{
		RegisteredMiddleware registered = self.middlewares[self.middleware_idx];
		self.middleware_idx++;

		MiddlewareContext middleware_ctx = { .context = self };
		registered.middleware(registered.self, allocator, &middleware_ctx, req, res);
		return;
	}

	if (self.handler != null && self.middleware_idx == self.middlewares.len)
	{
		RegisteredHandler* handler = self.handler;
		self.middleware_idx++;

		HandlerContext handler_ctx = { .context = self };
		handler.handler(handler.self, allocator, &handler_ctx, req, res);
	}
}

fn bool Context.set(&self, String key, void* val)
{
	return self.map.set(key, val);
}

fn void*? Context.get(&self, String key)
{
	void**? value = self.map.get_ref(key);
	if (catch value) return NOT_FOUND~;
	return *value;
}

<*
 Store a request-scoped value in the handler-facing context.

 @param [&inout] self : "Context view"
 @param key : "Lookup key"
 @param val : "Value to store"
 @return "True if an existing key was replaced"
*>
fn bool HandlerContext.set(&self, String key, void* val) @inline => self.context.set(key, val);

<*
 Read a request-scoped value from the handler-facing context.

 @param [&in] self : "Context view"
 @param key : "Lookup key"
 @return "Stored value or NOT_FOUND~"
*>
fn void*? HandlerContext.get(&self, String key) @inline => self.context.get(key);

<*
 Register a value in the handler-facing context by type.

 @param [&inout] self : "Context view"
 @param $Type : "Type used as the registration key"
 @param value : "Value to register"
*>
macro void HandlerContext.register(&self, $Type, value)
{
	self.context.register($Type, value);
}

<*
 Resolve a registered value from the handler-facing context by type.

 @param [&in] self : "Context view"
 @param $Type : "Type used as the registration key"
 @return "Registered value or NOT_FOUND~"
*>
macro HandlerContext.resolve(&self, $Type)
{
	return self.context.resolve($Type);
}

<*
 Formatter implementation delegating to the underlying context.

 @param [&in] self : "Context view to format"
 @param [&inout] formatter : "Formatter receiving the context representation"
 @return "Number of characters written"
*>
fn sz? HandlerContext.to_format(&self, Formatter* formatter) @dynamic
{
	return self.context.to_format(formatter);
}

<*
 Store an initial value in the server-facing context.

 @param [&inout] self : "Context view"
 @param key : "Lookup key"
 @param val : "Value to store"
 @return "True if an existing key was replaced"
*>
fn bool ServerContext.set(&self, String key, void* val) @inline => self.context.set(key, val);

<*
 Read an initial value from the server-facing context.

 @param [&in] self : "Context view"
 @param key : "Lookup key"
 @return "Stored value or NOT_FOUND~"
*>
fn void*? ServerContext.get(&self, String key) @inline => self.context.get(key);

<*
 Register an initial value in the server-facing context by type.

 @param [&inout] self : "Context view"
 @param $Type : "Type used as the registration key"
 @param value : "Value to register"
*>
macro void ServerContext.register(&self, $Type, value)
{
	self.context.register($Type, value);
}

<*
 Resolve an initial registered value from the server-facing context by type.

 @param [&in] self : "Context view"
 @param $Type : "Type used as the registration key"
 @return "Registered value or NOT_FOUND~"
*>
macro ServerContext.resolve(&self, $Type)
{
	return self.context.resolve($Type);
}

<*
 Formatter implementation delegating to the underlying context.

 @param [&in] self : "Context view to format"
 @param [&inout] formatter : "Formatter receiving the context representation"
 @return "Number of characters written"
*>
fn sz? ServerContext.to_format(&self, Formatter* formatter) @dynamic
{
	return self.context.to_format(formatter);
}

<*
 Store a request-scoped value in the middleware-facing context.

 @param [&inout] self : "Context view"
 @param key : "Lookup key"
 @param val : "Value to store"
 @return "True if an existing key was replaced"
*>
fn bool MiddlewareContext.set(&self, String key, void* val) @inline => self.context.set(key, val);

<*
 Read a request-scoped value from the middleware-facing context.

 @param [&in] self : "Context view"
 @param key : "Lookup key"
 @return "Stored value or NOT_FOUND~"
*>
fn void*? MiddlewareContext.get(&self, String key) @inline => self.context.get(key);

<*
 Register a value in the middleware-facing context by type.

 @param [&inout] self : "Context view"
 @param $Type : "Type used as the registration key"
 @param value : "Value to register"
*>
macro void MiddlewareContext.register(&self, $Type, value)
{
	self.context.register($Type, value);
}

<*
 Resolve a registered value from the middleware-facing context by type.

 @param [&in] self : "Context view"
 @param $Type : "Type used as the registration key"
 @return "Registered value or NOT_FOUND~"
*>
macro MiddlewareContext.resolve(&self, $Type)
{
	return self.context.resolve($Type);
}

<*
 Formatter implementation delegating to the underlying context.

 @param [&in] self : "Context view to format"
 @param [&inout] formatter : "Formatter receiving the context representation"
 @return "Number of characters written"
*>
fn sz? MiddlewareContext.to_format(&self, Formatter* formatter) @dynamic
{
	return self.context.to_format(formatter);
}

<*
 Advance the pipeline from a middleware callback.

 @param [&inout] self : "Context view"
 @param [&inout] allocator : "Allocator available during the request processing"
 @param [&inout] req : "Incoming HTTP request"
 @param [&inout] res : "Response being built"
*>
fn void MiddlewareContext.next(&self, Allocator allocator, HttpRequest* req, HttpResponse* res) @inline
{
	self.context.next(allocator, req, res);
}

<*
 Formatter implementation for debug output.

 @param [&in] self : "Context to format"
 @param [&inout] formatter : "Formatter receiving the context representation"
 @return "Number of characters written"
*>
fn sz? Context.to_format(&self, Formatter* formatter) @dynamic
{
	sz len = formatter.print("Context { ")!;

	len += formatter.print("objects: ")!;
	len += self.objects.to_format(formatter)!;

	len += formatter.print(", map: ")!;
	len += self.map.to_format(formatter)!;

	len += formatter.print(", middlewares: ")!;
	len += formatter.printf("%d", self.middlewares.len)!;

	len += formatter.print(", handler: ")!;
	len += formatter.printf("%s", self.handler != null)!;

	len += formatter.print(", middleware_idx: ")!;
	len += formatter.printf("%d", self.middleware_idx)!;

	len += formatter.print(" }")!;
	return len;
}

fn void Context.free(&self)
{
	self.objects.free();
	self.map.free();
}