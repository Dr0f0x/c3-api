// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module c3api::routing::handler;

import std::io;
import std::collections::enummap;

import c3api::http;
import c3api::context;

<*
 Route handler callback signature.

 @param [&inout] self : "Instance if the handler was registered with one"
 @param [&inout] allocator : "Allocator available during the request processing"
 @param [&inout] ctx : "Request context"
 @param [&inout] request : "Parsed request"
 @param [&inout] response : "Response to populate"
*>
alias HandleFunc = fn void(
	void* self = null,
	Allocator allocator,
	Context* ctx,
	HttpRequest* request,
	HttpResponse* response
);

<*
 Type-safe route handler callback signature.

 @param [&inout] self : "Owning instance if registered as a member function"
 @param [&inout] allocator : "Allocator available during the request processing"
 @param [&inout] ctx : "Request context"
 @param [&inout] request : "Parsed request"
 @param [&inout] response : "Response to populate"
*>
alias HandleFuncGen <Type> = fn void(
	Type* self = null,
	Allocator allocator,
	Context* ctx,
	HttpRequest* request,
	HttpResponse* response
);

<*
 Built-in 404 JSON handler.

 @param self : "Optional instance passed to the handler"
 @param [&inout] allocator : "Allocator used for response body formatting"
 @param [&inout] ctx : "Request context"
 @param [&inout] req : "Incoming request"
 @param [&inout] res : "Outgoing response"
*>
fn void e404(void* self = null, Allocator allocator, Context* ctx, HttpRequest* req, HttpResponse* res)
{
	res.status = HttpStatus.NOT_FOUND;
	res.body = string::format(mem, `{"type":"error","status":404}`);

	res.headers.set_header_value("Content-Type", "application/json");
}

<*
 Registered route handler entry.

 Stores the callback that should be invoked for a matched route along with
 an optional instance. If the handler was registered as a member function,
 `self` points to the owning instance. For free functions,
 `self` is `null`.
*>
struct RegisteredHandler
{
	void* self; /* Instance if handler was registered with one */
	HandleFunc handler; /* actual handler func */
}

<*
 Method-indexed collection of route handlers.
*>
struct HandlerCollection (Printable)
{
	EnumMap{RouteMethod, RegisteredHandler} handler_map;
}

<*
 Initialize the method-to-handler map.

 @param [&inout] self : "Handler collection to initialize"
 @return "Initialized handler collection"
*>
fn HandlerCollection* HandlerCollection.init(&self)
{
	self.handler_map.init({ .self = null, .handler = null });
	return self;
}

<*
 Set or replace the handler for a specific route method.

 @param [&inout] self : "Handler collection receiving the handler"
 @param method : "Method to associate with the handler"
 @param handler : "Handler callback"
 @param instance : "Optional instance passed to the handler as self"
 @return "True if an existing handler was replaced"
*>
fn bool HandlerCollection.set_handler(&self, RouteMethod method, HandleFunc handler, void* instance = null)
{
	bool already_present = self.has_handler(method);
	self.handler_map.set(method, { .self = instance, .handler = handler });
	return already_present;
}

<*
 Convenience wrapper for setting a GET handler.
 @param [&inout] self : "Handler collection receiving the handler"
 @param handler : "Handler callback"
 @param instance : "Optional instance passed to the handler as self"
 @return "True if an existing handler was replaced"
*>
fn bool HandlerCollection.set_get(
	&self,
	HandleFunc handler,
	void* instance = null
) => self.set_handler(RouteMethod.GET, handler, instance);
<*
 Convenience wrapper for setting a PATCH handler.
 @param [&inout] self : "Handler collection receiving the handler"
 @param handler : "Handler callback"
 @param instance : "Optional instance passed to the handler as self"
 @return "True if an existing handler was replaced"
*>
fn bool HandlerCollection.set_patch(
	&self,
	HandleFunc handler,
	void* instance = null
) => self.set_handler(RouteMethod.PATCH, handler, instance);
<*
 Convenience wrapper for setting a PUT handler.
 @param [&inout] self : "Handler collection receiving the handler"
 @param handler : "Handler callback"
 @param instance : "Optional instance passed to the handler as self"
 @return "True if an existing handler was replaced"
*>
fn bool HandlerCollection.set_put(
	&self,
	HandleFunc handler,
	void* instance = null
) => self.set_handler(RouteMethod.PUT, handler, instance);
<*
 Convenience wrapper for setting a POST handler.
 @param [&inout] self : "Handler collection receiving the handler"
 @param handler : "Handler callback"
 @param instance : "Optional instance passed to the handler as self"
 @return "True if an existing handler was replaced"
*>
fn bool HandlerCollection.set_post(
	&self,
	HandleFunc handler,
	void* instance = null
) => self.set_handler(RouteMethod.POST, handler, instance);
<*
 Convenience wrapper for setting a DELETE handler.
 @param [&inout] self : "Handler collection receiving the handler"
 @param handler : "Handler callback"
 @param instance : "Optional instance passed to the handler as self"
 @return "True if an existing handler was replaced"
*>
fn bool HandlerCollection.set_delete(
	&self,
	HandleFunc handler,
	void* instance = null
) => self.set_handler(RouteMethod.DELETE, handler, instance);

<*
 Retrieve the handler for a specific route method.

 @param [&in] self : "Handler collection to query"
 @param method : "Method to resolve"
 @return "Matching handler or NOT_FOUND~"
*>
fn RegisteredHandler*? HandlerCollection.get_handler(&self, RouteMethod method)
{
	RegisteredHandler* val = self.handler_map.get_ref(method);
	if (val == null || val.handler == null)
	{
		return NOT_FOUND~;
	}
	return val;
}

<*
 Convenience wrapper for retrieving a GET handler.
 @param [&in] self : "Handler collection to query"
 @return "Matching handler or NOT_FOUND~"
*>
fn RegisteredHandler*? HandlerCollection.get_get(&self) => self.get_handler(RouteMethod.GET);
<*
 Convenience wrapper for retrieving a PATCH handler.
 @param [&in] self : "Handler collection to query"
 @return "Matching handler or NOT_FOUND~"
*>
fn RegisteredHandler*? HandlerCollection.get_patch(&self) => self.get_handler(RouteMethod.PATCH);
<*
 Convenience wrapper for retrieving a PUT handler.
 @param [&in] self : "Handler collection to query"
 @return "Matching handler or NOT_FOUND~"
*>
fn RegisteredHandler*? HandlerCollection.get_put(&self) => self.get_handler(RouteMethod.PUT);
<*
 Convenience wrapper for retrieving a POST handler.
 @param [&in] self : "Handler collection to query"
 @return "Matching handler or NOT_FOUND~"
*>
fn RegisteredHandler*? HandlerCollection.get_post(&self) => self.get_handler(RouteMethod.POST);
<*
 Convenience wrapper for retrieving a DELETE handler.
 @param [&in] self : "Handler collection to query"
 @return "Matching handler or NOT_FOUND~"
*>
fn RegisteredHandler*? HandlerCollection.get_delete(&self) => self.get_handler(RouteMethod.DELETE);

<*
 Check whether a handler exists for a specific method.

 @param [&in] self : "Handler collection to query"
 @param method : "Method to test"
 @return "True when a non-null handler is registered"
*>
fn bool HandlerCollection.has_handler(&self, RouteMethod method)
{
	return self.handler_map.get_ref(method) != null;
}

<*
 Convenience wrapper for checking GET handler presence.
 @param [&in] self : "Handler collection to query"
 @return "True when a handler is registered"
*>
fn bool HandlerCollection.has_get(&self) => self.has_handler(RouteMethod.GET);
<*
 Convenience wrapper for checking PATCH handler presence.
 @param [&in] self : "Handler collection to query"
 @return "True when a handler is registered"
*>
fn bool HandlerCollection.has_patch(&self) => self.has_handler(RouteMethod.PATCH);
<*
 Convenience wrapper for checking PUT handler presence.
 @param [&in] self : "Handler collection to query"
 @return "True when a handler is registered"
*>
fn bool HandlerCollection.has_put(&self) => self.has_handler(RouteMethod.PUT);
<*
 Convenience wrapper for checking POST handler presence.
 @param [&in] self : "Handler collection to query"
 @return "True when a handler is registered"
*>
fn bool HandlerCollection.has_post(&self) => self.has_handler(RouteMethod.POST);
<*
 Convenience wrapper for checking DELETE handler presence.
 @param [&in] self : "Handler collection to query"
 @return "True when a handler is registered"
*>
fn bool HandlerCollection.has_delete(&self) => self.has_handler(RouteMethod.DELETE);


<*
 Free internal resources used by the handler collection.

 @param [&inout] self : "Handler collection to free"
*>
fn void HandlerCollection.free(&self)
{
	// placeholder
}

<*
 Formatter implementation for debug output.

 @param [&in] self : "Handler collection to format"
 @param [&inout] formatter : "Formatter receiving the collection representation"
 @return "Number of characters written"
*>
fn sz? HandlerCollection.to_format(&self, Formatter* formatter) @dynamic
{
	sz len = formatter.print("HandlerCollection {")!;
	foreach (i, &value : self.handler_map.values)
	{
		if (i != 0) len += formatter.print(", ")!;
		len += formatter.printf("%s: %s", RouteMethod::from_ordinal(i), value.handler != null)!;
	}
	len += formatter.print(" }")!;
	return len;
}