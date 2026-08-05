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
        // Build response message
		DString greetings = dstring::temp();
		greetings.appendfn("hello %s, c3-api is running!", req.args["name"]!!);

        // Write response body
        res.body = string::format(allocator, greetings.tcopy_str(), req.method, req.uri);
	};
}

fn int main(String[] args)
{
    // Create and initialize the server
	c3api::Server server;
	server.init(tmem);

    // Get the router instance from the server.
	router::Router* router = server.get_router();

    // Register the route with a path parameter.
	router.get("/test/{name}", &handler);

    // macro to print all registered routes to the console.
	routing::print_routes(router);

    // Start the HTTP server.
	server.run()!!;

	return 0;
}