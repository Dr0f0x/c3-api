module main;

import std::io::path;

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

	// Return a static success message
	res.body = string::format(tmem, "c3-api is running");
}

fn int main(String[] args)
{
	// Load configuration from the default configuration file
	config::Config config;
	config.from_file(tmem, config::DEFAULT_CONF_PATH, true);
	defer config.free(tmem);

	// Initialize the application logger
	log::C3ApiLogger logger;
	logger.init(tmem);
	defer logger.free();

	// Create and register the console logging sink.
	log::ConsoleSink console_sink;
	if (catch error = console_sink.init())
	{
		io::eprintfn("FileSink for logger could not be created: %s", error);
		return 1;
	}
	defer console_sink.free();
	logger.add_sink(&console_sink, log::min_level_enabler(config.logging.console.min_level));

	// Create and register the rotating file logging sink.
	// 
	// Logs are written to timestamped files based on the supplied
	// base path. A maximum of three files are retained and each
	// file can grow to a maximum of 500 bytes before rotation.
	RotatingFileSink file_sink;
	if (catch error = file_sink.init(tmem, path::tnew("log/c3api.log")!!, 3, 500))
	{
		io::eprintfn("RotatingFileSink for logger could not be created: %s", error);
		return 1;
	}
	defer file_sink.free();
	logger.add_sink(&file_sink, log::min_level_enabler(config.logging.file.min_level));

	// Create and initialize the server
	c3api::Server server;
	server.init(tmem, &config, &logger)!!;

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