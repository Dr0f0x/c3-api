module c3api::routing;

import std::collections::map;
import std::collections::list;
import std::io;

struct RouteNode (Printable)
{
	String name;
	HashMap{String, RouteNode} sub_nodes;

	HandlerCollection handlers;
	List{MiddlewareFunc} middlewares;
}

fn RouteNode* RouteNode.init(&self, Allocator allocator, String name)
{
	self.sub_nodes.init(allocator);
	self.middlewares.init(allocator);
	self.handlers.init();
	self.name = name;
	return self;
}

fn bool RouteNode.has_middleware(&self)
{
	return self.middlewares.len() > 0;
}

fn RouteNode*? RouteNode.get_next_node(&self, String to)
{
	return self.sub_nodes.get_ref(to) ?? self.sub_nodes.get_ref("{}");
}

fn void RouteNode.free(&self)
{
	self.middlewares.free();
	self.sub_nodes.free();
	self.handlers.free();
}


fn sz? RouteNode.to_format(&self, Formatter* formatter) @dynamic
{
    sz len = formatter.print("RouteNode { ")!;

    len += formatter.print("name: ")!;
    len += formatter.print(self.name)!;

    len += formatter.print(", handlers: ")!;
    len += formatter.printf("%s", self.handlers)!;

    len += formatter.print(", middleware_count: ")!;
    len += formatter.printf("%d", self.middlewares.len())!;

    len += formatter.print(", sub_nodes: ")!;
    len += formatter.printf("%s", self.sub_nodes)!;

    return len += formatter.print(" }")!;
}
