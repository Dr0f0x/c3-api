// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module c3api::routing::router;

import std::collections::map;
import std::collections::list;
import std::io;

import c3api::http;
import c3api::log;
import c3api::routing::internal;
import c3api::routing::group;
import c3api::routing::handler;
import c3api::routing::node;
import c3api::routing::middleware;

<*
 HTTP router using a trie of route nodes.
*>
struct Router (Printable)
{
	HashMap{String, RouteNode} root_nodes;

	HandlerCollection root_handlers;
	List{RegisteredMiddleware} root_middlewares;

	log::Logger log;
	Allocator allocator;
}

<*
 Initialize router storage and root handler collections.

 @param [&inout] self : "Router to initialize"
 @param [&inout] allocator : "Allocator used by route trie and middleware lists"
 @param [&in] logger : "Logger used by routing internals"
 @return "Initialized router instance"
*>
fn Router* Router.init(&self, Allocator allocator, log::Logger logger)
{
	self.root_nodes.init(allocator);
	self.root_middlewares.init(allocator);
	self.root_handlers.init();
	self.log = logger;
	self.allocator = allocator;
	return self;
}

<*
 Resolve the handler collection for a URI.

 Collects middleware along the matched path.

 @param [&in] self : "Router to search"
 @param [in] uri : "Request URI"
 @param [&inout] request : "Request object receiving path arguments"
 @param [&inout] middleware_collector : "Middleware output buffer"
 @return "Matched handler collection or ROUTE_NOT_FOUND~"
*>
fn HandlerCollection*? Router.get_handlers(
	&self,
	String uri,
	HttpRequest* request,
	List{RegisteredMiddleware}* middleware_collector
)
{
	middleware_collector.push_all(self.root_middlewares.array_view());
	return internal::_get_handlers(uri, &self.root_handlers, &self.root_nodes, request, middleware_collector, self.log);
}

<*
 Retrieve the handler associated with the specified HTTP method and URI.

 @param [&in] self : "Router to search"
 @param method : "HTTP method to match"
 @param [in] uri : "Route URI to look up"
 @param [&inout] request : "Request object receiving path arguments"
 @param [&inout] middleware_collector : "Middleware output buffer"

 @return "The matching handler if found; otherwise ROUTE_NOT_FOUND~"
*>
fn RegisteredHandler*? Router.get_route(
	&self,
	RouteMethod method,
	String uri,
	HttpRequest* request,
	List{RegisteredMiddleware}* middleware_collector
)
{
	HandlerCollection* handlers = self.get_handlers(uri, request, middleware_collector)!;

	RegisteredHandler*? handler = handlers.get_handler(method);
	if (try handler)
	{
		return handler;
	}
	// if route method is head try using get as a placeholder
	if (method == RouteMethod.HEAD)
	{
		if (try get_handler = handlers.get_handler(RouteMethod.GET)) return get_handler;
	}
	return routing::ROUTE_NOT_FOUND~;
}

<*
 Add or replace a route handler.

 If a handler is already registered for the specified method and URI,
 it is replaced with the new handler.

 @param [&inout] self : "Router receiving the route"
 @param method : "HTTP method"
 @param [in] uri : "Route URI"
 @param handler : "Handler function"
 @param instance : "Optional instance passed to the handler as self"

 @return "True if an existing handler was replaced, false if a new handler was added"
*>
fn bool Router.add_route(&self, RouteMethod method, String uri, HandleFunc handler, void* instance = null)
{
	return internal::_add_handler(
		uri,
		method,
		handler,
		instance,
		{ },
		&self.root_handlers,
		&self.root_middlewares,
		&self.root_nodes,
		self.log
	);
}

<*
 Register a GET handler on this router.
 @param [&inout] self : "Router receiving the route"
 @param uri : "Route URI"
 @param handler : "Handler function"
 @param instance : "Optional handler instance passed as self"
 @return "True if an existing handler was replaced"
*>
macro bool Router.get(
	&self,
	String uri,
	HandleFunc handler,
	void* instance = null
) => self.add_route(RouteMethod.GET, uri, handler, instance);

<*
 Register a POST handler on this router.
 @param [&inout] self : "Router receiving the route"
 @param uri : "Route URI"
 @param handler : "Handler function"
 @param instance : "Optional handler instance passed as self"
 @return "True if an existing handler was replaced"
*>
macro bool Router.post(
	&self,
	String uri,
	HandleFunc handler,
	void* instance = null
) => self.add_route(RouteMethod.POST, uri, handler, instance);

<*
 Register a PUT handler on this router.
 @param [&inout] self : "Router receiving the route"
 @param uri : "Route URI"
 @param handler : "Handler function"
 @param instance : "Optional handler instance passed as self"
 @return "True if an existing handler was replaced"
*>
macro bool Router.put(
	&self,
	String uri,
	HandleFunc handler,
	void* instance = null
) => self.add_route(RouteMethod.PUT, uri, handler, instance);

<*
 Register a PATCH handler on this router.
 @param [&inout] self : "Router receiving the route"
 @param uri : "Route URI"
 @param handler : "Handler function"
 @param instance : "Optional handler instance passed as self"
 @return "True if an existing handler was replaced"
*>
macro bool Router.patch(
	&self,
	String uri,
	HandleFunc handler,
	void* instance = null
) => self.add_route(RouteMethod.PATCH, uri, handler, instance);

<*
 Register a DELETE handler on this router.
 @param [&inout] self : "Router receiving the route"
 @param uri : "Route URI"
 @param handler : "Handler function"
 @param instance : "Optional handler instance passed as self"
 @return "True if an existing handler was replaced"
*>
macro bool Router.delete(
	&self,
	String uri,
	HandleFunc handler,
	void* instance = null
) => self.add_route(RouteMethod.DELETE, uri, handler, instance);

<*
 Register a HEAD handler on this router.
 @param [&inout] self : "Router receiving the route"
 @param uri : "Route URI"
 @param handler : "Handler function"
 @param instance : "Optional handler instance passed as self"
 @return "True if an existing handler was replaced"
*>
macro bool Router.head(
	&self,
	String uri,
	HandleFunc handler,
	void* instance = null
) => self.add_route(RouteMethod.HEAD, uri, handler, instance);

<*
 Register a typed route handler on this router.
 @param router : "Router receiving the route"
 @param method : "HTTP method"
 @param uri : "Route URI"
 @param handler : "Type-safe handler function"
 @param instance : "Optional instance passed to the handler as self"
 @return "True if an existing handler was replaced"
*>
macro bool route(
	Router* router,
	RouteMethod method,
	String uri,
	HandleFuncGen{Type} handler,
	Type* instance = null
) <Type>
{
	return router.add_route(method, uri, (HandleFunc)handler, instance);
}

<*
 Register a typed GET handler on a router.
 @param router : "Router receiving the route"
 @param uri : "Route URI"
 @param handler : "Type-safe handler function"
 @param instance : "Optional instance passed to the handler as self"
 @return "True if an existing handler was replaced"
*>
macro bool get(
	Router* router,
	String uri,
	HandleFuncGen{Type} handler,
	Type* instance = null
) <Type> => router.add_route(RouteMethod.GET, uri, (HandleFunc)handler, instance);

<*
 Register a typed POST handler on a router.
 @param router : "Router receiving the route"
 @param uri : "Route URI"
 @param handler : "Type-safe handler function"
 @param instance : "Optional instance passed to the handler as self"
 @return "True if an existing handler was replaced"
*>
macro bool post(
	Router* router,
	String uri,
	HandleFuncGen{Type} handler,
	Type* instance = null
) <Type> => router.add_route(RouteMethod.POST, uri, (HandleFunc)handler, instance);

<*
 Register a typed PUT handler on a router.
 @param router : "Router receiving the route"
 @param uri : "Route URI"
 @param handler : "Type-safe handler function"
 @param instance : "Optional instance passed to the handler as self"
 @return "True if an existing handler was replaced"
*>
macro bool put(
	Router* router,
	String uri,
	HandleFuncGen{Type} handler,
	Type* instance = null
) <Type> => router.add_route(RouteMethod.PUT, uri, (HandleFunc)handler, instance);

<*
 Register a typed PATCH handler on a router.
 @param router : "Router receiving the route"
 @param uri : "Route URI"
 @param handler : "Type-safe handler function"
 @param instance : "Optional instance passed to the handler as self"
 @return "True if an existing handler was replaced"
*>
macro bool patch(
	Router* router,
	String uri,
	HandleFuncGen{Type} handler,
	Type* instance = null
) <Type> => router.add_route(RouteMethod.PATCH, uri, (HandleFunc)handler, instance);

<*
 Register a typed DELETE handler on a router.
 @param router : "Router receiving the route"
 @param uri : "Route URI"
 @param handler : "Type-safe handler function"
 @param instance : "Optional instance passed to the handler as self"
 @return "True if an existing handler was replaced"
*>
macro bool delete(
	Router* router,
	String uri,
	HandleFuncGen{Type} handler,
	Type* instance = null
) <Type> => router.add_route(RouteMethod.DELETE, uri, (HandleFunc)handler, instance);

<*
 Register a typed HEAD handler on a router.
 @param router : "Router receiving the route"
 @param uri : "Route URI"
 @param handler : "Type-safe handler function"
 @param instance : "Optional instance passed to the handler as self"
 @return "True if an existing handler was replaced"
*>
macro bool head(
	Router* router,
	String uri,
	HandleFuncGen{Type} handler,
	Type* instance = null
) <Type> => router.add_route(RouteMethod.HEAD, uri, (HandleFunc)handler, instance);

<*
 Add middleware to a router route.

 @param [&inout] self : "Router receiving the middleware"
 @param [in] uri : "Route pattern"
 @param middleware : "Middleware callback to append"
 @param instance : "Optional instance passed to the middleware as self"
*>
fn void Router.use_middleware(&self, String uri, MiddlewareFunc middleware, void* instance = null)
{
	if (try node = internal::_get_or_create_node(uri, &self.root_nodes, self.log))
	{
		node.middlewares.push({ .middleware = middleware, .self = instance });
	}
	else
	{
		self.root_middlewares.push({ .middleware = middleware, .self = instance });
	}
}

<*
 Add middleware to this router.
 @param [&inout] self : "Router receiving the middleware"
 @param uri : "Route pattern"
 @param middleware : "Middleware callback to append"
 @param instance : "Optional middleware instance passed as self"
*>
macro void Router.use(
	&self,
	String uri,
	MiddlewareFunc middleware,
	void* instance = null
) => self.use_middleware(uri, middleware, instance);

<*
 Add typed middleware to a router.
 @param router : "Router receiving the middleware"
 @param uri : "Route pattern"
 @param middleware : "Type-safe middleware callback"
 @param instance : "Optional instance passed to the middleware as self"
*>
macro void use(
	Router* router,
	String uri,
	MiddlewareFuncGen{Type} middleware,
	Type* instance = null
) <Type> => router.use_middleware(uri, (MiddlewareFunc)middleware, instance);

<*
 Create a group wrapper around a route node.

 @require uri != "" : "Group cant refer to the root"
 @require uri != "/" : "Group cant refer to the root"

 @param [&inout] self : "Router providing the parent route scope"
 @param [&inout] allocator : "Allocator used by the group"
 @param [in] uri : "Route pattern for the group"

 @return "Group instance for relative route registrations"
*>
fn Group* Router.group(&self, Allocator allocator, String uri)
{
	Group* group = alloc::new(allocator, Group);

	RouteNode* node = internal::_get_or_create_node(uri, &self.root_nodes, self.log)!!;
	return group.init(node, self.log);
}

<*
 Free router-owned resources.

 @param [&inout] self : "Router whose resources are freed"
*>
fn void Router.free(&self)
{
	self.root_nodes.free();
	self.root_middlewares.free();
	self.root_handlers.free();
}

<*
 Formatter implementation for debug output.

 @param [&in] self : "Router to format"
 @param [&inout] formatter : "Formatter receiving the router representation"
 @return "Number of characters written"
*>
fn sz? Router.to_format(&self, Formatter* formatter) @dynamic
{
	sz len = formatter.print("Router { ")!;

	len += formatter.print("root_handlers: ")!;
	len += formatter.printf("%s", self.root_handlers)!;

	len += formatter.print(", root_middleware_count: ")!;
	len += formatter.printf("%d", self.root_middlewares.len())!;

	len += formatter.print(", root_nodes: ")!;
	len += formatter.printf("%s", self.root_nodes)!;

	return len += formatter.print(" }")!;
}

<*
 Format all routes registered on this router.

 @param [&in] self : "Router whose routes are formatted"
 @param [&inout] formatter : "Formatter receiving the route tree"
 @return "Number of characters written"
*>
fn sz? Router.to_route_format(&self, Formatter* formatter)
{
	sz len = 0;
	foreach (node : self.root_nodes.value_iter())
	{
		len += node.to_route_format(formatter, 0)!;
	}
	return len;
}