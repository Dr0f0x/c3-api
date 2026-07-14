module c3api::config;

import std::collections::object;

<*
 Cross-Origin Resource Sharing (CORS) configuration.

 Controls whether CORS is enabled and which request/response headers are allowed.
*>
struct CorsConfig
{
	bool enabled;
	String allow_methods;
	String allow_headers;
	String allow_origin;
}

const CorsConfig DEFAULT_CORS_CONFIG = {
	.enabled = false,
	.allow_methods = "GET, POST, OPTIONS",
	.allow_headers = "Content-Type",
	.allow_origin = "*"
};

<*
 Copy another CORS config into this instance.

 Performs deep copies for string fields using the provided allocator.

 @param [in] other : "Source CORS config"
 @param [&inout] allocator : "Allocator used for copied string fields"
*>
fn void CorsConfig.from_other(&self, CorsConfig* other, Allocator allocator)
{
	self.enabled = other.enabled;
	self.allow_methods = other.allow_methods.copy(allocator);
	self.allow_headers = other.allow_headers.copy(allocator);
	self.allow_origin = other.allow_origin.copy(allocator);
}

<*
 Parse CORS configuration from a JSON object.

 @param [&inout] allocator : "Allocator used for copied string fields"
 @param [in] cors_obj : "JSON object containing CORS settings"
*>
fn void CorsConfig.parse_from_object(&self, Allocator allocator, Object* cors_obj)
{
	@pool()
	{
		String parsed_allow_methods = cors_obj.get_string(
			"Access-Control-Allow-Methods"
		) ?? DEFAULT_CORS_CONFIG.allow_methods;
		String parsed_allow_headers = cors_obj.get_string(
			"Access-Control-Allow-Headers"
		) ?? DEFAULT_CORS_CONFIG.allow_headers;
		String parsed_allow_origin  = cors_obj.get_string(
			"Access-Control-Allow-Origin"
		) ?? DEFAULT_CORS_CONFIG.allow_origin;

		self.enabled = cors_obj.get_bool("enabled") ?? DEFAULT_CORS_CONFIG.enabled;
		self.allow_methods = parsed_allow_methods.copy(allocator);
		self.allow_headers = parsed_allow_headers.copy(allocator);
		self.allow_origin = parsed_allow_origin.copy(allocator);
	};
}

<*
 Free dynamically allocated CORS config string fields.

 @param [&inout] allocator : "Allocator used for previously allocated fields"
*>
fn void CorsConfig.free(&self, Allocator allocator)
{
	alloc::free(allocator, self.allow_methods);
	alloc::free(allocator, self.allow_headers);
	alloc::free(allocator, self.allow_origin);
}