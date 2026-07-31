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

 @param method : "HTTP method"
 @param [in] uri : "Route URI"
 @param handler : "Handler function"

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

macro bool Group.get(
	&self,
	String uri,
	HandleFunc handler,
	void* instance = null
) => self.add_route(RouteMethod.GET, uri, handler, instance);

macro bool Group.post(
	&self,
	String uri,
	HandleFunc handler,
	void* instance = null
) => self.add_route(RouteMethod.POST, uri, handler, instance);

macro bool Group.put(
	&self,
	String uri,
	HandleFunc handler,
	void* instance = null
) => self.add_route(RouteMethod.PUT, uri, handler, instance);

macro bool Group.patch(
	&self,
	String uri,
	HandleFunc handler,
	void* instance = null
) => self.add_route(RouteMethod.PATCH, uri, handler, instance);

macro bool Group.delete(
	&self,
	String uri,
	HandleFunc handler,
	void* instance = null
) => self.add_route(RouteMethod.DELETE, uri, handler, instance);

macro bool Group.head(
	&self,
	String uri,
	HandleFunc handler,
	void* instance = null
) => self.add_route(RouteMethod.HEAD, uri, handler, instance);

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

macro bool get(
	Group* group,
	String uri,
	HandleFuncGen{Type} handler,
	Type* instance = null
) <Type> => group.add_route(RouteMethod.GET, uri, (HandleFunc)handler, instance);

macro bool post(
	Group* group,
	String uri,
	HandleFuncGen{Type} handler,
	Type* instance = null
) <Type> => group.add_route(RouteMethod.POST, uri, (HandleFunc)handler, instance);

macro bool put(
	Group* group,
	String uri,
	HandleFuncGen{Type} handler,
	Type* instance = null
) <Type> => group.add_route(RouteMethod.PUT, uri, (HandleFunc)handler, instance);

macro bool patch(
	Group* group,
	String uri,
	HandleFuncGen{Type} handler,
	Type* instance = null
) <Type> => group.add_route(RouteMethod.PATCH, uri, (HandleFunc)handler, instance);

macro bool delete(
	Group* group,
	String uri,
	HandleFuncGen{Type} handler,
	Type* instance = null
) <Type> => group.add_route(RouteMethod.DELETE, uri, (HandleFunc)handler, instance);

macro bool head(
	Group* group,
	String uri,
	HandleFuncGen{Type} handler,
	Type* instance = null
) <Type> => group.add_route(RouteMethod.HEAD, uri, (HandleFunc)handler, instance);

<*
 Add middleware to a router route.

 @param [in] uri : "Route pattern"
 @param middleware : "Middleware callback to append"
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

macro void Group.use(
	&self,
	String uri,
	MiddlewareFunc middleware,
	void* instance = null
) => self.use_middleware(uri, middleware, instance);

macro void use(
	Group* group,
	String uri,
	MiddlewareFuncGen{Type} middleware,
	Type* instance = null
) <Type> => group.use_middleware(uri, (MiddlewareFunc)middleware, instance);

<*
 Formatter implementation for debug output.
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

fn sz? Group.to_route_format(&self, Formatter* formatter)
{
	sz len = self.node.to_route_format(formatter, 0)!;
	return len;
}
