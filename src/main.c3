module app;

import std::collections::map;
import std::io::path;
import std::encoding::json;

import c3api;
import c3api::config;
import c3api::routing;
import c3api::server;

fn void no_controller(Allocator allocator, HttpRequest* req, HttpResponse* res)
{
	io::printfn("%s", req);

	@pool()
	{
		// Using pool because of dstring::temp_new();
		res.status = HttpStatus.OK;
		DString greetings = dstring::temp();
		greetings.appendf("Look, %s, no controllers!\n", req.args["name"]!!);
		res.body = string::format(allocator, greetings.tcopy_str(), req.method, req.uri);
	};

	io::printfn("%s", res);
}

struct JSONResponse
{
	bool test;
	String value;
}

fn void static_no_controller(Allocator allocator, HttpRequest* req, HttpResponse* res)
{
	io::printfn("%s", req);

	res.status = HttpStatus.OK;
	res.body = json::marshal(allocator, (JSONResponse) { false, "string_val" }, indent: Indent.SPACE_2);

	io::printfn("%s", res);
}

fn int main(String[] args)
{
	config::Config config;
	config.from_file(mem, true);
	defer config.free(mem);

	/* sets up custom looger configuration
	log::C3ApiLogger logger;
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

	Router router;
	router.init(mem, null);
	defer router.free();

	@pool()
	{
		Group* example = router.group(tmem, "/v1/example");

		example.add_route(RouteMethod.GET, "/{name}", &no_controller);
		example.add_route(RouteMethod.GET, "/static/test", &static_no_controller);

		io::printfn("%s", *example);
	};

	io::printfn("%s", router);

	server::startServer(config, router)!!;

	return 0;
}
