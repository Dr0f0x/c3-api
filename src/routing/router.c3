module c3api::routing;

import std::collections::map;
import std::collections::list;
import std::io;

import c3api::http;

faultdef ROUTE_NOT_FOUND, ROUTE_ALREADY_PRESENT;
struct Router (Printable)
{
	HashMap{String, RouteNode} root_nodes;

	HandlerCollection root_handlers;
	List{MiddlewareFunc} root_middlewares;

	Logger* logger;
	Allocator allocator;
}

fn Router* Router.init(&self, Allocator allocator, Logger* logger)
{
	self.root_nodes.init(allocator);
	self.root_middlewares.init(allocator);
	self.root_handlers.init();
	self.logger = logger;
	self.allocator = allocator;
	return self;
}

fn HandlerCollection*? Router.get_handlers(&self, String uri, HttpRequest* request)
{
	return routing::get_handlers(uri, &self.root_handlers, &self.root_nodes, request, self.logger);
}

<*
 Retrieve the handler associated with the specified HTTP method and URI.

 @param method : "HTTP method to match"
 @param [in] uri : "Route URI to look up"

 @return "The matching handler if found; otherwise ROUTE_NOT_FOUND~"
*>
fn HandleFunc? Router.get_route(&self, RouteMethod method, String uri, HttpRequest* request)
{
	HandlerCollection*? handlers = self.get_handlers(uri, request);

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

 @return "True if an existing handler was replaced, false if a new handler was added"
*>
fn bool Router.add_route(&self, RouteMethod method, String uri, HandleFunc handler)
{
	return routing::add_handler(uri, method, handler, &self.root_handlers, &self.root_nodes, self.logger);
}

<*
 @require uri != "" : "Group cant refer to the root"
 @require uri != "/" : "Group cant refer to the root"
*>
fn Group* Router.group(&self, Allocator allocator, String uri)
{
	Group* group    = alloc::new(allocator, Group);
	RouteNode* node = routing::get_or_create_node(uri, &self.root_nodes, self.logger)!!;
	return group.init(node, self.logger);
}

<*
 Integrate all routes from another router under the specified URI prefix.

 Each route in `other` is added to this router with `uri` prepended to
 its route path.

 @param [in] uri : "URI prefix under which the other router will be mounted"
 @param other : "Router whose routes will be integrated"

 @return "ROUTE_ALREADY_PRESENT~ if a route already exists at a URI where a route from the other router would be added; otherwise void"
*>
fn void? Router.add_router(&self, String uri, Router other)
{
	return NOT_IMPLEMENTED~;
}

fn void Router.free(&self)
{
	self.root_nodes.free();
	self.root_middlewares.free();
	self.root_handlers.free();
}

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
