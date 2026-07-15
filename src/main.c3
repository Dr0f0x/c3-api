module app;

import std::collections::map;
import std::io::path;

import c3api;
import c3api::config;
import c3api::routing;
import c3api::server;

fn void no_controller(HttpRequest* req, HttpResponse* res)
{
	io::printfn("%s", req);

	@pool()
	{
		// Using pool because of dstring::temp_new();
		res.status = HttpStatus.OK;
		DString greetings = dstring::temp();
		greetings.appendf("Look, %s, no controllers!\n", req.args["name"]!!);
		res.body = string::format(mem, greetings.tcopy_str(), req.method, req.uri);
	};

	io::printfn("%s", res);
}

fn void static_no_controller(HttpRequest* req, HttpResponse* res)
{
	io::printfn("%s", req);

	@pool()
	{
		// Using pool because of dstring::temp_new();
		res.status = HttpStatus.OK;
		DString greetings = dstring::temp();
		greetings.appendf("Look, static!\n");
		res.body = string::format(mem, greetings.tcopy_str(), req.method, req.uri);
	};

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

	routing::init_route_map(mem);
	defer routing::destroy_route_map();

	routing::add_route("/example/{name}", &no_controller);

	routing::add_route("/exampler/static", &static_no_controller);

	server::startServer(config)!!;

	return 0;
}
