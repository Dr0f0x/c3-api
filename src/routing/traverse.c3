module c3api::routing;

import std::collections::map;
import std::collections::list;
import std::io;

import c3api::http;

fn HandlerCollection*? get_handlers(
	String uri,
	HandlerCollection* start_handlers,
	HashMap{String, RouteNode}* start_nodes,
	HttpRequest* request,
	List{MiddlewareFunc}* middleware_collector,
	Logger* log,
) @private
{
	if (uri == "" || uri == "/")
	{
		return start_handlers;
	}

	String old_uri;
	if (uri[0] == '/' && uri.len > 1)
	{
		io::printfn("[ROUTER] Removing leading slash from '%s'", uri);
		old_uri = uri;
		uri = uri[1..];
	}

	String[] uri_segments = uri.tsplit("/");
	io::printfn("[ROUTER] route segments: '%s'", uri_segments);

	String root_key = node_key(uri_segments[0]);
	RouteNode*? cur_node = start_nodes.get_ref(root_key);
	if (catch err = cur_node)
	{
		return ROUTE_NOT_FOUND~;
	}

	int i = 1;
	while (cur_node != null && i < uri_segments.len)
	{
		if (cur_node.has_middleware()) middleware_collector.push_all(cur_node.middlewares.array_view());

		if (uri_segments[i] == "") break;
		io::printfn("[ROUTER] Looking for child '%s' under '%s'", uri_segments[i], cur_node.name);

		cur_node = cur_node.get_next_node(uri_segments[i]) ?? null;

		if (cur_node == null)
		{
			io::printfn("[ROUTER] No child found, continuing");
			return ROUTE_NOT_FOUND~;
		}

		io::printfn("[ROUTER] Matched node '%s'", cur_node.name);

		if (cur_node.name[0] == '{' && cur_node.name[^1] == '}')
		{
			String key = cur_node.name[1:^2];
			io::printfn("[ROUTER] Dynamic parameter: %s=%s", key, uri_segments[i]);
			request.args.set_argument_value(key, uri_segments[i]);
		}

		i++;
	}

	if (cur_node == null)
	{
		io::printn("[ROUTER] No matching route found");
		return ROUTE_NOT_FOUND~;
	}
	
	middleware_collector.push_all(cur_node.middlewares.array_view());
	return &cur_node.handlers;
}

faultdef REFERS_TO_ROOT;

fn RouteNode*? get_or_create_node(String uri, HashMap{String, RouteNode}* start_nodes, Logger* log) @private
{
	@pool()
	{
		io::printfn("[ROUTER ADD] Adding route '%s'", uri);

		// would be root route
		if (uri == "/" || uri.len == 0)
		{
			return REFERS_TO_ROOT~;
		}

		// remove leading slash
		if (uri[0] == '/' && uri.len > 1) uri = uri[1..];

		io::printfn("[ROUTER ADD] Normalized route '%s'", uri);

		String[] uri_segments = uri.tsplit("/");

		RouteNode* cur_node;
		String root_key = node_key(uri_segments[0]);

		io::printfn("[ROUTER ADD] route segments %s", uri_segments);

		// check if root node needs to be added
		if (!start_nodes.has_key(root_key))
		{
			io::printfn("[ROUTER ADD] Creating root node '%s'", uri_segments[0]);

			start_nodes.set(root_key, new_route_node(uri_segments[0]));
			cur_node = start_nodes.get_ref(root_key)!!;
		}
		else
		{
			io::printfn("[ROUTER ADD] Using existing root node '%s'", uri_segments[0]);
			cur_node = start_nodes.get_ref(root_key)!!;
		}

		// traverse node tree down
		foreach (i, segment : uri_segments[..^2])
		{
			io::printfn("[ROUTER ADD] Processing child '%s' under '%s'", segment, cur_node.name);
			if (try new_cur_node = cur_node.get_next_node(segment))
			{
				io::printfn("[ROUTER ADD] Existing child '%s'", new_cur_node);
				cur_node = new_cur_node;
				continue;
			}
			String key = node_key(uri_segments[i + 1]);

			io::printfn("[ROUTER ADD] Creating child key '%s'", key);
			cur_node.sub_nodes[key] = new_route_node(uri_segments[i + 1]);
			cur_node = cur_node.sub_nodes.get_ref(key)!!;
		}

		return cur_node;
	};
}

fn bool add_handler(
	String uri,
	RouteMethod method,
	HandleFunc handler,
	MiddlewareFunc[] middlewares,
	HandlerCollection* start_handlers,
	List{MiddlewareFunc}* start_middlewares,
	HashMap{String, RouteNode}* start_nodes,
	Logger* log
) @private
{
	RouteNode*? node = get_or_create_node(uri, start_nodes, log);
	if(catch err = node){
		start_middlewares.push_all(middlewares);
		return start_handlers.set_handler(method, handler);
	}
	io::printfn("[ROUTER ADD] Assigning handler to '%s'", node.name);
	io::printfn("Adding middlewares to node '%s' %s %s", node.name, middlewares.len, node.middlewares.len());
	node.middlewares.push_all(middlewares);
	io::printfn("Added middlewares to node '%s' %s %s", node.name, middlewares.len, node.middlewares.len());
	return node.handlers.set_handler(method, handler);
}

fn bool String.is_braced(self)
{
	return self[0] == '{' && self[^1] == '}';
}

fn String node_key(String segment)
{
	return segment.is_braced() ? "{}" : segment;
}

macro RouteNode new_route_node(String name)
{
	RouteNode node;
	node.init(mem, name);
	return node;
}
