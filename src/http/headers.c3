module c3api::http;

import std::collections;
import std::io;

<*
 HTTP headers map keyed by header name.
*>
struct HttpHeaders
{
	HashMap{String, List{String}} header_map;

	Allocator allocator;
}

<*
 Initialize the headers collection with an allocator.

 @param [&inout] allocator : "Allocator to use for internal allocations"
 @return "The initialized headers collection"
*>
fn HttpHeaders* HttpHeaders.init(&self, Allocator allocator)
{
	self.header_map.init(allocator);
	self.allocator = allocator;
	return self;
}

<*
 Check if the headers collection has been initialized.

 @return "True if initialized, false otherwise"
*>
fn bool HttpHeaders.is_initialized(&self)
{
	return self.header_map.is_initialized();
}

<*
 Set a header value in the headers map.

 If the header key already exists, the value list is replaced with the new values.

 @param [in] header_name : "Header field name"
 @param [in] header_values : "List of header field values"
 @return "True if the header key already existed, false if a new header key was added"
*>
fn bool HttpHeaders.set_header_values(&self, String header_name, String... header_values)
{
	if (try entry = self.header_map.get_entry(header_name))
	{
		entry.value.clear();
		entry.value.push_all(header_values);
		return true;
	}
	else
	{
		List{String} header;
		header.init(self.allocator);
		header.push_all(header_values);
		self.header_map.set(header_name, header);
		return false;
	}
}

<*
 Set a header value in the headers map.

 If the header key already exists, the value list is replaced with the new value.

 @param [in] header_name : "Header field name"
 @param [in] header_value : "Header field value"
 @return "True if the header key already existed, false if a new header key was added"
*>
fn bool HttpHeaders.set_header_value(&self, String header_name, String header_value)
{
	if (try entry = self.header_map.get_entry(header_name))
	{
		entry.value.clear();
		entry.value.push(header_value);
		return true;
	}
	else
	{
		List{String} header;
		header.init(self.allocator);
		header.push(header_value);
		self.header_map.set(header_name, header);
		return false;
	}
}

<*
 Get the list of values for a given header key.

 @param [in] header_name : "Header field name"
 @return "The list of values for the header key, or NOT_FOUND~ if the key does not exist"
*>
fn List{String}? HttpHeaders.get_header_values(&self, String header_name) @operator([])
{
	return *self.header_map.get_ref(header_name) @inline;
}

<*
 Get the number of unique header keys in the headers map.

 @return "The count of unique header keys"
*>
fn sz HttpHeaders.len(&self)
{
	return self.header_map.len();
}

<*
 Parse header lines into the headers map.

 Each line must be in the form `name: value`.

 @param [&inout] self : "The headers collection to populate"
 @param lines : "Header lines, consumed and freed by this function"
*>
fn void? HttpHeaders.set_from_lines(&self, List{String} lines)
{
	@pool()
	{
		foreach (line : lines)
		{
			line = line.trim();
			if (line == "") break;

			sz colon = line.index_of_char(':')!;

			String header_name  = line[0..colon].trim();
			String header_value = line[colon + 1..].trim();

			self.set_header_value(header_name, header_value);
		}
		lines.free();
	};
}

macro HttpHeaders.@each(headers; @body(key, value))
{
	headers.header_map.@each_entry(; map::Entry{String, List{String}}* entry)
	{
		@body(entry.key, entry.value);
	};
}

macro HttpHeaders.@each_entry(headers; @body(entry))
{
	if (!headers.header_map.count) return;
	foreach (&entry : headers.header_map.table)
	{
		while (entry)
		{
			@body(entry);
			entry = entry.next;
		}
	}
}

<*
 Free the headers collection and its internal resources.
*>
fn void HttpHeaders.free(&self)
{
	foreach (List{String} value : self.header_map.value_iter())
	{
		value.free();
	}
	self.header_map.free();
}