// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module test::routing;

import std::core::mem;
import std::core::mem::allocators;
import std::collections::list;

import c3api::http;
import c3api::http::request;
import c3api::routing::handler;
import c3api::routing::middleware;

const LOOKUP_ITERATIONS = 1000;

fn void test_router_lookup_allocates_nothing() @test
{
	DynamicArenaAllocator arena;
	arena.init(mem, 4096);
	defer arena.free();

	TrackingAllocator tracker;
	tracker.init(&arena);
	defer tracker.free();

	int static_marker;
	int dynamic_marker;
	int deep_marker;

	TestRouter tr;
	HttpRequest req;
	List{RegisteredMiddleware} collector;
	mem::@scoped(&tracker)
	{
		tr.init_with(mem);
		tr.router.get("/api/static", &noop_handler, (void*)&static_marker);
		tr.router.get("/api/users/{id}", &noop_handler, (void*)&dynamic_marker);
		tr.router.get(
			"/api/v1/resource-7/child/grandchild/{id}",
			&noop_handler,
			(void*)&deep_marker
		);
		collector.init(mem);
		req.init(mem);
		(void)tr.router.get_route(RouteMethod.GET, "/api/users/42", &req, &collector);
	};
	defer tr.free();
	defer collector.free();
	defer req.free();

	sz before = tracker.total_allocation_count();

	for (sz i = 0; i < LOOKUP_ITERATIONS; ++i)
	{
		RegisteredHandler* handler = tr.router.get_route(RouteMethod.GET, "/api/static", &req, &collector) ?? null;
		assert(handler != null);
		assert(handler.self == (void*)&static_marker);

		handler = tr.router.get_route(RouteMethod.GET, "/api/users/42", &req, &collector) ?? null;
		assert(handler != null);
		assert(handler.self == (void*)&dynamic_marker);

		handler = tr.router.get_route(
			RouteMethod.GET,
			"/api/v1/resource-7/child/grandchild/value-9",
			&req,
			&collector
		) ?? null;
		assert(handler != null);
		assert(handler.self == (void*)&deep_marker);

		handler = tr.router.get_route(RouteMethod.HEAD, "/api/static", &req, &collector) ?? null;
		assert(handler != null);
		assert(handler.self == (void*)&static_marker);
	}

	assert(tracker.total_allocation_count() == before);
}
