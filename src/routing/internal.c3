// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module c3api::routing::internal;

import std::collections::map;
import std::collections::list;
import std::io;

import c3api::http;
import c3api::log;
import c3api::routing::handler;
import c3api::routing::node;
import c3api::routing::middleware;

<*
 Check whether a route pattern repeats a path parameter name.

 Only braced segments are treated as parameters, matching the router's
 segment rules. The check runs at compile time.

 @param [in] $uri : "Route pattern to inspect"
 @return "True when the same parameter name appears more than once"
*>
macro bool has_duplicate_path_params(String $uri) @const
{
	var $wrapped = "/" +++ $uri +++ "/";
	var $pos = 0;
	$for ; $pos < $wrapped.len; $pos++:
		$if $wrapped[$pos] == '{' &&& $wrapped[$pos - 1] == '/':
			var $end = $pos + 1;
			$for ; $end < $wrapped.len &&& $wrapped[$end] != '}'; $end++:
			$endfor
			$if $end + 1 < $wrapped.len &&& $wrapped[$end + 1] == '/':
				var $name = $wrapped[$pos + 1:$end - $pos - 1];
				var $needle = "/{" +++ $name +++ "}/";
				$if @str_find($wrapped[$end + 1..], $needle) >= 0:
					return true;
				$endif
			$endif
			$pos = $end;
		$endif
	$endfor
	return false;
}

<*
 Traverse the route trie and return handlers for a URI.

 Collects middleware along the matched path and writes dynamic path
 segment values into request arguments.

 @param [in] uri : "Request URI to resolve"
 @param [&in] start_handlers : "Fallback handler collection for root"
 @param [&in] start_nodes : "Root node map to traverse"
 @param [&inout] request : "Request receiving path argument values, or null to skip them"
 @param [&inout] middleware_collector : "Collected middleware callbacks"
 @param [&in] log : "Logger"
 @return "Matching handler collection or ROUTE_NOT_FOUND~"
*>
fn HandlerCollection*? _get_handlers(
	String uri,
	HandlerCollection* start_handlers,
	HashMap{String, RouteNode}* start_nodes,
	HttpRequest* request,
	List{RegisteredMiddleware}* middleware_collector,
	log::Logger log,
)
{
	log.tracef("Getting handlers for route %s", "Retrieving handlers", log::_string("uri", &uri));

	if (uri == "" || uri == "/")
	{
		return start_handlers;
	}

	if (uri[0] == '/' && uri.len > 1) uri = uri[1..];

	sz position          = 0;
	String segment       = next_uri_segment(uri, &position);
	String root_key      = node_key(segment);
	RouteNode*? cur_node = start_nodes.get_ref(root_key);
	if (catch err = cur_node)
	{
		return routing::ROUTE_NOT_FOUND~;
	}

	while (cur_node != null && position < uri.len)
	{
		segment = next_uri_segment(uri, &position);
		if (segment == "") break;

		if (cur_node.has_middleware()) middleware_collector.push_all(cur_node.middlewares.array_view());

		cur_node = cur_node.get_next_node(segment) ?? null;

		if (cur_node == null)
		{
			return routing::ROUTE_NOT_FOUND~;
		}

		if (request != null && cur_node.name.is_braced())
		{
			String key = cur_node.name[1:^2];
			request.params.set_argument_value(key, segment);
		}
	}

	if (cur_node == null)
	{
		log.trace("No matching route found");
		return routing::ROUTE_NOT_FOUND~;
	}

	middleware_collector.push_all(cur_node.middlewares.array_view());
	return &cur_node.handlers;
}

<*
 Read the next slash-delimited URI segment without allocating.

 The position is advanced past the segment and its trailing slash. A
 trailing slash produces a final empty segment, matching `String.split`.

 @param [in] uri : "URI to read from"
 @param [&inout] position : "Current read position, advanced past the segment"
 @return "Next URI segment, or an empty string when the URI is exhausted"
*>
fn String next_uri_segment(String uri, sz* position) @private
{
	sz start = *position;
	if (start >= uri.len) return "";

	sz slash = uri.index_of_char_from('/', start) ?? uri.len;
	if (slash == start)
	{
		*position = start + 1;
		return "";
	}

	*position = slash + 1;
	return slash == uri.len ? uri[start..] : uri[start..slash - 1];
}

<*
 Raised when an insertion URI points at the root scope.
*>
faultdef REFERS_TO_ROOT;

<*
 Check whether a requested dynamic segment conflicts with an existing one.

 @param [in] existing : "Parameter name already stored by the node"
 @param [in] requested : "Parameter name from the new registration"
 @return "True when both segments are dynamic and use different names"
*>
fn bool has_dynamic_name_conflict(String existing, String requested)
{
	return requested.is_braced() && existing.is_braced() && existing != requested;
}

<*
 Abort when a registration reuses a dynamic branch with another parameter name.

 @param [in] uri : "Route pattern being registered"
 @param [&in] node : "Existing dynamic branch"
 @param [in] segment : "Dynamic segment from the new registration"
 @param [&in] log : "Logger receiving the error entry"
*>
fn void _abort_on_dynamic_name_conflict(String uri, RouteNode* node, String segment, log::Logger log) @private
{
	if (!has_dynamic_name_conflict(node.name, segment)) return;

	log.errorf(
		"Route '%s' conflicts with existing parameter '%s'; requested '%s'",
		"route parameter name conflict",
		log::_string("uri", &uri),
		log::_string("existing", &node.name),
		log::_string("requested", &segment)
	);
	abort("Route parameter name conflict in '%s': existing '%s', requested '%s'", uri, node.name, segment);
}

<*
 Get or create the route node corresponding to the given URI.

 Root-level URIs return REFERS_TO_ROOT~ so callers can attach directly
 to root handlers or middleware collections.

 @param [in] uri : "Route pattern to resolve"
 @param [&inout] start_nodes : "Root node map"
 @param [&in] log : "Logger"
 @return "Resolved node pointer or REFERS_TO_ROOT~"
*>
fn RouteNode*? _get_or_create_node(String uri, HashMap{String, RouteNode}* start_nodes, log::Logger log)
{
	@pool()
	{
		String original_uri = uri;

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
			_abort_on_dynamic_name_conflict(original_uri, cur_node, uri_segments[0], log);
		}

		// traverse node tree down
		foreach (i, segment : uri_segments[1..^1])
		{
			String key = node_key(segment);

			if (cur_node.sub_nodes.has_key(key))
			{
				cur_node = cur_node.sub_nodes.get_ref(key)!!;
				_abort_on_dynamic_name_conflict(original_uri, cur_node, segment, log);

				log.tracef(
					"Using existing route node '%s'",
					"Found existing route node",
					log::_string("uri", &cur_node.name)
				);
				continue;
			}

			log.tracef("Creating new route node '%s'", "Created new route node", log::_string("name", &key));

			cur_node.sub_nodes[key] = new_route_node(segment);
			cur_node = cur_node.sub_nodes.get_ref(key)!!;
		}

		return cur_node;
	};
}

<*
 Add or replace a route handler and attach route middleware.

 @param [in] uri : "Route pattern"
 @param method : "HTTP method"
 @param handler : "Handler callback"
 @param instance : "Optional instance passed as the handler's self argument"
 @param middlewares : "Middleware callbacks to attach to the route"
 @param [&inout] start_handlers : "Root handler collection"
 @param [&inout] start_middlewares : "Root middleware collection"
 @param [&inout] start_nodes : "Root node map"
 @param [&in] log : "Logger"
 @return "True if an existing handler was replaced"
*>
fn bool _add_handler(
	String uri,
	RouteMethod method,
	HandleFunc handler,
	void* instance,
	RegisteredMiddleware[] middlewares,
	HandlerCollection* start_handlers,
	List{RegisteredMiddleware}* start_middlewares,
	HashMap{String, RouteNode}* start_nodes,
	log::Logger log
)
{
	RouteNode*? node = internal::_get_or_create_node(uri, start_nodes, log);
	if (catch err = node)
	{
		start_middlewares.push_all(middlewares);
		return start_handlers.set_handler(method, handler, instance);
	}
	log.tracef("Assigning handler to '%s'", "Assigned handler to node", log::_string("node", &node.name));
	log.tracef("Adding middlewares to '%s'", "Adding middlewares to node", log::_string("node", &node.name));
	node.middlewares.push_all(middlewares);

	return node.handlers.set_handler(method, handler, instance);
}

<*
 Check whether a segment is a dynamic braced segment.

 @param [in] self : "Route segment to inspect"
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

 @param name : "Path segment represented by the node"
 @return "Initialized route node"
*>
macro RouteNode new_route_node(String name) @private
{
	RouteNode node;
	node.init(mem, name);
	return node;
}