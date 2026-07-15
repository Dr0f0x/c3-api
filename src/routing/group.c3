module c3api::routing;

import std::io;

struct Group (Printable)
{
	RouteNode* node;
	Logger* log;
}

fn Group* Group.init(&self, RouteNode* node, Logger* log)
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
fn bool Group.add_route(&self, RouteMethod method, String uri, HandleFunc handler)
{
	return routing::add_handler(uri, method, handler, &self.node.handlers, &self.node.sub_nodes, self.log);
}


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