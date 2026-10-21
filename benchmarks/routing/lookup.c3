// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module routing_benchmarks;

import std::core::mem;
import std::core::mem::allocators;
import std::collections::list;

import c3api::http;
import c3api::http::request;
import c3api::routing::router;
import c3api::routing::handler;
import c3api::routing::middleware;

fn void router_resolve_static_route_handler() @benchmark => @pool()
{
	sz count = ROUTE_COUNT;
	String[] paths = make_static_paths(count);
	usz[] instances = alloc::new_array(mem, usz, count);

	router::Router timed;
	timed.init(mem, &bench_logger);
	foreach (i, p : paths) timed.get(p, &noop_handler, (void*)&instances[i]);
	List{RegisteredMiddleware} collector;
	collector.init(mem);
	HttpRequest req;
	req.init(mem);
	usz pseudo = 0;

	start_timed();
	for (sz i = 0; i < LOOKUP_COUNT; ++i)
	{
		if (try h = timed.get_route(RouteMethod.GET, paths[i % count], &req, &collector))
		{
			if (h.self == (void*)&instances[i % count] && h.handler == &noop_handler) pseudo++;
		}
	}
	end_timed();

	collector.free();
	req.free();
	timed.free();

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
		foreach (i, p : paths) tracked.get(p, &noop_handler, (void*)&instances[i]);
		tcollector.init(mem);
		treq.init(mem);
	};
	AllocSnapshot before = alloc_snapshot(&tracker);
	usz tpseudo = 0;
	mem::@scoped(&tracker)
	{
		for (sz i = 0; i < ALLOC_LOOKUP_COUNT; ++i)
		{
			if (try h = tracked.get_route(RouteMethod.GET, paths[i % count], &treq, &tcollector))
			{
				if (h.self == (void*)&instances[i % count] && h.handler == &noop_handler) tpseudo++;
			}
		}
	};
	tcollector.free();
	treq.free();
	tracked.free();
	log_memory_stats("router resolve static route+handler", &tracker, before, ALLOC_LOOKUP_COUNT, pseudo + tpseudo);
	tracker.free();
	arena.free();
	free_paths(paths);
	alloc::free(mem, instances.ptr);
}

fn void router_resolve_dynamic_route_handler() @benchmark => @pool()
{
	sz count = ROUTE_COUNT;
	String[] routes = make_dynamic_routes(count);
	String[] uris = make_dynamic_uris(count);
	usz[] instances = alloc::new_array(mem, usz, count);

	router::Router timed;
	timed.init(mem, &bench_logger);
	foreach (i, p : routes) timed.get(p, &noop_handler, (void*)&instances[i]);
	List{RegisteredMiddleware} collector;
	collector.init(mem);
	HttpRequest req;
	req.init(mem);
	usz pseudo = 0;

	start_timed();
	for (sz i = 0; i < LOOKUP_COUNT; ++i)
	{
		if (try h = timed.get_route(RouteMethod.GET, uris[i % count], &req, &collector))
		{
			if (h.self == (void*)&instances[i % count] && h.handler == &noop_handler) pseudo++;
		}
	}
	end_timed();

	collector.free();
	req.free();
	timed.free();

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
		foreach (i, p : routes) tracked.get(p, &noop_handler, (void*)&instances[i]);
		tcollector.init(mem);
		treq.init(mem);
		(void)tracked.get_route(RouteMethod.GET, uris[0], &treq, &tcollector);
	};
	AllocSnapshot before = alloc_snapshot(&tracker);
	usz tpseudo = 0;
	mem::@scoped(&tracker)
	{
		for (sz i = 0; i < ALLOC_LOOKUP_COUNT; ++i)
		{
			if (try h = tracked.get_route(RouteMethod.GET, uris[i % count], &treq, &tcollector))
			{
				if (h.self == (void*)&instances[i % count] && h.handler == &noop_handler) tpseudo++;
			}
		}
	};
	tcollector.free();
	treq.free();
	tracked.free();
	log_memory_stats("router resolve dynamic route+handler", &tracker, before, ALLOC_LOOKUP_COUNT, pseudo + tpseudo);
	tracker.free();
	arena.free();
	free_paths(routes);
	free_paths(uris);
	alloc::free(mem, instances.ptr);
}

fn void router_resolve_deep_route_handler() @benchmark => @pool()
{
	sz count = DEEP_ROUTE_COUNT;
	String[] routes = make_deep_routes(count);
	String[] uris = make_deep_uris(count);
	usz[] instances = alloc::new_array(mem, usz, count);

	router::Router timed;
	timed.init(mem, &bench_logger);
	foreach (i, p : routes) timed.get(p, &noop_handler, (void*)&instances[i]);
	List{RegisteredMiddleware} collector;
	collector.init(mem);
	HttpRequest req;
	req.init(mem);
	usz pseudo = 0;

	start_timed();
	for (sz i = 0; i < LOOKUP_COUNT; ++i)
	{
		if (try h = timed.get_route(RouteMethod.GET, uris[i % count], &req, &collector))
		{
			if (h.self == (void*)&instances[i % count] && h.handler == &noop_handler) pseudo++;
		}
	}
	end_timed();

	collector.free();
	req.free();
	timed.free();

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
		foreach (i, p : routes) tracked.get(p, &noop_handler, (void*)&instances[i]);
		tcollector.init(mem);
		treq.init(mem);
		(void)tracked.get_route(RouteMethod.GET, uris[0], &treq, &tcollector);
	};
	AllocSnapshot before = alloc_snapshot(&tracker);
	usz tpseudo = 0;
	mem::@scoped(&tracker)
	{
		for (sz i = 0; i < ALLOC_LOOKUP_COUNT; ++i)
		{
			if (try h = tracked.get_route(RouteMethod.GET, uris[i % count], &treq, &tcollector))
			{
				if (h.self == (void*)&instances[i % count] && h.handler == &noop_handler) tpseudo++;
			}
		}
	};
	tcollector.free();
	treq.free();
	tracked.free();
	log_memory_stats("router resolve deep route+handler", &tracker, before, ALLOC_LOOKUP_COUNT, pseudo + tpseudo);
	tracker.free();
	arena.free();
	free_paths(routes);
	free_paths(uris);
	alloc::free(mem, instances.ptr);
}

fn void router_resolve_head_fallback() @benchmark => @pool()
{
	sz count = ROUTE_COUNT;
	String[] paths = make_static_paths(count);
	usz[] instances = alloc::new_array(mem, usz, count);

	router::Router timed;
	timed.init(mem, &bench_logger);
	foreach (i, p : paths) timed.get(p, &noop_handler, (void*)&instances[i]);
	List{RegisteredMiddleware} collector;
	collector.init(mem);
	HttpRequest req;
	req.init(mem);
	usz pseudo = 0;

	start_timed();
	for (sz i = 0; i < LOOKUP_COUNT; ++i)
	{
		if (try h = timed.get_route(RouteMethod.HEAD, paths[i % count], &req, &collector))
		{
			if (h.self == (void*)&instances[i % count] && h.handler == &noop_handler) pseudo++;
		}
	}
	end_timed();

	collector.free();
	req.free();
	timed.free();

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
		foreach (i, p : paths) tracked.get(p, &noop_handler, (void*)&instances[i]);
		tcollector.init(mem);
		treq.init(mem);
	};
	AllocSnapshot before = alloc_snapshot(&tracker);
	usz tpseudo = 0;
	mem::@scoped(&tracker)
	{
		for (sz i = 0; i < ALLOC_LOOKUP_COUNT; ++i)
		{
			if (try h = tracked.get_route(RouteMethod.HEAD, paths[i % count], &treq, &tcollector))
			{
				if (h.self == (void*)&instances[i % count] && h.handler == &noop_handler) tpseudo++;
			}
		}
	};
	tcollector.free();
	treq.free();
	tracked.free();
	log_memory_stats("router resolve HEAD fallback", &tracker, before, ALLOC_LOOKUP_COUNT, pseudo + tpseudo);
	tracker.free();
	arena.free();
	free_paths(paths);
	alloc::free(mem, instances.ptr);
}
