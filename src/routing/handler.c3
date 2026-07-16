module c3api::routing;

import std::io;
import std::collections::enummap;

import c3api::http;

<*
 Route handler callback signature.

 @param [&inout] allocator : "Allocator available for response construction"
 @param [&inout] request : "Parsed request"
 @param [&inout] response : "Response to populate"
*>
alias HandleFunc = fn void(Allocator allocator, Context* ctx, HttpRequest* request, HttpResponse* response);

<*
 Built-in 404 JSON handler.

 @param [&inout] allocator : "Allocator used for response body formatting"
 @param [&inout] req : "Incoming request"
 @param [&inout] res : "Outgoing response"
*>
fn void e404(Allocator allocator, Context* ctx, HttpRequest* req, HttpResponse* res)
{
	res.status = HttpStatus.NOT_FOUND;
	res.body = string::format(mem, `{"type":"error","status":404}`);

	res.headers.set_header_value("Content-Type", "application/json");
}

<*
 Method-indexed collection of route handlers.
*>
struct HandlerCollection (Printable)
{
	EnumMap{RouteMethod, HandleFunc} handler_map;
}

<*
 Initialize the method-to-handler map.

 @return "Initialized handler collection"
*>
fn HandlerCollection* HandlerCollection.init(&self)
{
	self.handler_map.init(null);
	return self;
}

<*
 Set or replace the handler for a specific route method.

 @param method : "Method to associate with the handler"
 @param handler : "Handler callback"
 @return "True if an existing handler was replaced"
*>
fn bool HandlerCollection.set_handler(&self, RouteMethod method, HandleFunc handler)
{
	bool already_present = self.has_handler(method);
	self.handler_map.set(method, handler);
	return already_present;
}

<*
 Convenience wrapper for setting a GET handler.
*>
fn bool HandlerCollection.set_get(&self, HandleFunc handler) => self.set_handler(RouteMethod.GET, handler);
<*
 Convenience wrapper for setting a PATCH handler.
*>
fn bool HandlerCollection.set_patch(&self, HandleFunc handler) => self.set_handler(RouteMethod.PATCH, handler);
<*
 Convenience wrapper for setting a PUT handler.
*>
fn bool HandlerCollection.set_put(&self, HandleFunc handler) => self.set_handler(RouteMethod.PUT, handler);
<*
 Convenience wrapper for setting a POST handler.
*>
fn bool HandlerCollection.set_post(&self, HandleFunc handler) => self.set_handler(RouteMethod.POST, handler);
<*
 Convenience wrapper for setting a DELETE handler.
*>
fn bool HandlerCollection.set_delete(&self, HandleFunc handler) => self.set_handler(RouteMethod.DELETE, handler);

<*
 Retrieve the handler for a specific route method.

 @param method : "Method to resolve"
 @return "Matching handler or NOT_FOUND~"
*>
fn HandleFunc? HandlerCollection.get_handler(&self, RouteMethod method)
{
	HandleFunc val = self.handler_map.get(method);
	if (val == null)
	{
		return NOT_FOUND~;
	}
	return val;
}

<*
 Convenience wrapper for retrieving a GET handler.
*>
fn HandleFunc? HandlerCollection.get_get(&self) => self.get_handler(RouteMethod.GET);
<*
 Convenience wrapper for retrieving a PATCH handler.
*>
fn HandleFunc? HandlerCollection.get_patch(&self) => self.get_handler(RouteMethod.PATCH);
<*
 Convenience wrapper for retrieving a PUT handler.
*>
fn HandleFunc? HandlerCollection.get_put(&self) => self.get_handler(RouteMethod.PUT);
<*
 Convenience wrapper for retrieving a POST handler.
*>
fn HandleFunc? HandlerCollection.get_post(&self) => self.get_handler(RouteMethod.POST);
<*
 Convenience wrapper for retrieving a DELETE handler.
*>
fn HandleFunc? HandlerCollection.get_delete(&self) => self.get_handler(RouteMethod.DELETE);

<*
 Check whether a handler exists for a specific method.

 @param method : "Method to test"
 @return "True when a non-null handler is registered"
*>
fn bool HandlerCollection.has_handler(&self, RouteMethod method)
{
	return self.handler_map.get(method) != null;
}

<*
 Convenience wrapper for checking GET handler presence.
*>
fn bool HandlerCollection.has_get(&self) => self.has_handler(RouteMethod.GET);
<*
 Convenience wrapper for checking PATCH handler presence.
*>
fn bool HandlerCollection.has_patch(&self) => self.has_handler(RouteMethod.PATCH);
<*
 Convenience wrapper for checking PUT handler presence.
*>
fn bool HandlerCollection.has_put(&self) => self.has_handler(RouteMethod.PUT);
<*
 Convenience wrapper for checking POST handler presence.
*>
fn bool HandlerCollection.has_post(&self) => self.has_handler(RouteMethod.POST);
<*
 Convenience wrapper for checking DELETE handler presence.
*>
fn bool HandlerCollection.has_delete(&self) => self.has_handler(RouteMethod.DELETE);


<*
 Free internal resources used by the handler collection.
*>
fn void HandlerCollection.free(&self)
{
	// placeholder
}

<*
 Formatter implementation for debug output.
*>
fn sz? HandlerCollection.to_format(&self, Formatter* formatter) @dynamic
{
	sz len = formatter.print("HandlerCollection {")!;
	foreach (i, &value : self.handler_map.values)
	{
		if (i != 0) len += formatter.print(", ")!;
		len += formatter.printf("%s: %s", RouteMethod::from_ordinal(i), *value != null)!;
	}
	len += formatter.print(" }")!;
	return len;
}
