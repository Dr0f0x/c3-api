// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module main;

import std::collections::map;
import std::io::path;
import std::encoding::json;
import std::time::datetime;

import c3api;
import c3api::routing::router;
import c3api::routing::group;
import c3api::encoding;

fn void no_controller(void* self = null, Allocator allocator, Context* ctx, HttpRequest* req, HttpResponse* res)
{
	io::printfn("cookie %s", req.get_cookie("test") ?? "-");
	@pool()
	{
		res.status = HttpStatus.OK;
		DString greetings = dstring::temp();
		greetings.appendfn("Look, %s, no controllers!", req.params["name"]!!);
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
	res.body = json::marshal(allocator, (JSONResponse) { false, "string_val" });

	DateTime expiration = datetime::now().add_hours(1);
	res.set_cookie(
		allocator,
		"test",
		"value",
		{
			.use = CookieOption.EXPIRES | CookieOption.SECURE | CookieOption.MAX_AGE | CookieOption.PATH,
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
	res.body = json::marshal(allocator, (JSONResponse) { false, "string_val" });

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

struct TodoRequest (Printable)
{
	String title @Json("title", true) @Xml("title", true) @Form("title", true);
	String description @Json("description", true) @Xml("description", true) @Form("description", true);
	bool completed @Json("completed", true) @Xml("completed", true) @Form("completed", true);
}

fn sz? TodoRequest.to_format(&self, Formatter* formatter) @dynamic
{
	sz len = formatter.print("TodoRequest { ")!;

	len += formatter.print("title: ")!;
	len += formatter.print(self.title)!;

	len += formatter.print(", description: ")!;
	len += formatter.print(self.description)!;

	len += formatter.print(", completed: ")!;
	len += formatter.printf("%b", self.completed)!;

	return len += formatter.print(" }")!;
}

fn void todo_handler(void* self = null, Allocator allocator, Context* ctx, HttpRequest* req, HttpResponse* res)
{
	io::printfn("req %s", req);
	io::printfn("req body %s", (String)req.body);

	TodoRequest*? todo = request::from_form{TodoRequest}(req, allocator);
	if (catch err = todo)
	{
		res.status = HttpStatus.BAD_REQUEST;
		res.body = string::format(allocator, `{"type":"error","message":"%s"}`, err);
		return;
	}
	io::printfn("%s", todo);
	res.status = HttpStatus.CREATED;
	response::as_form{TodoRequest}(res, allocator, todo);
}

struct Address
{
	String city;
	String[] lines;
}
struct Product
{
	String name;
	float price;
	String[] tags;
	Address supplier_address;
}
struct Order
{
	String id;
	Product product;
	String[] notes;
}

fn int main(String[] args)
{
	config::Config config;
	config.from_default(mem);
	config.from_file(mem, config::DEFAULT_CONF_PATH, true);
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

	Product product = {
		.name = "Mechanical Keyboard",
		.price = 89.99,
		.tags = { "keyboard", "mechanical" },
		.supplier_address = { .city = "Cologne", .lines = { "Industriestrasse 10", "Building B" } }
	};
	Order order = { .id = "ORD-1001", .product = product, .notes = { "Handle with care", "Leave at reception" } };

	io::printfn("%s", form::marshal_form(tmem, order));

	c3api::Server server;
	server.init(tmem)!!;
	defer server.free();
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
		router.get("/staticc/ctrl", (HandleFunc)&Controller.static_controller, &controller);

		io::print("\nGroup routes\n");
		routing::print_routes(example);
	};

	Path cwd = path::tcwd()!!;
	Path dir = cwd.tappend("examples/todo/public")!!;

	router.serve_static("/files", dir)!!;

	router.post("/todo", &todo_handler);

	io::print("\nRouter routes\n");
	routing::print_routes(router);
	io::print("\n");

	server.run()!!;

	return 0;
}