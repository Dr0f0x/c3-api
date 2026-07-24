module c3api::routing;

import std::collections::map;
import std::collections::list;
import std::io;

<*
 Node in the route trie.

 Each node owns handler registrations, middleware, and child nodes.
*>
struct RouteNode (Printable)
{
	String name;
	HashMap{String, RouteNode} sub_nodes;

	HandlerCollection handlers;
	List{MiddlewareFunc} middlewares;
}

<*
 Initialize a route node.

 @param [&inout] allocator : "Allocator used by child map and middleware list"
 @param [in] name : "Path segment represented by this node"
 @return "Initialized route node"
*>
fn RouteNode* RouteNode.init(&self, Allocator allocator, String name)
{
	self.sub_nodes.init(allocator);
	self.middlewares.init(allocator);
	self.handlers.init();
	self.name = name;
	return self;
}

<*
 Check whether this node has middleware attached.

 @return "True when middleware list is non-empty"
*>
fn bool RouteNode.has_middleware(&self)
{
	return self.middlewares.len() > 0;
}

<*
 Resolve the next child node for a segment.

 Tries an exact child first, then the dynamic placeholder key.

 @param [in] to : "Next URI segment"
 @return "Matching child node or null"
*>
fn RouteNode*? RouteNode.get_next_node(&self, String to)
{
	return self.sub_nodes.get_ref(to) ?? self.sub_nodes.get_ref("{}");
}

<*
 Free node-owned resources.
*>
fn void RouteNode.free(&self)
{
	self.middlewares.free();
	self.sub_nodes.free();
	self.handlers.free();
}


<*
 Formatter implementation for debug output.
*>
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

fn sz? RouteNode.to_route_format(&self, Formatter* formatter, sz indent = 0)
{
	sz len = 0;

	for (sz i = 0; i < indent; i++)
	{
		len += formatter.print(" ")!;
	}

	len += formatter.printf("%s", self.name)!;

	bool first = true;
	foreach (i, &value : self.handlers.handler_map.values)
	{
		if (value.handler == null) continue;

		if (first)
		{
			len += formatter.print(" - ")!;
			first = false;
		}
		else
		{
			len += formatter.print(", ")!;
		}

		len += formatter.printf("%s", RouteMethod::from_ordinal(i))!;
	}

	len += formatter.print("\n")!;

	foreach (node : self.sub_nodes.value_iter())
	{
		len += node.to_route_format(formatter, indent + 2)!;
	}

	return len;
}
