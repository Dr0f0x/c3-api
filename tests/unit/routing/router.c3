// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module test::routing;

import std::core::mem;
import std::collections::list;

import c3api::context;
import c3api::http;
import c3api::http::request;
import c3api::log;
import c3api::routing::handler;
import c3api::routing::middleware;
import c3api::routing::router;

struct TestRouter
{
	router::Router router;
	log::C3ApiLogger logger;
}

fn void TestRouter.init(&self)
{
	self.init_with(mem);
}

fn void TestRouter.init_with(&self, Allocator allocator)
{
	self.logger.init(allocator);
	self.router.init(allocator, &self.logger);
}

fn void TestRouter.free(&self)
{
	self.router.free();
	self.logger.free();
}

fn void noop_handler(void* self = null, Allocator allocator, HandlerContext* ctx, HttpRequest* req, HttpResponse* res)
{
}

fn void assert_route(TestRouter* tr, String uri, void* expected)
{
	HttpRequest req;
	req.init(mem);
	defer req.free();

	List{RegisteredMiddleware} collector;
	collector.init(mem);
	defer collector.free();

	RegisteredHandler* handler = tr.router.get_route(RouteMethod.GET, uri, &req, &collector) ?? null;
	assert(handler != null);
	assert(handler.self == expected);
	assert(handler.handler == &noop_handler);
}

fn void test_router_lookup_accepts_leading_and_trailing_slashes() @test
{
	TestRouter tr;
	tr.init();
	defer tr.free();

	int marker;
	tr.router.get("/api/v1/resource", &noop_handler, (void*)&marker);

	assert_route(&tr, "/api/v1/resource", (void*)&marker);
	assert_route(&tr, "api/v1/resource", (void*)&marker);
	assert_route(&tr, "/api/v1/resource/", (void*)&marker);
	assert_route(&tr, "/api/v1/resource//", (void*)&marker);
}

fn void test_router_lookup_accepts_registered_uri_without_leading_slash() @test
{
	TestRouter tr;
	tr.init();
	defer tr.free();

	int marker;
	tr.router.get("api/no-leading-slash", &noop_handler, (void*)&marker);

	assert_route(&tr, "/api/no-leading-slash", (void*)&marker);
	assert_route(&tr, "api/no-leading-slash", (void*)&marker);
}

fn void test_router_lookup_empty_segment_stops_at_parent() @test
{
	TestRouter tr;
	tr.init();
	defer tr.free();

	int parent_marker;
	int child_marker;
	tr.router.get("/api", &noop_handler, (void*)&parent_marker);
	tr.router.get("/api/v1", &noop_handler, (void*)&child_marker);

	assert_route(&tr, "/api//v1", (void*)&parent_marker);
	assert_route(&tr, "/api/v1", (void*)&child_marker);
}

fn void test_router_lookup_root_route() @test
{
	TestRouter tr;
	tr.init();
	defer tr.free();

	int marker;
	tr.router.get("/", &noop_handler, (void*)&marker);

	assert_route(&tr, "/", (void*)&marker);
	assert_route(&tr, "", (void*)&marker);
}

fn void test_router_lookup_dynamic_params() @test
{
	TestRouter tr;
	tr.init();
	defer tr.free();

	int marker;
	tr.router.get("/api/users/{id}", &noop_handler, (void*)&marker);

	HttpRequest req;
	req.init(mem);
	defer req.free();

	List{RegisteredMiddleware} collector;
	collector.init(mem);
	defer collector.free();

	RegisteredHandler* handler = tr.router.get_route(RouteMethod.GET, "/api/users/42", &req, &collector) ?? null;
	assert(handler != null);
	assert(handler.self == (void*)&marker);
	assert(req.params["id"]!! == "42");

	req.reset();
	handler = tr.router.get_route(RouteMethod.GET, "/api/users/42/", &req, &collector) ?? null;
	assert(handler != null);
	assert(handler.self == (void*)&marker);
	assert(req.params["id"]!! == "42");
}

fn void test_router_lookup_dynamic_route_with_request() @test
{
	TestRouter tr;
	tr.init();
	defer tr.free();

	int marker;
	tr.router.get("/api/users/{id}", &noop_handler, (void*)&marker);

	assert_route(&tr, "/api/users/42", (void*)&marker);
}

fn void test_router_lookup_deep_dynamic_route() @test
{
	TestRouter tr;
	tr.init();
	defer tr.free();

	int marker;
	tr.router.get("/api/v1/resource-7/child/grandchild/{id}", &noop_handler, (void*)&marker);

	HttpRequest req;
	req.init(mem);
	defer req.free();

	List{RegisteredMiddleware} collector;
	collector.init(mem);
	defer collector.free();

	RegisteredHandler* handler = tr.router.get_route(
		RouteMethod.GET,
		"/api/v1/resource-7/child/grandchild/value-9",
		&req,
		&collector
	) ?? null;
	assert(handler != null);
	assert(handler.self == (void*)&marker);
	assert(req.params["id"]!! == "value-9");
}

fn void test_router_lookup_distinguishes_sibling_routes() @test
{
	TestRouter tr;
	tr.init();
	defer tr.free();

	int first_marker;
	int second_marker;
	tr.router.get("/api/first", &noop_handler, (void*)&first_marker);
	tr.router.get("/api/second", &noop_handler, (void*)&second_marker);

	assert_route(&tr, "/api/first", (void*)&first_marker);
	assert_route(&tr, "/api/second", (void*)&second_marker);
}

fn void test_router_lookup_head_falls_back_to_get() @test
{
	TestRouter tr;
	tr.init();
	defer tr.free();

	int marker;
	tr.router.get("/api/resource", &noop_handler, (void*)&marker);

	HttpRequest req;
	req.init(mem);
	defer req.free();

	List{RegisteredMiddleware} collector;
	collector.init(mem);
	defer collector.free();

	RegisteredHandler* handler = tr.router.get_route(RouteMethod.HEAD, "/api/resource", &req, &collector) ?? null;
	assert(handler != null);
	assert(handler.self == (void*)&marker);
	assert(handler.handler == &noop_handler);
}

fn void test_router_lookup_rejects_wrong_method_and_missing_route() @test
{
	TestRouter tr;
	tr.init();
	defer tr.free();

	int marker;
	tr.router.get("/api/resource", &noop_handler, (void*)&marker);

	HttpRequest req;
	req.init(mem);
	defer req.free();

	List{RegisteredMiddleware} collector;
	collector.init(mem);
	defer collector.free();

	RegisteredHandler* handler = tr.router.get_route(RouteMethod.POST, "/api/resource", &req, &collector) ?? null;
	assert(handler == null);

	handler = tr.router.get_route(RouteMethod.GET, "/api/missing", &req, &collector) ?? null;
	assert(handler == null);
}