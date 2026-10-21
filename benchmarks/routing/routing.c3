// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module routing_benchmarks;

import std::io::path;
import std::core::mem;
import std::core::mem::allocators;
import std::collections::map;
import std::collections::list;

import c3api::http;
import c3api::http::request;
import c3api::context;
import c3api::log;
import c3api::routing;
import c3api::routing::router;
import c3api::routing::group;
import c3api::routing::handler;
import c3api::routing::middleware;
import c3api::routing::node;

const DEFAULT_ITERATIONS = 5;
const ROUTE_COUNT        = 1000;
const DEEP_ROUTE_COUNT   = 500;
const LOOKUP_COUNT       = 50_000;
const ALLOC_LOOKUP_COUNT = 5_000;
const MICRO_OPS          = 1_000_000;
const ALLOC_MICRO_OPS    = 10_000;
const INIT_OPS           = 100_000;
const ALLOC_INIT_OPS     = 10_000;
const MIDDLEWARE_COUNT   = 1000;
const CHILD_COUNT        = 100;

log::C3ApiLogger bench_logger;

fn void bench_setup() @init
{
	set_benchmark_warmup_iterations(2);
	set_benchmark_max_iterations(DEFAULT_ITERATIONS);

	set_benchmark_func_iterations($reflect(router_init_free).qname, 5);
	set_benchmark_func_iterations($reflect(router_register_static).qname, 3);
	set_benchmark_func_iterations($reflect(router_register_dynamic).qname, 3);
	set_benchmark_func_iterations($reflect(router_register_deep).qname, 3);
	set_benchmark_func_iterations($reflect(router_lookup_static).qname, 3);
	set_benchmark_func_iterations($reflect(router_lookup_dynamic).qname, 3);
	set_benchmark_func_iterations($reflect(router_lookup_deep).qname, 3);
	set_benchmark_func_iterations($reflect(router_lookup_miss).qname, 3);
	set_benchmark_func_iterations($reflect(router_lookup_middleware).qname, 3);
	set_benchmark_func_iterations($reflect(router_get_route_head).qname, 3);
	set_benchmark_func_iterations($reflect(router_resolve_static_route_handler).qname, 3);
	set_benchmark_func_iterations($reflect(router_resolve_dynamic_route_handler).qname, 3);
	set_benchmark_func_iterations($reflect(router_resolve_deep_route_handler).qname, 3);
	set_benchmark_func_iterations($reflect(router_resolve_head_fallback).qname, 3);
	set_benchmark_func_iterations($reflect(group_register_nested).qname, 3);
	set_benchmark_func_iterations($reflect(handler_collection_set_get).qname, 3);
	set_benchmark_func_iterations($reflect(middleware_register).qname, 3);
	set_benchmark_func_iterations($reflect(node_init_free).qname, 3);
	set_benchmark_func_iterations($reflect(node_child_lookup).qname, 3);
	set_benchmark_func_iterations($reflect(static_register_routes).qname, 5);

	bench_logger.init(mem);
	csv_init();
}

fn void bench_teardown() @finalizer
{
	csv_shutdown();
	bench_logger.free();
}

fn void noop_handler(void* self = null, Allocator allocator, HandlerContext* ctx, HttpRequest* req, HttpResponse* res)
{
}

fn void noop_middleware(
	void* self = null,
	Allocator allocator,
	MiddlewareContext* ctx,
	HttpRequest* req,
	HttpResponse* res
)
{
	ctx.next(allocator, req, res);
}

fn String[] make_static_paths(sz count)
{
	String[] paths = alloc::new_array(mem, String, count);
	foreach (i, &p : paths) *p = string::format(mem, "/api/v1/static/resource-%d", i);
	return paths;
}

fn String[] make_dynamic_routes(sz count)
{
	String[] paths = alloc::new_array(mem, String, count);
	foreach (i, &p : paths) *p = string::format(mem, "/api/resource-%d/{id}", i);
	return paths;
}

fn String[] make_dynamic_uris(sz count)
{
	String[] paths = alloc::new_array(mem, String, count);
	foreach (i, &p : paths) *p = string::format(mem, "/api/resource-%d/value-%d", i, i);
	return paths;
}

fn String[] make_deep_routes(sz count)
{
	String[] paths = alloc::new_array(mem, String, count);
	foreach (i, &p : paths) *p = string::format(mem, "/api/v1/resource-%d/child/grandchild/{id}", i);
	return paths;
}

fn String[] make_deep_uris(sz count)
{
	String[] paths = alloc::new_array(mem, String, count);
	foreach (i, &p : paths) *p = string::format(mem, "/api/v1/resource-%d/child/grandchild/value-%d", i, i);
	return paths;
}

fn String[] make_miss_uris(sz count)
{
	String[] paths = alloc::new_array(mem, String, count);
	foreach (i, &p : paths) *p = string::format(mem, "/api/missing-%d/nope", i);
	return paths;
}

fn String[] make_group_paths(sz count)
{
	String[] paths = alloc::new_array(mem, String, count);
	foreach (i, &p : paths) *p = string::format(mem, "/resource-%d", i);
	return paths;
}

fn String[] make_node_names(sz count)
{
	String[] names = alloc::new_array(mem, String, count);
	foreach (i, &p : names) *p = string::format(mem, "child-%d", i);
	return names;
}

fn void free_paths(String[] paths)
{
	foreach (p : paths) alloc::free(mem, p.ptr);
	alloc::free(mem, paths.ptr);
}

fn void free_node_recursive(RouteNode* node, Allocator allocator)
{
	foreach (child : node.sub_nodes.value_iter())
	{
		free_node_recursive(&child, allocator);
	}
	node.free(allocator);
}

fn void free_node_map(HashMap{String, RouteNode}* nodes, Allocator allocator)
{
	foreach (node : nodes.value_iter())
	{
		free_node_recursive(&node, allocator);
	}
	nodes.free();
}

fn void free_router_nodes(router::Router* r, Allocator allocator)
{
	free_node_map(&r.root_nodes, allocator);
	r.root_middlewares.free();
	r.root_handlers.free();
}

fn void handler_collection_set_get() @benchmark => @pool()
{
	RouteMethod[6] methods = {
		RouteMethod.GET,
		RouteMethod.PATCH,
		RouteMethod.POST,
		RouteMethod.PUT,
		RouteMethod.DELETE,
		RouteMethod.HEAD
	};
	HandlerCollection hc;
	hc.init();
	usz pseudo = 0;

	start_timed();
	for (sz i = 0; i < MICRO_OPS; ++i)
	{
		foreach (m : methods) hc.set_handler(m, &noop_handler);
		foreach (m : methods)
		{
			if (try h = hc.get_handler(m)) pseudo += (usz)h;
			if (hc.has_handler(m)) pseudo++;
		}
	}
	end_timed();
	hc.free();

	DynamicArenaAllocator arena;
	arena.init(mem, 4096);
	TrackingAllocator tracker;
	tracker.init(&arena);
	HandlerCollection thc;
	thc.init();
	AllocSnapshot before = alloc_snapshot(&tracker);
	usz tpseudo          = 0;
	mem::@scoped(&tracker)
	{
		for (sz i = 0; i < ALLOC_MICRO_OPS; ++i)
		{
			foreach (m : methods) thc.set_handler(m, &noop_handler);
			foreach (m : methods)
			{
				if (try h = thc.get_handler(m)) tpseudo += (usz)h;
				if (thc.has_handler(m)) tpseudo++;
			}
		}
	};
	thc.free();
	log_memory_stats("handler collection set/get/has", &tracker, before, ALLOC_MICRO_OPS * 18, pseudo + tpseudo);
	tracker.free();
	arena.free();
}

fn void middleware_register() @benchmark => @pool()
{
	router::Router timed;
	timed.init(mem, &bench_logger);
	start_timed();
	for (sz i = 0; i < MIDDLEWARE_COUNT; ++i) timed.use("/api", &noop_middleware);
	end_timed();
	free_router_nodes(&timed, mem);

	DynamicArenaAllocator arena;
	arena.init(mem, 4096);
	TrackingAllocator tracker;
	tracker.init(&arena);
	router::Router tracked;
	AllocSnapshot before = { };
	mem::@scoped(&tracker)
	{
		tracked.init(mem, &bench_logger);
		before = alloc_snapshot(&tracker);
		for (sz i = 0; i < MIDDLEWARE_COUNT; ++i) tracked.use("/api", &noop_middleware);
	};
	tracked.free();
	log_memory_stats("middleware register", &tracker, before, MIDDLEWARE_COUNT, 0);
	tracker.free();
	arena.free();
}

fn void node_init_free() @benchmark => @pool()
{
	RouteNode node;
	start_timed();
	for (sz i = 0; i < MICRO_OPS; ++i)
	{
		node.init(mem, "root");
		node.free(mem);
	}
	end_timed();

	DynamicArenaAllocator arena;
	arena.init(mem, 4096);
	TrackingAllocator tracker;
	tracker.init(&arena);
	RouteNode tnode;
	AllocSnapshot before = alloc_snapshot(&tracker);
	mem::@scoped(&tracker)
	{
		for (sz i = 0; i < ALLOC_MICRO_OPS; ++i)
		{
			tnode.init(mem, "root");
			tnode.free(&tracker);
		}
	};
	log_memory_stats("node init+free", &tracker, before, ALLOC_MICRO_OPS, 0);
	tracker.free();
	arena.free();
}

fn void node_child_lookup() @benchmark => @pool()
{
	sz count       = CHILD_COUNT;
	String[] names = make_node_names(count);

	RouteNode parent;
	parent.init(mem, "root");
	foreach (name : names)
	{
		RouteNode child;
		child.init(mem, name);
		parent.sub_nodes.set(name, child);
	}
	RouteNode wildcard;
	wildcard.init(mem, "{}");
	parent.sub_nodes.set("{}", wildcard);

	usz pseudo = 0;
	start_timed();
	for (sz i = 0; i < MICRO_OPS; ++i)
	{
		String key = (i & 1) != 0 ? names[i % count] : "not-found";
		if (try child = parent.get_next_node(key)) pseudo += (usz)child;
	}
	end_timed();
	free_node_recursive(&parent, mem);

	DynamicArenaAllocator arena;
	arena.init(mem, 4096);
	TrackingAllocator tracker;
	tracker.init(&arena);
	RouteNode tparent;
	AllocSnapshot before = { };
	mem::@scoped(&tracker)
	{
		tparent.init(mem, "root");
		foreach (name : names)
		{
			RouteNode child;
			child.init(mem, name);
			tparent.sub_nodes.set(name, child);
		}
		RouteNode twildcard;
		twildcard.init(mem, "{}");
		tparent.sub_nodes.set("{}", twildcard);
		before = alloc_snapshot(&tracker);
		for (sz i = 0; i < ALLOC_MICRO_OPS; ++i)
		{
			String key = (i & 1) != 0 ? names[i % count] : "not-found";
			if (try child = tparent.get_next_node(key)) pseudo += (usz)child;
		}
	};
	free_node_recursive(&tparent, &tracker);
	log_memory_stats("node child lookup", &tracker, before, ALLOC_MICRO_OPS, pseudo);
	tracker.free();
	arena.free();
	free_paths(names);
}

fn void static_register_routes() @benchmark => @pool()
{
	Path? dir_opt = path::tnew("examples/basic/static/public");
	if (catch err = dir_opt) return;
	Path dir = dir_opt;
	if (!path::is_dir(dir)) return;

	routing::StaticFiles timed_files;
	timed_files.init(mem, dir);

	DynamicArenaAllocator timed_arena;
	timed_arena.init(mem, 4096);
	router::Router timed;
	mem::@scoped(&timed_arena)
	{
		timed.init(mem, &bench_logger);
		start_timed();
		timed.serve_static("/static", &timed_files)!!;
		end_timed();
	};
	timed.free();
	timed_files.free();
	timed_arena.free();

	DynamicArenaAllocator arena;
	arena.init(mem, 4096);
	TrackingAllocator tracker;
	tracker.init(&arena);
	router::Router tracked;
	routing::StaticFiles tracked_files;
	AllocSnapshot before = { };
	mem::@scoped(&tracker)
	{
		tracked.init(mem, &bench_logger);
		tracked_files.init(&tracker, dir);
		before = alloc_snapshot(&tracker);
		tracked.serve_static("/static", &tracked_files)!!;
	};
	tracked.free();
	tracked_files.free();
	log_memory_stats("static register", &tracker, before, 1, 0);
	tracker.free();
	arena.free();
}