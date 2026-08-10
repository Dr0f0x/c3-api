module main;

import c3api;
import c3api::routing;
import c3api::routing::router;

<*
 Simple route handler.
 Handles requests to: GET /test/{name}

 The value of `{name}` is extracted from the route parameters and
 returned to the client as part of the response body.
*>
fn void handler(void* self = null, Allocator allocator, Context* ctx, HttpRequest* req, HttpResponse* res)
{
	// Set HTTP status code
	res.status = HttpStatus.OK;

	@pool()
	{
		// Build the response message
		DString greeting = dstring::temp();

		// Access the path parameter under "name"
		greeting.appendfn("hello %s, c3-api is running!", req.params["name"]!!);

		// Write the response body
		res.body = greeting.copy_str(allocator);
	};
}

<*
 Route handler with multiple path parameters.
Handles requests to: GET /test/{name}/{id}

The values of `{name}` and `{id}` are extracted from the route
parameters and returned to the client.
*>
fn void multi_param_handler(void* self = null, Allocator allocator, Context* ctx, HttpRequest* req, HttpResponse* res)
{
	// Set HTTP status code
	res.status = HttpStatus.OK;

	@pool()
	{
		// Build the response message
		DString response = dstring::temp();

		// Access both path parameters
		response.appendfn("hello %s, your id is %s", req.params["name"]!!, req.params["id"]!!);

		// Write the response body
		res.body = response.copy_str(allocator);
	};
}

fn int main(String[] args)
{
	// Create and initialize the server
	c3api::Server server;
	server.init(tmem);

	// Get the router instance from the server
	router::Router* router = server.get_router();

	// Register the route with a single path parameter
	router.get("/test/{name}", &handler);

	// Register the route with two path parameters
	router.get("/test/{name}/{id}", &multi_param_handler);

	// Print all registered routes
	routing::print_routes(router);

	// Start the HTTP server
	server.run()!!;

	return 0;
}
