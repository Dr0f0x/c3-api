module main;

import c3api;
import c3api::routing;
import c3api::routing::router;

<*
 Simple query parameter handler.
 Handles requests to: GET /test?name={name}

 Reads the `name` query parameter and returns it in the response.
*>
fn void handler(void* self = null, Allocator allocator, Context* ctx, HttpRequest* req, HttpResponse* res)
{
	// Set HTTP status code
	res.status = HttpStatus.OK;

	// Access the query parameter under "name"
	String? name = req.query["name"];

	if (try name)
	{
		// Return the provided query parameter in the response body
		res.body = string::format(allocator, "Hello %s!", name);
	}
	else
	{
		// Return a message when the query parameter is not provided
		res.body = "No name provided";
	}
}

<*
 Query parameter handler with multiple parameters.
 Handles requests to: GET /search?query={query}&page={page}

 Reads both `query` and `page` from the query string.
*>
fn void search_handler(void* self = null, Allocator allocator, Context* ctx, HttpRequest* req, HttpResponse* res)
{
	// Set HTTP status code
	res.status = HttpStatus.OK;

	// Access both query parameters
	String? query = req.query["query"];
	String? page  = req.query["page"];

	if (try query && try page)
	{
		// Return both query parameters in the response body
		res.body = string::format(allocator, "Searching for '%s' on page %s", query, page);
	}
	else
	{
		// Return a message when either parameter is missing
		res.body = "Missing query or page parameter";
	}
}

fn int main(String[] args)
{
	// Create and initialize the server
	c3api::Server server;
	server.init(tmem)!!;

	// Get the router instance from the server.
	router::Router* router = server.get_router();

	// register routes
	router.get("/test", &handler);
	router.get("/search", &search_handler);

	// macro to print all registered routes to the console.
	routing::print_routes(router);

	// Start the HTTP server.
	server.run()!!;

	return 0;
}