// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module routing_benchmarks;

import std::core::mem;
import std::core::mem::allocators;

import c3api::routing::router;
import c3api::routing::group;

fn void group_register_nested() @benchmark => @pool()
{
	sz count = ROUTE_COUNT;
	String[] paths = make_group_paths(count);

	router::Router timed;
	timed.init(mem, &bench_logger);
	start_timed();
	Group* api = timed.group(mem, "/api");
	Group* v1 = api.group(mem, "/v1");
	Group* users = v1.group(mem, "/users");
	foreach (p : paths) users.get(p, &noop_handler);
	end_timed();
	alloc::free(mem, users);
	alloc::free(mem, v1);
	alloc::free(mem, api);
	free_router_nodes(&timed, mem);

	DynamicArenaAllocator arena;
	arena.init(mem, 4096);
	TrackingAllocator tracker;
	tracker.init(&arena);
	router::Router tracked;
	AllocSnapshot before = {};
	Group* tapi = null;
	Group* tv1 = null;
	Group* tusers = null;
	mem::@scoped(&tracker)
	{
		tracked.init(mem, &bench_logger);
		before = alloc_snapshot(&tracker);
		tapi = tracked.group(mem, "/api");
		tv1 = tapi.group(mem, "/v1");
		tusers = tv1.group(mem, "/users");
		foreach (p : paths) tusers.get(p, &noop_handler);
	};
	alloc::free(&tracker, tusers);
	alloc::free(&tracker, tv1);
	alloc::free(&tracker, tapi);
	tracked.free();
	log_memory_stats("group register nested", &tracker, before, count + 3, 0);
	tracker.free();
	arena.free();
	free_paths(paths);
}
