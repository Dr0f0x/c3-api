module c3api::routing;

import std::collections::map;
import std::collections::list;
import std::io;

import c3api::http;
import c3api::log;

<*
 ROUTE_NOT_FOUND: no route or method match for the request.
 ROUTE_ALREADY_PRESENT: route existed before replacement.
*>
faultdef ROUTE_NOT_FOUND, ROUTE_ALREADY_PRESENT;

<*
 HTTP router using a trie of route nodes.
*>
struct Router (Printable)
{
	HashMap{String, RouteNode} root_nodes;

	HandlerCollection root_handlers;
	List{MiddlewareFunc} root_middlewares;

	log::Logger log;
	Allocator allocator;
}

<*
 Initialize router storage and root handler collections.

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

 @param [in] uri : "Request URI"
 @param [&inout] request : "Request object receiving path arguments"
 @param [&inout] middleware_collector : "Middleware output buffer"
 @return "Matched handler collection or ROUTE_NOT_FOUND~"
*>
fn HandlerCollection*? Router.get_handlers(
	&self,
	String uri,
	HttpRequest* request,
	List{MiddlewareFunc}* middleware_collector
)
{
	return routing::get_handlers(
		uri,
		&self.root_handlers,
		&self.root_nodes,
		request,
		middleware_collector,
		self.log
	);
}

<*
 Retrieve the handler associated with the specified HTTP method and URI.

 @param method : "HTTP method to match"
 @param [in] uri : "Route URI to look up"
 @param [&inout] request : "Request object receiving path arguments"
 @param [&inout] middleware_collector : "Middleware output buffer"

 @return "The matching handler if found; otherwise ROUTE_NOT_FOUND~"
*>
fn HandleFunc? Router.get_route(
	&self,
	RouteMethod method,
	String uri,
	HttpRequest* request,
	List{MiddlewareFunc}* middleware_collector
)
{
	middleware_collector.push_all(self.root_middlewares.array_view());
	HandlerCollection* handlers = self.get_handlers(uri, request, middleware_collector)!;

	HandleFunc? handler = handlers.get_handler(method);
	if (try handler)
	{
		return handler;
	}
	// if route method is head try using get as a placeholder
	if (method == RouteMethod.HEAD)
	{
		if (try get_handler = handlers.get_handler(RouteMethod.GET)) return get_handler;
	}
	return ROUTE_NOT_FOUND~;
}

<*
 Add or replace a route handler.

 If a handler is already registered for the specified method and URI,
 it is replaced with the new handler.

 @param method : "HTTP method"
 @param [in] uri : "Route URI"
 @param handler : "Handler function"
 @param [in] middlewares : "Middleware callbacks for this route"

 @return "True if an existing handler was replaced, false if a new handler was added"
*>
fn bool Router.add_route(&self, RouteMethod method, String uri, HandleFunc handler, MiddlewareFunc ...middlewares)
{
	return routing::add_handler(
		uri,
		method,
		handler,
		middlewares,
		&self.root_handlers,
		&self.root_middlewares,
		&self.root_nodes,
		self.log
	);
}

<*
 Add middleware to a router route.

 If uri refers to router root, middleware is attached at root level.

 @param [in] uri : "Route pattern"
 @param [in] middlewares : "Middleware callbacks to append"
*>
fn void Router.add_middleware(&self, String uri, MiddlewareFunc ...middlewares)
{
	if (try node = routing::get_or_create_node(uri, &self.root_nodes, self.log))
	{
		node.middlewares.push_all(middlewares);
	}
	else
	{
		self.root_middlewares.push_all(middlewares);
	}
}

<*
 Add middleware to the router root.

 @param [in] middlewares : "Middleware callbacks to append"
*>
fn void Router.use_middleware(&self, MiddlewareFunc ...middlewares)
{
	self.root_middlewares.push_all(middlewares);
}

<*
 Create a group wrapper around a route node.

 @require uri != "" : "Group cant refer to the root"
 @require uri != "/" : "Group cant refer to the root"

 @param [&inout] allocator : "Allocator used by the group"
 @param [in] uri : "Route pattern for the group"

 @return "Group instance for relative route registrations"
*>
fn Group* Router.group(&self, Allocator allocator, String uri)
{
	Group* group    = alloc::new(allocator, Group);
	RouteNode* node = routing::get_or_create_node(uri, &self.root_nodes, self.log)!!;
	return group.init(node, self.log);
}

<*
 Free router-owned resources.
*>
fn void Router.free(&self)
{
	self.root_nodes.free();
	self.root_middlewares.free();
	self.root_handlers.free();
}

<*
 Formatter implementation for debug output.
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
