module main;

import std::io::path;

import c3api;
import c3api::routing;
import c3api::routing::router;

fn int main(String[] args)
{
	// Create and initialize the server
	c3api::Server server;
	server.init(tmem)!!;

	// Get the router instance from the server.
	router::Router* router = server.get_router();

	// construct path to this examples`s public directory
	Path cwd = path::tcwd()!!;
	Path dir = cwd.tappend("examples/basic/static/public")!!;

	// create storage configured with the public directory and options
	routing::StaticFiles static_files;
	static_files.init(tmem, dir);
	defer static_files.free();

	// serve static files from the configured directory
	router.serve_static("/", &static_files)!!;

	// macro to print all registered routes to the console.
	routing::print_routes(router);

	// Start the HTTP server.
	server.run()!!;

	return 0;
}