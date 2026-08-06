module main;

import c3api;
import c3api::routing;
import c3api::routing::router;


fn void handler(void* self = null, Allocator allocator, Context* ctx, HttpRequest* req, HttpResponse* res)
{
    // Set HTTP status code
	res.status = HttpStatus.OK;
	res.body = string::format("c3-api is running");
}

fn int main(String[] args)
{
    // Create and initialize the server
	c3api::Server server;
	server.init(tmem);

    // Get the router instance from the server.
	router::Router* router = server.get_router();

	// register route
	router.get("/test", &handler);

    // macro to print all registered routes to the console.
	routing::print_routes(router);

    // Start the HTTP server.
	server.run()!!;

	return 0;
}