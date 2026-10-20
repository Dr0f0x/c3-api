// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module test;

import std::io;

import c3api::context;
import c3api::http::request;
import c3api::http::response;
import c3api::routing::handler;
import c3api::routing::middleware;

int[8] call_log;
int call_count;
int typed_value = 7;
long typed_long = 11;

fn void record(int value)
{
	call_log[call_count] = value;
	call_count++;
}

fn void reset_log()
{
	call_count = 0;
}

fn void first_middleware(
	void* self = null,
	Allocator allocator,
	MiddlewareContext* ctx,
	HttpRequest* req,
	HttpResponse* res
)
{
	record(1);
	ctx.next(allocator, req, res);
	record(2);
}

fn void second_middleware(
	void* self = null,
	Allocator allocator,
	MiddlewareContext* ctx,
	HttpRequest* req,
	HttpResponse* res
)
{
	record(3);
	ctx.next(allocator, req, res);
	record(4);
}

fn void stop_middleware(
	void* self = null,
	Allocator allocator,
	MiddlewareContext* ctx,
	HttpRequest* req,
	HttpResponse* res
)
{
	record(1);
}

fn void double_next_middleware(
	void* self = null,
	Allocator allocator,
	MiddlewareContext* ctx,
	HttpRequest* req,
	HttpResponse* res
)
{
	record(1);
	ctx.next(allocator, req, res);
	ctx.next(allocator, req, res);
	record(2);
}

fn void terminal_handler(
	void* self = null,
	Allocator allocator,
	HandlerContext* ctx,
	HttpRequest* req,
	HttpResponse* res
)
{
	record(5);
}

fn void test_basic() @test
{
	int result = 2 + 3;

	assert(result == 5);
}

fn void test_next_runs_chain_in_onion_order() @test
{
	reset_log();

	Context ctx;
	ctx.init(mem);
	defer ctx.free();

	HttpRequest req;
	req.init(mem);
	defer req.free();

	HttpResponse res;
	res.init(mem);
	defer res.free();

	RegisteredMiddleware[2] middlewares = {
		{ .self = null, .middleware = &first_middleware },
		{ .self = null, .middleware = &second_middleware },
	};
	RegisteredHandler handler = { .self = null, .handler = &terminal_handler };

	ctx.setup_handling(middlewares[..], &handler);
	ctx.next(mem, &req, &res);

	assert(call_count == 5);
	assert(call_log[0] == 1);
	assert(call_log[1] == 3);
	assert(call_log[2] == 5);
	assert(call_log[3] == 4);
	assert(call_log[4] == 2);
}

fn void test_skipping_next_stops_pipeline() @test
{
	reset_log();

	Context ctx;
	ctx.init(mem);
	defer ctx.free();

	HttpRequest req;
	req.init(mem);
	defer req.free();

	HttpResponse res;
	res.init(mem);
	defer res.free();

	RegisteredMiddleware[1] middlewares = {
		{ .self = null, .middleware = &stop_middleware },
	};
	RegisteredHandler handler = { .self = null, .handler = &terminal_handler };

	ctx.setup_handling(middlewares[..], &handler);
	ctx.next(mem, &req, &res);

	assert(call_count == 1);
	assert(call_log[0] == 1);
}

fn void test_next_beyond_end_is_noop() @test
{
	reset_log();

	Context ctx;
	ctx.init(mem);
	defer ctx.free();

	HttpRequest req;
	req.init(mem);
	defer req.free();

	HttpResponse res;
	res.init(mem);
	defer res.free();

	RegisteredMiddleware[1] middlewares = {
		{ .self = null, .middleware = &double_next_middleware },
	};
	RegisteredHandler handler = { .self = null, .handler = &terminal_handler };

	ctx.setup_handling(middlewares[..], &handler);
	ctx.next(mem, &req, &res);

	assert(call_count == 3);
	assert(call_log[0] == 1);
	assert(call_log[1] == 5);
	assert(call_log[2] == 2);

	// No terminal handler: advancing past the end must not crash.
	reset_log();
	ctx.setup_handling(middlewares[..], null);
	ctx.next(mem, &req, &res);

	assert(call_count == 2);
	assert(call_log[0] == 1);
	assert(call_log[1] == 2);
}

fn void test_setup_handling_resets_index() @test
{
	reset_log();

	Context ctx;
	ctx.init(mem);
	defer ctx.free();

	HttpRequest req;
	req.init(mem);
	defer req.free();

	HttpResponse res;
	res.init(mem);
	defer res.free();

	RegisteredMiddleware[1] middlewares = {
		{ .self = null, .middleware = &first_middleware },
	};
	RegisteredHandler handler = { .self = null, .handler = &terminal_handler };

	ctx.setup_handling(middlewares[..], &handler);
	ctx.next(mem, &req, &res);
	assert(call_count == 3);

	ctx.setup_handling(middlewares[..], &handler);
	ctx.next(mem, &req, &res);
	assert(call_count == 6);
}

fn void test_context_views_share_request_state() @test
{
	Context ctx;
	ctx.init(mem);
	defer ctx.free();

	HandlerContext handler_ctx       = { .context = &ctx };
	MiddlewareContext middleware_ctx = { .context = &ctx };
	ServerContext server_ctx         = { .context = &ctx };

	handler_ctx.register(int, &typed_value);
	int*? resolved = handler_ctx.resolve(int);
	assert(resolved!! != null);
	assert(*resolved!! == 7);
	assert(middleware_ctx.resolve(int)!! != null);
	assert(server_ctx.resolve(int)!! == &typed_value);

	server_ctx.register(long, &typed_long);
	assert(handler_ctx.resolve(long)!! == &typed_long);

	bool replaced = middleware_ctx.set("key", &typed_value);
	assert(!replaced);
	replaced = handler_ctx.set("key", &typed_value);
	assert(replaced);
	assert(handler_ctx.get("key")!! == &typed_value);

	server_ctx.set("server_key", &typed_long);
	assert(handler_ctx.get("server_key")!! == &typed_long);

	String handler_display = string::tformat("%s", handler_ctx);
	assert(handler_display.contains("middleware_idx"));

	String middleware_display = string::tformat("%s", middleware_ctx);
	assert(middleware_display.contains("objects"));

	String server_display = string::tformat("%s", server_ctx);
	assert(server_display.contains("handler:"));
}