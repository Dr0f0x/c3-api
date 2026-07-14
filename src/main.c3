module app;

import c3api;
import c3api::config;
import c3api::routing;
import c3api::server;
import std::collections::map;

fn HttpResponse no_controller(c3api::Cref self = null, HttpRequest req, HashMap{String, String} args)
{
	HttpResponse res;
	res.init(tmem);
	@pool()
	{
		// Using pool because of dstring::temp_new();
		res.status = HttpStatus.OK;
		DString greetings = dstring::temp();
		greetings.appendf("Look, %s, no controllers!\n", args["name"]!!);
		res.body = string::format(mem, greetings.tcopy_str(), req.method, req.uri);
		return res;
	};
}

fn HttpResponse static_no_controller(c3api::Cref self = null, HttpRequest req, HashMap{String, String} args)
{
	HttpResponse res;
	res.init(tmem);
	@pool()
	{
		// Using pool because of dstring::temp_new();
		res.status = HttpStatus.OK;
		DString greetings = dstring::temp();
		greetings.appendf("Look, static!\n");
		res.body = string::format(mem, greetings.tcopy_str(), req.method, req.uri);
		return res;
	};
}
fn int main(String[] args)
{
	config::Config config;
	config.from_file(mem,true);
	defer config.free(mem);

	routing::init_route_map(mem);
	defer routing::destroy_route_map();

	routing::add_route("/example/{name}", &no_controller);

	routing::add_route("/exampler/static", &static_no_controller);

	server::startServer(config)!!;

	return 0;
}
