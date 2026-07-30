// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module app;

import std::collections::map;
import std::io::path;
import std::encoding::json;
import std::time::datetime;

import c3api;
import c3api::http::cookies;
import c3api::config;
import c3api::routing;
import c3api::routing::router;
import c3api::routing::group;

fn void no_controller(void* self = null, Allocator allocator, Context* ctx, HttpRequest* req, HttpResponse* res)
{
	io::printfn("cookie %s", req.get_cookie("test") ?? "-");
	@pool()
	{
		res.status = HttpStatus.OK;
		DString greetings = dstring::temp();
		greetings.appendfn("Look, %s, no controllers!", req.args["name"]!!);
		res.body = string::format(allocator, greetings.tcopy_str(), req.method, req.uri);
	};

	// io::printfn("%s", res);
}

struct JSONResponse
{
	bool test;
	String value;
}

struct Controller
{
	int test;
}

fn void static_no_controller(void* self = null, Allocator allocator, Context* ctx, HttpRequest* req, HttpResponse* res)
{
	io::printfn("%s", req);

	res.status = HttpStatus.OK;
	res.body = json::marshal(allocator, (JSONResponse) { false, "string_val" }, indent: Indent.SPACE_2);

	DateTime expiration = datetime::now().add_hours(1);
	res.set_cookie(
		allocator,
		"test",
		"value",
		{
			.options = CookieOption.EXPIRES | CookieOption.SECURE | CookieOption.MAX_AGE | CookieOption.PATH,
			.expires = expiration,
			.max_age = cookies::HOUR,
			.path = "/",
			.secure = true,
		}
	);

	io::printfn("%s", res);
}

fn void Controller.static_controller(&self, Allocator allocator, Context* ctx, HttpRequest* req, HttpResponse* res)
{
	res.status = HttpStatus.OK;
	res.body = json::marshal(allocator, (JSONResponse) { false, "string_val" }, indent: Indent.SPACE_2);

	io::printfn("%s", res);
}

fn RequestFlow router_log_middleware(
	void* self = null,
	Allocator allocator,
	Context* ctx,
	HttpRequest* req,
	HttpResponse* res
)
{
	log::Logger* log = ctx.resolve(log::Logger)!!;
	log.debugf(
		"[MIDDLEWARE] router %s %s",
		"middleware router",
		log::_enum("method", &req.method),
		log::_string("uri", &req.uri)
	);
	return RequestFlow.CONTINUE;
}

fn RequestFlow group_log_middleware(
	void* self = null,
	Allocator allocator,
	Context* ctx,
	HttpRequest* req,
	HttpResponse* res
)
{
	log::Logger* log = ctx.resolve(log::Logger)!!;
	log.debugf(
		"[MIDDLEWARE] group %s %s",
		"middleware group",
		log::_enum("method", &req.method),
		log::_string("uri", &req.uri)
	);
	return RequestFlow.CONTINUE;
}

fn RequestFlow endpoint_log_middleware(
	void* self = null,
	Allocator allocator,
	Context* ctx,
	HttpRequest* req,
	HttpResponse* res
)
{
	log::Logger* log = ctx.resolve(log::Logger)!!;
	log.debugf(
		"[MIDDLEWARE] endpoint %s %s",
		"middleware endpoint",
		log::_enum("method", &req.method),
		log::_string("uri", &req.uri)
	);
	return RequestFlow.CONTINUE;
}

struct Test
{
	union
	{
		HttpRequest req;
		HttpRequest res;
	}
}

fn int main(String[] args)
{
	config::Config config;
	config.from_file(mem);
	defer config.free(mem);
	/* log::C3ApiLogger logger;
	logger.init(mem);

	log::ConsoleSink console_sink;
	console_sink.init();
	defer console_sink.free();
	logger.add_sink(&console_sink, log::min_level_enabler(log::LogLevel.TRACE));
	
	log::FileSink file_sink;
	if(catch error = file_sink.init(path::tnew("c3api.log")!!)){
		io::eprintn("FileSink for logger could not be created");
		return 1;
	}
	defer file_sink.free();
	logger.add_sink(&file_sink, log::min_level_enabler(log::LogLevel.TRACE)); */

	c3api::Server server;
	server.init(tmem, &config);
	server.get_context().register(Logger, server.get_logger());

	Router* router = server.get_router();
	router.use("/", &router_log_middleware);

	Controller controller = { .test = 2 };

	@pool()
	{
		Group* example = router.group(tmem, "/v1/example");
		example.use("/", &group_log_middleware);
		example.use("/{name}", &endpoint_log_middleware);

		example.get("/{name}", &no_controller);
		group::get{void}(example, "/static/yay", &static_no_controller);
		// TODO find nicer way then casting to (HandleFunc)
		/* example.route(
			RouteMethod.GET,
			"/staticc/ctrl",
			&Controller.static_controller,
			&endpoint_log_middleware
		); */

		group::get{Controller}(example, "/staticc/ctrl", &Controller.static_controller, &controller);


		io::print("\nGroup routes\n");
		routing::print_routes(example);
	};

	Path cwd = path::tcwd()!!;
	Path dir = cwd.tappend("example/public")!!;

	router.serve_static("/files", dir)!!;

	io::print("\nRouter routes\n");
	routing::print_routes(router);
	io::print("\n");

	server.run()!!;

	return 0;
}





