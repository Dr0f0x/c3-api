module main;

import std::io;

import c3api;
import c3api::routing;
import c3api::routing::router;
import c3api::routing::group;

<*
 Simple route handler.

 Handles requests registered inside a route group and returns
 the request URI.
*>
fn void handler(void* self = null, Allocator allocator, Context* ctx, HttpRequest* req, HttpResponse* res)
{
	// Set HTTP status code
	res.status = HttpStatus.OK;

	// Return the requested URI
	res.body = string::format(allocator, "c3-api is running: %s", req.uri);
}

<*
 API version middleware.

 Adds a response header to routes registered under the
 `/api/v1` subgroup.
*>
fn middleware::RequestFlow api_middleware(
	void* self = null,
	Allocator allocator,
	Context* ctx,
	HttpRequest* req,
	HttpResponse* res
)
{
	// Mark the request as having passed through the v1 middleware.
	io::printn("Adding header for api v1 group in middleware");
	res.headers.set_header_value("X-V1-Middleware", "active");

	// Continue processing the request.
	return RequestFlow.CONTINUE;
}

<*
 User group middleware.

 Adds a response header to routes registered under the
`/api/v1/users` subgroup.
*>
fn middleware::RequestFlow user_middleware(
	void* self = null,
	Allocator allocator,
	Context* ctx,
	HttpRequest* req,
	HttpResponse* res
)
{
	// Mark the request as having passed through the user middleware
	io::printn("Adding header for user group in middleware");
	res.headers.set_header_value("X-User-Middleware", "active");

	// Continue processing the request
	return RequestFlow.CONTINUE;
}

fn int main(String[] args)
{
	// Create and initialize the server
	c3api::Server server;
	server.init(tmem)!!;

	// Get the router instance from the server
	router::Router* router = server.get_router();

	@pool()
	{
		// Create a group for the /api prefix
		group::Group* api = router.group(tmem, "/api/v1");

		// Register middleware for all routes under /api
		api.use("/", &api_middleware);

		// Register a route relative to the /api group
		// The resulting route is: /api/test
		api.get("/test", &handler);

		@pool()
		{
			// Create another nested group relative to /api/v1
			group::Group* users = api.group(tmem, "/users");

			// Register middleware for the /api/v1/users subgroup.
			users.use("/", &user_middleware);


			// Register a route relative to the /api/v1/users group
			// The resulting route is: /api/v1/users/test
			users.get("/test", &handler);
		};
	};

	// macro to print all registered routes to the console.
	routing::print_routes(router);

	// Start the HTTP server.
	server.run()!!;

	return 0;
}