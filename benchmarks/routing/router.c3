// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module routing_benchmarks;

import std::core::mem;
import std::core::mem::allocators;
import std::collections::list;

import c3api::http;
import c3api::http::request;
import c3api::context;
import c3api::log;
import c3api::routing;
import c3api::routing::router;
import c3api::routing::handler;
import c3api::routing::middleware;

fn void router_init_free() @benchmark => @pool()
{
	start_timed();
	for (sz i = 0; i < INIT_OPS; ++i)
	{
		router::Router r;
		r.init(mem, &bench_logger);
		r.free();
	}
	end_timed();

	DynamicArenaAllocator arena;
	arena.init(mem, 4096);
	TrackingAllocator tracker;
	tracker.init(&arena);
	AllocSnapshot before = alloc_snapshot(&tracker);
	mem::@scoped(&tracker)
	{
		for (sz i = 0; i < ALLOC_INIT_OPS; ++i)
		{
			router::Router r;
			r.init(mem, &bench_logger);
			r.free();
		}
	};
	log_memory_stats("router init+free", &tracker, before, ALLOC_INIT_OPS, 0);
	tracker.free();
	arena.free();
}

fn void router_register_static() @benchmark => @pool()
{
	sz count = ROUTE_COUNT;
	String[] paths = make_static_paths(count);

	router::Router timed;
	timed.init(mem, &bench_logger);
	start_timed();
	foreach (p : paths) timed.get(p, &noop_handler);
	end_timed();
	free_router_nodes(&timed, mem);

	DynamicArenaAllocator arena;
	arena.init(mem, 4096);
	TrackingAllocator tracker;
	tracker.init(&arena);
	router::Router tracked;
	AllocSnapshot before = {};
	mem::@scoped(&tracker)
	{
		tracked.init(mem, &bench_logger);
		before = alloc_snapshot(&tracker);
		foreach (p : paths) tracked.get(p, &noop_handler);
	};
	tracked.free();
	log_memory_stats("router register static", &tracker, before, count, 0);
	tracker.free();
	arena.free();
	free_paths(paths);
}

fn void router_register_dynamic() @benchmark => @pool()
{
	sz count = ROUTE_COUNT;
	String[] paths = make_dynamic_routes(count);

	router::Router timed;
	timed.init(mem, &bench_logger);
	start_timed();
	foreach (p : paths) timed.get(p, &noop_handler);
	end_timed();
	free_router_nodes(&timed, mem);

	DynamicArenaAllocator arena;
	arena.init(mem, 4096);
	TrackingAllocator tracker;
	tracker.init(&arena);
	router::Router tracked;
	AllocSnapshot before = {};
	mem::@scoped(&tracker)
	{
		tracked.init(mem, &bench_logger);
		before = alloc_snapshot(&tracker);
		foreach (p : paths) tracked.get(p, &noop_handler);
	};
	tracked.free();
	log_memory_stats("router register dynamic", &tracker, before, count, 0);
	tracker.free();
	arena.free();
	free_paths(paths);
}

fn void router_register_deep() @benchmark => @pool()
{
	sz count = DEEP_ROUTE_COUNT;
	String[] paths = make_deep_routes(count);

	router::Router timed;
	timed.init(mem, &bench_logger);
	start_timed();
	foreach (p : paths) timed.get(p, &noop_handler);
	end_timed();
	free_router_nodes(&timed, mem);

	DynamicArenaAllocator arena;
	arena.init(mem, 4096);
	TrackingAllocator tracker;
	tracker.init(&arena);
	router::Router tracked;
	AllocSnapshot before = {};
	mem::@scoped(&tracker)
	{
		tracked.init(mem, &bench_logger);
		before = alloc_snapshot(&tracker);
		foreach (p : paths) tracked.get(p, &noop_handler);
	};
	tracked.free();
	log_memory_stats("router register deep", &tracker, before, count, 0);
	tracker.free();
	arena.free();
	free_paths(paths);
}

fn void router_lookup_static() @benchmark => @pool()
{
	sz count = ROUTE_COUNT;
	String[] paths = make_static_paths(count);

	router::Router timed;
	timed.init(mem, &bench_logger);
	foreach (p : paths) timed.get(p, &noop_handler);
	HttpRequest req;
	req.init(mem);
	List{RegisteredMiddleware} collector;
	collector.init(mem);
	usz pseudo = 0;

	start_timed();
	for (sz i = 0; i < LOOKUP_COUNT; ++i)
	{
		req.reset();
		collector.clear();
		if (try handlers = timed.get_handlers(paths[i % count], &req, &collector))
		{
			if (try h = handlers.get_handler(RouteMethod.GET)) pseudo += (usz)h;
		}
	}
	end_timed();

	collector.free();
	req.free();
	free_router_nodes(&timed, mem);

	DynamicArenaAllocator arena;
	arena.init(mem, 4096);
	TrackingAllocator tracker;
	tracker.init(&arena);
	router::Router tracked;
	HttpRequest treq;
	List{RegisteredMiddleware} tcollector;
	mem::@scoped(&tracker)
	{
		tracked.init(mem, &bench_logger);
		foreach (p : paths) tracked.get(p, &noop_handler);
		treq.init(mem);
		tcollector.init(mem);
	};
	AllocSnapshot before = alloc_snapshot(&tracker);
	usz tpseudo = 0;
	mem::@scoped(&tracker)
	{
		for (sz i = 0; i < ALLOC_LOOKUP_COUNT; ++i)
		{
			treq.reset();
			tcollector.clear();
			if (try handlers = tracked.get_handlers(paths[i % count], &treq, &tcollector))
			{
				if (try h = handlers.get_handler(RouteMethod.GET)) tpseudo += (usz)h;
			}
		}
	};
	tcollector.free();
	treq.free();
	tracked.free();
	log_memory_stats("router lookup static", &tracker, before, ALLOC_LOOKUP_COUNT, pseudo + tpseudo);
	tracker.free();
	arena.free();
	free_paths(paths);
}

fn void router_lookup_dynamic() @benchmark => @pool()
{
	sz count = ROUTE_COUNT;
	String[] routes = make_dynamic_routes(count);
	String[] uris = make_dynamic_uris(count);

	router::Router timed;
	timed.init(mem, &bench_logger);
	foreach (p : routes) timed.get(p, &noop_handler);
	HttpRequest req;
	req.init(mem);
	List{RegisteredMiddleware} collector;
	collector.init(mem);
	usz pseudo = 0;

	start_timed();
	for (sz i = 0; i < LOOKUP_COUNT; ++i)
	{
		req.reset();
		collector.clear();
		if (try handlers = timed.get_handlers(uris[i % count], &req, &collector))
		{
			if (try h = handlers.get_handler(RouteMethod.GET)) pseudo += (usz)h;
		}
		if (try v = req.params["id"]) pseudo += (usz)v.len;
	}
	end_timed();

	collector.free();
	req.free();
	free_router_nodes(&timed, mem);

	DynamicArenaAllocator arena;
	arena.init(mem, 4096);
	TrackingAllocator tracker;
	tracker.init(&arena);
	router::Router tracked;
	HttpRequest treq;
	List{RegisteredMiddleware} tcollector;
	mem::@scoped(&tracker)
	{
		tracked.init(mem, &bench_logger);
		foreach (p : routes) tracked.get(p, &noop_handler);
		treq.init(mem);
		tcollector.init(mem);
	};
	AllocSnapshot before = alloc_snapshot(&tracker);
	usz tpseudo = 0;
	mem::@scoped(&tracker)
	{
		for (sz i = 0; i < ALLOC_LOOKUP_COUNT; ++i)
		{
			treq.reset();
			tcollector.clear();
			if (try handlers = tracked.get_handlers(uris[i % count], &treq, &tcollector))
			{
				if (try h = handlers.get_handler(RouteMethod.GET)) tpseudo += (usz)h;
			}
			if (try v = treq.params["id"]) tpseudo += (usz)v.len;
		}
	};
	tcollector.free();
	treq.free();
	tracked.free();
	log_memory_stats("router lookup dynamic", &tracker, before, ALLOC_LOOKUP_COUNT, pseudo + tpseudo);
	tracker.free();
	arena.free();
	free_paths(routes);
	free_paths(uris);
}

fn void router_lookup_deep() @benchmark => @pool()
{
	sz count = DEEP_ROUTE_COUNT;
	String[] routes = make_deep_routes(count);
	String[] uris = make_deep_uris(count);

	router::Router timed;
	timed.init(mem, &bench_logger);
	foreach (p : routes) timed.get(p, &noop_handler);
	HttpRequest req;
	req.init(mem);
	List{RegisteredMiddleware} collector;
	collector.init(mem);
	usz pseudo = 0;

	start_timed();
	for (sz i = 0; i < LOOKUP_COUNT; ++i)
	{
		req.reset();
		collector.clear();
		if (try handlers = timed.get_handlers(uris[i % count], &req, &collector))
		{
			if (try h = handlers.get_handler(RouteMethod.GET)) pseudo += (usz)h;
		}
		if (try v = req.params["id"]) pseudo += (usz)v.len;
	}
	end_timed();

	collector.free();
	req.free();
	free_router_nodes(&timed, mem);

	DynamicArenaAllocator arena;
	arena.init(mem, 4096);
	TrackingAllocator tracker;
	tracker.init(&arena);
	router::Router tracked;
	HttpRequest treq;
	List{RegisteredMiddleware} tcollector;
	mem::@scoped(&tracker)
	{
		tracked.init(mem, &bench_logger);
		foreach (p : routes) tracked.get(p, &noop_handler);
		treq.init(mem);
		tcollector.init(mem);
	};
	AllocSnapshot before = alloc_snapshot(&tracker);
	usz tpseudo = 0;
	mem::@scoped(&tracker)
	{
		for (sz i = 0; i < ALLOC_LOOKUP_COUNT; ++i)
		{
			treq.reset();
			tcollector.clear();
			if (try handlers = tracked.get_handlers(uris[i % count], &treq, &tcollector))
			{
				if (try h = handlers.get_handler(RouteMethod.GET)) tpseudo += (usz)h;
			}
			if (try v = treq.params["id"]) tpseudo += (usz)v.len;
		}
	};
	tcollector.free();
	treq.free();
	tracked.free();
	log_memory_stats("router lookup deep", &tracker, before, ALLOC_LOOKUP_COUNT, pseudo + tpseudo);
	tracker.free();
	arena.free();
	free_paths(routes);
	free_paths(uris);
}

fn void router_lookup_miss() @benchmark => @pool()
{
	sz count = ROUTE_COUNT;
	String[] routes = make_static_paths(count);
	String[] uris = make_miss_uris(count);

	router::Router timed;
	timed.init(mem, &bench_logger);
	foreach (p : routes) timed.get(p, &noop_handler);
	HttpRequest req;
	req.init(mem);
	List{RegisteredMiddleware} collector;
	collector.init(mem);
	usz pseudo = 0;

	start_timed();
	for (sz i = 0; i < LOOKUP_COUNT; ++i)
	{
		req.reset();
		collector.clear();
		if (try handlers = timed.get_handlers(uris[i % count], &req, &collector))
		{
			pseudo += (usz)handlers;
		}
		else
		{
			pseudo++;
		}
	}
	end_timed();

	collector.free();
	req.free();
	free_router_nodes(&timed, mem);

	DynamicArenaAllocator arena;
	arena.init(mem, 4096);
	TrackingAllocator tracker;
	tracker.init(&arena);
	router::Router tracked;
	HttpRequest treq;
	List{RegisteredMiddleware} tcollector;
	mem::@scoped(&tracker)
	{
		tracked.init(mem, &bench_logger);
		foreach (p : routes) tracked.get(p, &noop_handler);
		treq.init(mem);
		tcollector.init(mem);
	};
	AllocSnapshot before = alloc_snapshot(&tracker);
	usz tpseudo = 0;
	mem::@scoped(&tracker)
	{
		for (sz i = 0; i < ALLOC_LOOKUP_COUNT; ++i)
		{
			treq.reset();
			tcollector.clear();
			if (try handlers = tracked.get_handlers(uris[i % count], &treq, &tcollector))
			{
				tpseudo += (usz)handlers;
			}
			else
			{
				tpseudo++;
			}
		}
	};
	tcollector.free();
	treq.free();
	tracked.free();
	log_memory_stats("router lookup miss", &tracker, before, ALLOC_LOOKUP_COUNT, pseudo + tpseudo);
	tracker.free();
	arena.free();
	free_paths(routes);
	free_paths(uris);
}

fn void router_lookup_middleware() @benchmark => @pool()
{
	sz count = ROUTE_COUNT;
	String[] paths = make_static_paths(count);

	router::Router timed;
	timed.init(mem, &bench_logger);
	foreach (p : paths) timed.get(p, &noop_handler);
	timed.use("/api", &noop_middleware);
	timed.use("/api/v1", &noop_middleware);
	timed.use("/api/v1/static", &noop_middleware);
	HttpRequest req;
	req.init(mem);
	List{RegisteredMiddleware} collector;
	collector.init(mem);
	usz pseudo = 0;

	start_timed();
	for (sz i = 0; i < LOOKUP_COUNT; ++i)
	{
		req.reset();
		collector.clear();
		if (try handlers = timed.get_handlers(paths[i % count], &req, &collector))
		{
			if (try h = handlers.get_handler(RouteMethod.GET)) pseudo += (usz)h;
		}
		pseudo += (usz)collector.len();
	}
	end_timed();

	collector.free();
	req.free();
	free_router_nodes(&timed, mem);

	DynamicArenaAllocator arena;
	arena.init(mem, 4096);
	TrackingAllocator tracker;
	tracker.init(&arena);
	router::Router tracked;
	HttpRequest treq;
	List{RegisteredMiddleware} tcollector;
	mem::@scoped(&tracker)
	{
		tracked.init(mem, &bench_logger);
		foreach (p : paths) tracked.get(p, &noop_handler);
		tracked.use("/api", &noop_middleware);
		tracked.use("/api/v1", &noop_middleware);
		tracked.use("/api/v1/static", &noop_middleware);
		treq.init(mem);
		tcollector.init(mem);
	};
	AllocSnapshot before = alloc_snapshot(&tracker);
	usz tpseudo = 0;
	mem::@scoped(&tracker)
	{
		for (sz i = 0; i < ALLOC_LOOKUP_COUNT; ++i)
		{
			treq.reset();
			tcollector.clear();
			if (try handlers = tracked.get_handlers(paths[i % count], &treq, &tcollector))
			{
				if (try h = handlers.get_handler(RouteMethod.GET)) tpseudo += (usz)h;
			}
			tpseudo += (usz)tcollector.len();
		}
	};
	tcollector.free();
	treq.free();
	tracked.free();
	log_memory_stats("router lookup middleware", &tracker, before, ALLOC_LOOKUP_COUNT, pseudo + tpseudo);
	tracker.free();
	arena.free();
	free_paths(paths);
}

fn void router_get_route_head() @benchmark => @pool()
{
	sz count = ROUTE_COUNT;
	String[] paths = make_static_paths(count);

	router::Router timed;
	timed.init(mem, &bench_logger);
	foreach (p : paths) timed.get(p, &noop_handler);
	HttpRequest req;
	req.init(mem);
	List{RegisteredMiddleware} collector;
	collector.init(mem);
	usz pseudo = 0;

	start_timed();
	for (sz i = 0; i < LOOKUP_COUNT; ++i)
	{
		req.reset();
		collector.clear();
		if (try h = timed.get_route(RouteMethod.HEAD, paths[i % count], &req, &collector))
		{
			pseudo += (usz)h;
		}
	}
	end_timed();

	collector.free();
	req.free();
	free_router_nodes(&timed, mem);

	DynamicArenaAllocator arena;
	arena.init(mem, 4096);
	TrackingAllocator tracker;
	tracker.init(&arena);
	router::Router tracked;
	HttpRequest treq;
	List{RegisteredMiddleware} tcollector;
	mem::@scoped(&tracker)
	{
		tracked.init(mem, &bench_logger);
		foreach (p : paths) tracked.get(p, &noop_handler);
		treq.init(mem);
		tcollector.init(mem);
	};
	AllocSnapshot before = alloc_snapshot(&tracker);
	usz tpseudo = 0;
	mem::@scoped(&tracker)
	{
		for (sz i = 0; i < ALLOC_LOOKUP_COUNT; ++i)
		{
			treq.reset();
			tcollector.clear();
			if (try h = tracked.get_route(RouteMethod.HEAD, paths[i % count], &treq, &tcollector))
			{
				tpseudo += (usz)h;
			}
		}
	};
	tcollector.free();
	treq.free();
	tracked.free();
	log_memory_stats("router get_route HEAD fallback", &tracker, before, ALLOC_LOOKUP_COUNT, pseudo + tpseudo);
	tracker.free();
	arena.free();
	free_paths(paths);
}
