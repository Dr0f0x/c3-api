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
	Path dir = cwd.tappend("examples/static/public")!!;

	// serve static files from the public directory
	router.serve_static("/", dir)!!;

	// macro to print all registered routes to the console.
	routing::print_routes(router);

	// Start the HTTP server.
	server.run()!!;

	return 0;
}