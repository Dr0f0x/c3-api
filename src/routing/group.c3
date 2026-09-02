// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module c3api::routing::group;

import std::io;

import c3api::log;
import c3api::routing::handler;
import c3api::routing::node;
import c3api::routing::middleware;
import c3api::routing::internal;

<*
 Route group scoped to a trie node.

 Group operations are relative to the backing node path.
*>
struct Group (Printable)
{
	RouteNode* node;
	log::Logger log;
}

<*
 Initialize a group wrapper around an existing route node.

 @param [&inout] self : "Group wrapper to initialize"
 @param [&in] node : "Backing node for relative route registrations"
 @param [&in] log : "Logger used by routing internals"
 @return "Initialized group instance"
*>
fn Group* Group.init(&self, RouteNode* node, log::Logger log)
{
	self.node = node;
	self.log = log;
	return self;
}

<*
 Add or replace a route handler.

 If a handler is already registered for the specified method and URI,
 it is replaced with the new handler.

 @param [&inout] self : "Group receiving the route"
 @param method : "HTTP method"
 @param [in] uri : "Route URI"
 @param handler : "Handler function"
 @param instance : "Optional instance passed to the handler as self"

 @return "True if an existing handler was replaced, false if a new handler was added"
*>
fn bool Group.add_route(&self, RouteMethod method, String uri, HandleFunc handler, void* instance = null)
{
	return internal::_add_handler(
		uri,
		method,
		handler,
		instance,
		{ },
		&self.node.handlers,
		&self.node.middlewares,
		&self.node.sub_nodes,
		self.log
	);
}

<*
 Register a GET handler relative to this group.
 @param [&inout] self : "Group receiving the route"
 @param uri : "Route URI relative to the group"
 @param handler : "Handler function"
 @param instance : "Optional handler instance passed as self"
 @return "True if an existing handler was replaced"
*>
macro bool Group.get(
	&self,
	String uri,
	HandleFunc handler,
	void* instance = null
) => self.add_route(RouteMethod.GET, uri, handler, instance);

<*
 Register a POST handler relative to this group.
 @param [&inout] self : "Group receiving the route"
 @param uri : "Route URI relative to the group"
 @param handler : "Handler function"
 @param instance : "Optional handler instance passed as self"
 @return "True if an existing handler was replaced"
*>
macro bool Group.post(
	&self,
	String uri,
	HandleFunc handler,
	void* instance = null
) => self.add_route(RouteMethod.POST, uri, handler, instance);

<*
 Register a PUT handler relative to this group.
 @param [&inout] self : "Group receiving the route"
 @param uri : "Route URI relative to the group"
 @param handler : "Handler function"
 @param instance : "Optional handler instance passed as self"
 @return "True if an existing handler was replaced"
*>
macro bool Group.put(
	&self,
	String uri,
	HandleFunc handler,
	void* instance = null
) => self.add_route(RouteMethod.PUT, uri, handler, instance);

<*
 Register a PATCH handler relative to this group.
 @param [&inout] self : "Group receiving the route"
 @param uri : "Route URI relative to the group"
 @param handler : "Handler function"
 @param instance : "Optional handler instance passed as self"
 @return "True if an existing handler was replaced"
*>
macro bool Group.patch(
	&self,
	String uri,
	HandleFunc handler,
	void* instance = null
) => self.add_route(RouteMethod.PATCH, uri, handler, instance);

<*
 Register a DELETE handler relative to this group.
 @param [&inout] self : "Group receiving the route"
 @param uri : "Route URI relative to the group"
 @param handler : "Handler function"
 @param instance : "Optional handler instance passed as self"
 @return "True if an existing handler was replaced"
*>
macro bool Group.delete(
	&self,
	String uri,
	HandleFunc handler,
	void* instance = null
) => self.add_route(RouteMethod.DELETE, uri, handler, instance);

<*
 Register a HEAD handler relative to this group.
 @param [&inout] self : "Group receiving the route"
 @param uri : "Route URI relative to the group"
 @param handler : "Handler function"
 @param instance : "Optional handler instance passed as self"
 @return "True if an existing handler was replaced"
*>
macro bool Group.head(
	&self,
	String uri,
	HandleFunc handler,
	void* instance = null
) => self.add_route(RouteMethod.HEAD, uri, handler, instance);

<*
 Register a typed route handler relative to this group.
 @param group : "Group receiving the route"
 @param method : "HTTP method"
 @param uri : "Route URI relative to the group"
 @param handler : "Type-safe handler function"
 @param instance : "Optional instance passed to the handler as self"
 @return "True if an existing handler was replaced"
*>
macro bool route(
	Group* group,
	RouteMethod method,
	String uri,
	HandleFuncGen{Type} handler,
	Type* instance = null
) <Type>
{
	return group.add_route(method, uri, (HandleFunc)handler, instance);
}

<*
 Register a typed GET handler relative to a group.
 @param group : "Group receiving the route"
 @param uri : "Route URI relative to the group"
 @param handler : "Type-safe handler function"
 @param instance : "Optional instance passed to the handler as self"
 @return "True if an existing handler was replaced"
*>
macro bool get(
	Group* group,
	String uri,
	HandleFuncGen{Type} handler,
	Type* instance = null
) <Type> => group.add_route(RouteMethod.GET, uri, (HandleFunc)handler, instance);

<*
 Register a typed POST handler relative to a group.
 @param group : "Group receiving the route"
 @param uri : "Route URI relative to the group"
 @param handler : "Type-safe handler function"
 @param instance : "Optional instance passed to the handler as self"
 @return "True if an existing handler was replaced"
*>
macro bool post(
	Group* group,
	String uri,
	HandleFuncGen{Type} handler,
	Type* instance = null
) <Type> => group.add_route(RouteMethod.POST, uri, (HandleFunc)handler, instance);

<*
 Register a typed PUT handler relative to a group.
 @param group : "Group receiving the route"
 @param uri : "Route URI relative to the group"
 @param handler : "Type-safe handler function"
 @param instance : "Optional instance passed to the handler as self"
 @return "True if an existing handler was replaced"
*>
macro bool put(
	Group* group,
	String uri,
	HandleFuncGen{Type} handler,
	Type* instance = null
) <Type> => group.add_route(RouteMethod.PUT, uri, (HandleFunc)handler, instance);

<*
 Register a typed PATCH handler relative to a group.
 @param group : "Group receiving the route"
 @param uri : "Route URI relative to the group"
 @param handler : "Type-safe handler function"
 @param instance : "Optional instance passed to the handler as self"
 @return "True if an existing handler was replaced"
*>
macro bool patch(
	Group* group,
	String uri,
	HandleFuncGen{Type} handler,
	Type* instance = null
) <Type> => group.add_route(RouteMethod.PATCH, uri, (HandleFunc)handler, instance);

<*
 Register a typed DELETE handler relative to a group.
 @param group : "Group receiving the route"
 @param uri : "Route URI relative to the group"
 @param handler : "Type-safe handler function"
 @param instance : "Optional instance passed to the handler as self"
 @return "True if an existing handler was replaced"
*>
macro bool delete(
	Group* group,
	String uri,
	HandleFuncGen{Type} handler,
	Type* instance = null
) <Type> => group.add_route(RouteMethod.DELETE, uri, (HandleFunc)handler, instance);

<*
 Register a typed HEAD handler relative to a group.
 @param group : "Group receiving the route"
 @param uri : "Route URI relative to the group"
 @param handler : "Type-safe handler function"
 @param instance : "Optional instance passed to the handler as self"
 @return "True if an existing handler was replaced"
*>
macro bool head(
	Group* group,
	String uri,
	HandleFuncGen{Type} handler,
	Type* instance = null
) <Type> => group.add_route(RouteMethod.HEAD, uri, (HandleFunc)handler, instance);

<*
 Add middleware to a router route.

 @param [&inout] self : "Group receiving the middleware"
 @param [in] uri : "Route pattern"
 @param middleware : "Middleware callback to append"
 @param instance : "Optional instance passed to the middleware as self"
*>
fn void Group.use_middleware(&self, String uri, MiddlewareFunc middleware, void* instance = null)
{
	if (try node = internal::_get_or_create_node(uri, &self.node.sub_nodes, self.log))
	{
		node.middlewares.push({ .middleware = middleware, .self = instance });
	}
	else
	{
		self.node.middlewares.push({ .middleware = middleware, .self = instance });
	}
}

<*
 Add middleware relative to this group.
 @param [&inout] self : "Group receiving the middleware"
 @param uri : "Route pattern"
 @param middleware : "Middleware callback to append"
 @param instance : "Optional middleware instance passed as self"
*>
macro void Group.use(
	&self,
	String uri,
	MiddlewareFunc middleware,
	void* instance = null
) => self.use_middleware(uri, middleware, instance);

<*
 Add typed middleware relative to a group.
 @param group : "Group receiving the middleware"
 @param uri : "Route pattern"
 @param middleware : "Type-safe middleware callback"
 @param instance : "Optional instance passed to the middleware as self"
*>
macro void use(
	Group* group,
	String uri,
	MiddlewareFuncGen{Type} middleware,
	Type* instance = null
) <Type> => group.use_middleware(uri, (MiddlewareFunc)middleware, instance);

<*
 Create a group wrapper around a route node.

 @require uri != "" : "Nested group must specify a route path"
 @require uri != "/" : "Nested group must specify a route path"

 @param [&inout] self : "Group providing the parent route scope"
 @param [&inout] allocator : "Allocator used by the group"
 @param [in] uri : "Route pattern relative to the current group"

 @return "Group instance for relative route registrations"
*>
fn Group* Group.group(&self, Allocator allocator, String uri)
{
	Group* group = alloc::new(allocator, Group);

	RouteNode* node = internal::_get_or_create_node(uri, &self.node.sub_nodes, self.log)!!;
	return group.init(node, self.log);
}

<*
 Free the group wrapper.

 @param [&inout] self : "Group to free"
*>
fn void Group.free(&self)
{
	// nothing to do here yet
}

<*
 Formatter implementation for debug output.

 @param [&in] self : "Group to format"
 @param [&inout] formatter : "Formatter receiving the group representation"
 @return "Number of characters written"
*>
fn sz? Group.to_format(&self, Formatter* formatter) @dynamic
{
	sz len = formatter.print("Group { ")!;

	len += formatter.print("name: ")!;
	len += formatter.print(self.node.name)!;

	len += formatter.print(", middleware_count: ")!;
	len += formatter.printf("%d", self.node.middlewares.len())!;

	len += formatter.print(", sub_nodes: ")!;
	len += formatter.printf("%s", self.node.sub_nodes)!;

	return len += formatter.print(" }")!;
}

<*
 Format all routes below this group.

 @param [&in] self : "Group whose routes are formatted"
 @param [&inout] formatter : "Formatter receiving the route tree"
 @return "Number of characters written"
*>
fn sz? Group.to_route_format(&self, Formatter* formatter)
{
	sz len = self.node.to_route_format(formatter, 0)!;
	return len;
}