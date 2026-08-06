module main;

import c3api;
import c3api::routing;
import c3api::routing::router;


<*
 Simple route handler.
 Handles requests to: GET /test

 Returns a static success message to confirm the server is running.
*>
fn void handler(void* self = null, Allocator allocator, Context* ctx, HttpRequest* req, HttpResponse* res)
{
	// Set HTTP status code
	res.status = HttpStatus.OK;
	res.body = string::format(allocator, "c3-api is running");
}

<*
 Stateful handler owner.

 Stores a counter value that is returned and incremented
 by `Counter.counter_handler` on each request.
*>
struct Counter
{
	int counter;
}

<*
 Type method route handler.
 Handles requests to: GET /counter

 Returns the current counter value in the response body and
 increments it for the next request.
*>
fn void Counter.counter_handler(&self, Allocator allocator, Context* ctx, HttpRequest* req, HttpResponse* res)
{
	// Set HTTP status code
	res.status = HttpStatus.OK;

	// Return the current counter value in the response body
	res.body = string::format(allocator, "Counter: %d", self.counter);

	// Increment the counter for the next request
	self.counter++;
}

fn int main(String[] args)
{
	// Create and initialize the server
	c3api::Server server;
	server.init(tmem);

	// Create an instance of the Counter struct to maintain state across requests
	Counter counter_instance;

	// Get the router instance from the server.
	router::Router* router = server.get_router();

	// Register simple route with the stateless handler
	router.get("/test", &handler);
	// Register the counter route with the stateful handler (requires cast!)
	router.get("/counter", (HandleFunc)&Counter.counter_handler, &counter_instance);

	// Register simple route with the stateless handler using the generic macro
	router::get{void}(router, "/generic", &handler);
	// Register the counter route with the stateful handler using the generic macro (no cast required and typesafe)
	router::get{Counter}(router, "/generic-counter", &Counter.counter_handler, &counter_instance);

	// macro to print all registered routes to the console.
	routing::print_routes(router);

	// Start the HTTP server.
	server.run()!!;

	return 0;
}
