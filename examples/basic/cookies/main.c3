module main;

import std::time::datetime;

import c3api;
import c3api::routing;
import c3api::routing::router;
import c3api::http::cookies;

<*
 Cookie-based route handler.

 Handles requests to: GET /test

 Reads the `lastVisit` cookie and, if present, converts its Unix
 timestamp into a DateTime and returns the previous visit time.

 If no valid cookie is present, reports that this is the first visit.
 The handler then updates the cookie with the current Unix timestamp.
*>
fn void handler(void* self = null, Allocator allocator, Context* ctx, HttpRequest* req, HttpResponse* res)
{
	// Retrieve cookie from request
	String? last_visit = req.get_cookie("lastVisit");

	// Set HTTP status code
	res.status = HttpStatus.OK;

	// Check if cookie was actually present
	if (try last_visit)
	{
		// Parse string value into actual DateTime
		if (try last_visit_time = from_unix_seconds(last_visit))
		{
			res.body = string::format(
				tmem,
				"Your last visit was %s",
				last_visit_time.format(tmem, DateTimeFormat.UNIXDATE)
			);
		} // Cookie value didnt contain string in RFC format
		else
		{
			res.status = HttpStatus.OK;
			res.body = "lastVisit Cookie had incorrect format";
		}
	} // Cookie was not present
	else
	{
		res.status = HttpStatus.OK;
		res.body = "This is your first visit";
	}

	// Update Cookie value
	DateTime expiration = datetime::now().add_months(1);
	res.set_cookie(
		tmem,
		"lastVisit",
		string::format(tmem, "%s", time::now() / (Time)time::SEC),
		{
			.use = CookieOption.EXPIRES | CookieOption.SECURE | CookieOption.MAX_AGE | CookieOption.PATH,
			.expires = expiration,
			.max_age = cookies::HOUR,
			.path = "/",
			.secure = true,
		}
	);
}

fn int main(String[] args)
{
	// Create and initialize the server
	c3api::Server server;
	server.init(tmem)!!;

	// Get the router instance from the server
	router::Router* router = server.get_router();

	// register route
	router.get("/test", &handler);

	// macro to print all registered routes to the console
	routing::print_routes(router);

	// Start the HTTP server
	server.run()!!;

	return 0;
}