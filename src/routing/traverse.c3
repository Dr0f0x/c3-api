module c3api::routing;

import std::collections::map;
import std::collections::list;
import std::io;

import c3api::http;
import c3api::log;

<*
 Traverse the route trie and return handlers for a URI.

 Collects middleware along the matched path and writes dynamic path
 segment values into request arguments.

 @param [in] uri : "Request URI to resolve"
 @param [&in] start_handlers : "Fallback handler collection for root"
 @param [&in] start_nodes : "Root node map to traverse"
 @param [&inout] request : "Request receiving path argument values"
 @param [&inout] middleware_collector : "Collected middleware callbacks"
 @param [&in] log : "Logger"
 @return "Matching handler collection or ROUTE_NOT_FOUND~"
*>
fn HandlerCollection*? get_handlers(
	String uri,
	HandlerCollection* start_handlers,
	HashMap{String, RouteNode}* start_nodes,
	HttpRequest* request,
	List{MiddlewareFunc}* middleware_collector,
	log::Logger log,
) @private
{
	log.tracef("Getting handlers for route %s", "Retrieving handlers", log::_string("uri", &uri));

	if (uri == "" || uri == "/")
	{
		return start_handlers;
	}

	String old_uri;
	if (uri[0] == '/' && uri.len > 1)
	{
		// remove leading slash
		old_uri = uri;
		uri = uri[1..];
	}

	String[] uri_segments = uri.tsplit("/");
	log.tracef("Normalized route into segments: %s", "route normalized", log::_string_arr("segments", &uri_segments));

	String root_key      = node_key(uri_segments[0]);
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

		cur_node = cur_node.get_next_node(uri_segments[i]) ?? null;

		if (cur_node == null)
		{
			return ROUTE_NOT_FOUND~;
		}

		if (cur_node.name[0] == '{' && cur_node.name[^1] == '}')
		{
			String key = cur_node.name[1:^2];
			request.args.set_argument_value(key, uri_segments[i]);
		}

		i++;
	}

	if (cur_node == null)
	{
		log.trace("No matching route found");
		return ROUTE_NOT_FOUND~;
	}

	middleware_collector.push_all(cur_node.middlewares.array_view());
	return &cur_node.handlers;
}

<*
 Raised when an insertion URI points at the root scope.
*>
faultdef REFERS_TO_ROOT;

<*
 Get or create the route node corresponding to the given URI.

 Root-level URIs return REFERS_TO_ROOT~ so callers can attach directly
 to root handlers or middleware collections.

 @param [in] uri : "Route pattern to resolve"
 @param [&inout] start_nodes : "Root node map"
 @param [&in] log : "Logger"
 @return "Resolved node pointer or REFERS_TO_ROOT~"
*>
fn RouteNode*? get_or_create_node(String uri, HashMap{String, RouteNode}* start_nodes, log::Logger log) @private
{
	@pool()
	{
		log.tracef("Retrieving route node at '%s'", "Retrieving route node", log::_string("uri", &uri));

		// would be root route
		if (uri == "/" || uri.len == 0)
		{
			return REFERS_TO_ROOT~;
		}

		// remove leading slash
		if (uri[0] == '/' && uri.len > 1) uri = uri[1..];

		String[] uri_segments = uri.tsplit("/");

		RouteNode* cur_node;
		String root_key = node_key(uri_segments[0]);

		log.tracef(
			"Normalized route into segments: %s",
			"route normalized",
			log::_string_arr("segments", &uri_segments)
		);

		// check if root node needs to be added
		if (!start_nodes.has_key(root_key))
		{
			log.tracef(
				"Creating new route node '%s'",
				"Created new route node",
				log::_string("name", &uri_segments[0])
			);

			start_nodes.set(root_key, new_route_node(uri_segments[0]));
			cur_node = start_nodes.get_ref(root_key)!!;
		}
		else
		{
			log.tracef(
				"Using existing route node '%s'",
				"Found existing route node",
				log::_string("uri", &uri_segments[0])
			);
			cur_node = start_nodes.get_ref(root_key)!!;
		}

		// traverse node tree down
		foreach (i, segment : uri_segments[..^2])
		{
			if (try new_cur_node = cur_node.get_next_node(segment))
			{
				log.tracef(
					"Using existing route node '%s'",
					"Found existing route node",
					log::_string("uri", &new_cur_node.name)
				);
				cur_node = new_cur_node;
				continue;
			}
			String key = node_key(uri_segments[i + 1]);

			log.tracef("Creating new route node '%s'", "Created new route node", log::_string("name", &key));
			cur_node.sub_nodes[key] = new_route_node(uri_segments[i + 1]);
			cur_node = cur_node.sub_nodes.get_ref(key)!!;
		}

		return cur_node;
	};
}

<*
 Add or replace a route handler and attach route middleware.

 When uri refers to root, handler and middleware are attached to the
 provided root collections.

 @param [in] uri : "Route pattern"
 @param method : "HTTP method"
 @param handler : "Handler callback"
 @param controller : "Optional controller instance passed as the handler's `self` argument; `null` for free functions"
 @param [&inout] start_handlers : "Root handler collection"
 @param [&inout] start_middlewares : "Root middleware collection"
 @param [&inout] start_nodes : "Root node map"
 @param [&in] log : "Logger"
 @return "True if an existing handler for method was replaced"
*>
fn bool add_handler(
	String uri,
	RouteMethod method,
	HandleFunc handler,
	void* controller,
	MiddlewareFunc[] middlewares,
	HandlerCollection* start_handlers,
	List{MiddlewareFunc}* start_middlewares,
	HashMap{String, RouteNode}* start_nodes,
	log::Logger log
) @private
{
	RouteNode*? node = get_or_create_node(uri, start_nodes, log);
	if (catch err = node)
	{
		start_middlewares.push_all(middlewares);
		return start_handlers.set_handler(method, handler);
	}
	log.tracef("Assigning handler to '%s'", "Assigned handler to node", log::_string("node", &node.name));
	log.tracef("Adding middlewares to '%s'", "Adding middlewares to node", log::_string("node", &node.name));
	node.middlewares.push_all(middlewares);
	return node.handlers.set_handler(method, handler, controller);
}

<*
 Check whether a segment is a dynamic braced segment.

 @return "True for segments such as {name}"
*>
fn bool String.is_braced(self)
{
	return self[0] == '{' && self[^1] == '}';
}

<*
 Convert a route segment to its trie storage key.

 Dynamic segments share the {} key so only one wildcard branch exists
 per node level.

 @param [in] segment : "Raw route segment"
 @return "Storage key used in sub node maps"
*>
fn String node_key(String segment) @private
{
	return segment.is_braced() ? "{}" : segment;
}

<*
 Construct and initialize a RouteNode by segment name.
*>
macro RouteNode new_route_node(String name) @private
{
	RouteNode node;
	node.init(mem, name);
	return node;
}
