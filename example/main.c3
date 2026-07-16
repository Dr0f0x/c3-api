module app;

import std::collections::map;
import std::io::path;
import std::encoding::json;

import c3api;
import c3api::config;
import c3api::routing;

fn void no_controller(Allocator allocator, Context* ctx, HttpRequest* req, HttpResponse* res)
{
	@pool()
	{
		// Using pool because of dstring::temp_new();
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

fn RequestFlow router_log_middleware(Allocator allocator, Context* ctx, HttpRequest* req, HttpResponse* res)
{
	io::printfn("[MIDDLEWARE] router %s %s", req.method, req.uri);
	return RequestFlow.CONTINUE;
}

fn RequestFlow group_log_middleware(Allocator allocator, Context* ctx, HttpRequest* req, HttpResponse* res)
{
	io::printfn("[MIDDLEWARE] group %s %s", req.method, req.uri);
	return RequestFlow.CONTINUE;
}

fn RequestFlow endpoint_log_middleware(Allocator allocator, Context* ctx, HttpRequest* req, HttpResponse* res)
{
	io::printfn("[MIDDLEWARE] endpoint %s %s", req.method, req.uri);
	return RequestFlow.CONTINUE;
}

fn void static_no_controller(Allocator allocator, Context* ctx, HttpRequest* req, HttpResponse* res)
{
	io::printfn("%s", req);

	res.status = HttpStatus.OK;
	res.body = json::marshal(allocator, (JSONResponse) { false, "string_val" }, indent: Indent.SPACE_2);

	io::printfn("%s", res);
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

	routing::Router* router = server.get_router();
	router.use_middleware(&router_log_middleware);

	@pool()
	{
		Group* example = router.group(tmem, "/v1/example");
		example.use_middleware(&group_log_middleware);
		example.add_middleware("/{name}", &endpoint_log_middleware);

		example.add_route(RouteMethod.GET, "/{name}", &no_controller, &endpoint_log_middleware);
		example.add_route(RouteMethod.GET, "/static/test", &static_no_controller, &endpoint_log_middleware);

		io::printfn("%s", *example);
	};

	io::printfn("%s", router);

	server.run()!!;

	return 0;
}
