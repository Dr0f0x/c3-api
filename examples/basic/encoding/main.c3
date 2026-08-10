module main;

import c3api;
import c3api::routing;
import c3api::routing::router;
import c3api::encoding;

<*
 Supplier information for a product.
*>
struct Supplier
{
	String name @Json("name", true) @Xml("name", true) @Form("name", true);
	String email @Json("email", true) @Xml("email", true) @Form("email", true);
}

<*
 Product model used for request binding and response serialization.

 The same structure can be decoded from JSON, XML, or form data
 and serialized back to each format.
*>
struct Product
{
	String name @Json("name", true) @Xml("name", true) @Form("name", true);
	String category @Json("category", true) @Xml("category", true) @Form("category", true);
	float price @Json("price", true) @Xml("price", true) @Form("price", true);
	uint quantity @Json("quantity", true) @Xml("quantity", true) @Form("quantity", true);

	Supplier supplier @Json("supplier", true) @Xml("supplier", true) @Form("supplier", true);
}

<*
 Response containing a message and the submitted product.

 The response can be serialized as JSON, XML, or form data.
*>
struct ProductResponse
{
	String message @Json("message", true) @Xml("message", true) @Form("message", true);
	Product product @Json("product", true) @Xml("product", true) @Form("product", true);
}

<*
 Error response returned when request binding fails.
*>
struct ErrorResponse
{
	String error @Json("error", true) @Xml("error", true) @Form("error", true);
}

<*
 JSON request handler.

 Handles requests to: POST /json

 Decodes the request body into a Product from JSON and returns
 the created product as a JSON response.
*>
fn void json_handler(void* self = null, Allocator allocator, Context* ctx, HttpRequest* req, HttpResponse* res)
{
	// Decode the JSON request body into a Product
	Product*? product = request::from_json{Product}(req, allocator);
	if (catch err = product)
	{
		// Return a bad request response when JSON binding fails
		res.status = HttpStatus.BAD_REQUEST;
		ErrorResponse error_response = { .error = string::tformat("%s", err) };
		response::as_json{ErrorResponse}(res, allocator, &error_response);
		return;
	}

	// Build the response containing the submitted product
	ProductResponse response = { .message = "Product entered", .product = *product };

	// Return the product as JSON
	res.status = HttpStatus.CREATED;
	response::as_json{ProductResponse}(res, allocator, &response);
}

<*
 XML request handler.

 Handles requests to: POST /xml

 Decodes the request body into a Product from XML and returns the
 created product as an XML response.
*>
fn void xml_handler(void* self = null, Allocator allocator, Context* ctx, HttpRequest* req, HttpResponse* res)
{
	// Decode the XML request body into a Product
	Product*? product = request::from_xml{Product}(req, allocator);
	if (catch err = product)
	{
		// Return a bad request response when XML binding fails
		res.status = HttpStatus.BAD_REQUEST;
		ErrorResponse error_response = { .error = string::tformat("%s", err) };
		response::as_xml{ErrorResponse}(res, allocator, &error_response);
		return;
	}

	// Build the response containing the submitted product
	ProductResponse response = { .message = "Product entered", .product = *product };

	// Return the product as XML
	res.status = HttpStatus.CREATED;
	response::as_xml{ProductResponse}(res, allocator, &response);
}

<*
 Form request handler.

 Handles requests to: POST /form

 Decodes application/x-www-form-urlencoded request data
 into a Product and returns the product as form data.
*>
fn void form_handler(void* self = null, Allocator allocator, Context* ctx, HttpRequest* req, HttpResponse* res)
{
	// Decode the form request body into a Product
	Product*? product = request::from_form{Product}(req, allocator);
	if (catch err = product)
	{
		// Return a bad request response when form binding fails
		res.status = HttpStatus.BAD_REQUEST;
		ErrorResponse error_response = { .error = string::tformat("%s", err) };
		response::as_form{ErrorResponse}(res, allocator, &error_response);
		return;
	}

	// Build the response containing the submitted product
	ProductResponse response = { .message = "Product entered", .product = *product };

	// Return the product as form data
	res.status = HttpStatus.CREATED;
	response::as_form{ProductResponse}(res, allocator, &response);
}

fn int main(String[] args)
{
	// Create and initialize the server
	c3api::Server server;
	server.init(tmem);

	// Get the router instance from the server
	router::Router* router = server.get_router();

	// Register the JSON endpoint
	router.post("/json", &json_handler);

	// Register the XML endpoint
	router.post("/xml", &xml_handler);

	// Register the form endpoint
	router.post("/form", &form_handler);

	// macro to print all registered routes to the console
	routing::print_routes(router);

	// Start the HTTP server
	server.run()!!;

	return 0;
}
