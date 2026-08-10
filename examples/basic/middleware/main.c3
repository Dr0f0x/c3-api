module main;

import std::io;

import c3api;
import c3api::routing;
import c3api::routing::router;
import c3api::routing::middleware;

<*
 Simple middleware function.
 Adds a custom `X-Middleware` response header to each request
 and allows request processing to continue.
*>
fn RequestFlow middleware(void* self = null, Allocator allocator, Context* ctx, HttpRequest* req, HttpResponse* res)
{
	// Add a custom response header
	io::printn("Sending custom middleware header");
	res.headers.set_header_value("X-Middleware", "active");

	// Continue processing the request
	return RequestFlow.CONTINUE;
}

<*
 Stateful middleware owner.

 Stores a counter value that is incremented by
 `Counter.counter_middleware` for each request.
*>
struct Counter
{
	int counter;
}

<*
 Type method middleware.

 Increments the counter for each request and stores the
 current counter value in the request context.
*>
fn middleware::RequestFlow Counter.counter_middleware(
	&self,
	Allocator allocator,
	Context* ctx,
	HttpRequest* req,
	HttpResponse* res
)
{
	// Increment the counter for the current request
	self.counter++;

	// Store the current counter value in the request context
	int* val = alloc::new(tmem, int, self.counter);
	ctx.set("count", val);

	// Continue processing the request
	return RequestFlow.CONTINUE;
}

<*
 Simple route handler.

 Handles requests to: GET /test and GET /generic.
 Returns the current request counter value stored by the middleware.
*>
fn void handler(void* self = null, Allocator allocator, Context* ctx, HttpRequest* req, HttpResponse* res)
{
	// Set HTTP status code
	res.status = HttpStatus.OK;

	// Retrieve the counter value from the request context
	int default_val = 0;
	int* count      = ctx.get("count") ?? &default_val;

	// Return the current counter value in the response body
	res.body = string::format(tmem, "c3-api is running, count: %d", *count);
}

fn int main(String[] args)
{
	// Create and initialize the server
	c3api::Server server;
	server.init(tmem);

	// Create an instance of the Counter struct to maintain state across requests
	Counter counter_instance;

	// Get the router instance from the server
	router::Router* router = server.get_router();

	router.get("/test", &handler);
	
	// Register the stateless middleware for /test
	router.use("/test", &middleware);
	// Register the stateful middleware for /test (requires cast!)
	router.use("/test", (MiddlewareFunc)&Counter.counter_middleware, &counter_instance);

	router::get{void}(router, "/generic", &handler);

	// Register the stateless middleware using the generic macro
	router::use{void}(router, "/generic", &middleware);
	// Register the stateful middleware using the generic macro
	router::use{Counter}(router, "/generic", &Counter.counter_middleware, &counter_instance);

	// macro to print all registered routes to the console
	routing::print_routes(router);

	// Start the HTTP server
	server.run()!!;

	return 0;
}
