module c3api::http;

import std::collections;
import std::io;

struct HttpQueryParams (Printable)
{
	HashMap{String, String} param_map;

	Allocator allocator;
}

<*
 Initialize the params collection with an allocator.

 @param [&inout] allocator : "Allocator to use for internal allocations"
 @return "The initialized params collection"
*>
fn HttpQueryParams* HttpQueryParams.init(&self, Allocator allocator)
{
	self.param_map.init(allocator);
	self.allocator = allocator;
	return self;
}

<*
 Check if the parameters collection has been initialized.

 @return "true if initialized, false otherwise"
*>
fn bool HttpQueryParams.is_initialized(&self)
{
	return self.param_map.is_initialized();
}

<*
 Set a parameter value in the parameters map.

 If the parameter key already exists, the value is replaced with the new value.

 @param [in] param_name : "Parameter name"
 @param [in] param_value : "Parameter value"
 @return "True if the parameter key already existed, false if a new parameter key was added"
*>
fn bool HttpQueryParams.set_param_value(&self, String param_name, String param_value) @operator([]=)
{
	return self.param_map.set(param_name, param_value);
}

<*
 Get the value for a given parameter key.

 @param [in] param_name : "Parameter name"
 @return "The parameter value, or NOT_FOUND~ if the key does not exist"
*>
fn String? HttpQueryParams.get_param_value(&self, String param_name) @operator([])
{
	return *self.param_map.get_ref(param_name) @inline;
}

<*
 Get the number of parameters stored in the parameter map.

 @return "The count of unique parameter keys"
*>
fn sz HttpQueryParams.len(&self)
{
	return self.param_map.len();
}


<*
 Parse route parameters from the last URI segment.

 The segment must contain key-value pairs in the form `name=value`
 separated by `&`. Each parsed parameter is added to the parameter map.

 Example:

 `id=123&name=john&active=true`

 becomes:

 - id -> 123
 - name -> john
 - active -> true

 @param [&inout] self : "The parameters collection to populate"
 @param [in] segment : "Last URI segment containing parameter assignments"
*>
fn void? HttpQueryParams.set_from_last_uri_segment(&self, String segment)
{
	@pool()
	{
		foreach (String pair : segment.split(self.allocator, "&"))
		{
			pair = pair.trim();
			if (pair == "") continue;

			sz equals = pair.index_of_char('=')!;

			String param_name  = pair[0..equals-1].trim();
			String param_value = pair[equals + 1..].trim();

			self.set_param_value(param_name, param_value);
		}
	};
}

macro HttpQueryParams.@each(params; @body(key, value))
{
	params.param_map.@each_entry(; map::Entry{String, String}* entry)
	{
		@body(entry.key, entry.value);
	};
}

macro HttpQueryParams.@each_entry(params; @body(entry))
{
	if (!params.param_map.count) return;
	foreach (&entry : params.param_map.table)
	{
		while (entry)
		{
			@body(entry);
			entry = entry.next;
		}
	}
}

<*
 Free the params collection and its internal resources.
*>
fn void HttpQueryParams.free(&self)
{
	self.param_map.free();
}


<*
 Format the params collection using the underlying params map formatter.

 @param [inout] formatter : "Formatter to write output to"
 @return "The number of characters written, or an error"
*>
fn sz? HttpQueryParams.to_format(&self, Formatter* formatter) @dynamic
{
	return self.param_map.to_format(formatter);
}
