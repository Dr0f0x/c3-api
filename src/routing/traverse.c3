module c3api::routing;

import std::collections::map;
import std::io;

import c3api::http;

fn HandlerCollection*? get_handlers(
	String uri,
	HandlerCollection* start_handlers,
	HashMap{String, RouteNode}* start_nodes,
	HttpRequest* request,
	Logger* log,
) @private
{
	if (uri == "" || uri == "/")
	{
		return start_handlers;
	}

	DString reverse_path = dstring::new(mem, uri);

	if (uri[0] != '/')
	{
		reverse_path.insert_at(0, "/");
	}
	io::printfn("[ROUTER] Initial reverse path: '%s'", reverse_path.str_view());

	String old_uri;
	if (uri[0] == '/' && uri.len > 1)
	{
		io::printfn("[ROUTER] Removing leading slash from '%s'", uri);
		old_uri = uri;
		uri = uri[1..];
	}

	String[] uri_segments = uri.tsplit("/");
	io::printfn("[ROUTER] route segments: '%s'", uri_segments);

	RouteNode*? cur_node = start_nodes.get_ref(uri_segments[0]);
	if (catch err = cur_node)
	{
		return ROUTE_NOT_FOUND~;
	}

	reverse_path.clear();
	reverse_path.appendf("/%s", cur_node.name);

	int i = 1;
	while (cur_node != null && i < uri_segments.len)
	{
		if (uri_segments[i] == "") break;
		io::printfn("[ROUTER] Looking for child '%s' under '%s'", uri_segments[i], cur_node.name);

		io::printfn("cur: %s", cur_node);
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

		reverse_path.appendf("/%s", cur_node.name);
		io::printfn("[ROUTER] Reverse path now: '%s'", reverse_path.str_view());
		i++;
	}

	if (cur_node == null)
	{
		io::printn("[ROUTER] No matching route found");
		// args.set("reverse_path", "/e404");
		return ROUTE_NOT_FOUND~;
	}

	io::printfn("[ROUTER] Final route: '%s'", reverse_path.str_view());
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

		io::printfn("[ROUTER ADD] route segments %s", uri_segments);

		// check if root node needs to be added
		if (!start_nodes.has_key(uri_segments[0]))
		{
			io::printfn("[ROUTER ADD] Creating root node '%s'", uri_segments[0]);
			String key = uri_segments[0].is_braced() ? "{}" : uri_segments[0];

			start_nodes.set(key, new_route_node(uri_segments[0]));
			cur_node = start_nodes.get_ref(key)!!;
		}
		else
		{
			io::printfn("[ROUTER ADD] Using existing root node '%s'", uri_segments[0]);
			cur_node = start_nodes.get_ref(uri_segments[0])!!;
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
			String key = uri_segments[i + 1].is_braced() ? "{}" : uri_segments[i + 1];

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
	HandlerCollection* start_handlers,
	HashMap{String, RouteNode}* start_nodes,
	Logger* log
) @private
{
	RouteNode*? node = get_or_create_node(uri, start_nodes, log);
	if(catch err = node){
		return start_handlers.set_handler(method, handler);
	}
	io::printfn("[ROUTER ADD] Assigning handler to '%s'", node.name);
	return node.handlers.set_handler(method, handler);
}

fn bool String.is_braced(self)
{
	return self[0] == '{' && self[^1] == '}';
}

macro RouteNode new_route_node(String name)
{
	RouteNode node;
	node.init(mem, name);
	return node;
}
