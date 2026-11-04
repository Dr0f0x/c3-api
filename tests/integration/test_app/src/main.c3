// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module integration_app;

import c3api;
import c3api::routing;
import c3api::routing::router;

fn void health(void* self = null, Allocator allocator, HandlerContext* ctx, HttpRequest* req, HttpResponse* res)
{
	res.status = HttpStatus.OK;
	res.body = "ok";
}

fn int main(String[] args)
{
	c3api::Server server;
	server.init(tmem)!!;

	router::Router* router = server.get_router();
	router.get("/health", &health);

	server.run()!!;

	return 0;
}