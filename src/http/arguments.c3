module c3api::http;

import std::collections;
import std::io;

struct HttpPathArguments (Printable)
{
	HashMap{String, String} argument_map;

	Allocator allocator;
}

<*
 Initialize the path arguments collection with an allocator.

 @param [&inout] allocator : "Allocator to use for internal allocations"
 @return "The initialized arguments collection"
*>
fn HttpPathArguments* HttpPathArguments.init(&self, Allocator allocator)
{
	self.argument_map.init(allocator);
	self.allocator = allocator;
	return self;
}

<*
 Check if the arguments collection has been initialized.

 @return "true if initialized, false otherwise"
*>
fn bool HttpPathArguments.is_initialized(&self)
{
	return self.argument_map.is_initialized();
}

<*
 Set a argument value in the arguments map.

 If the argument key already exists, the value is replaced with the new value.

 @param [in] argument_name : "Argument name"
 @param [in] argument_value : "Argument value"
 @return "True if the argument key already existed, false if a new argument key was added"
*>
fn bool HttpPathArguments.set_argument_value(&self, String argument_name, String argument_value)
{
	return self.argument_map.set(argument_name, argument_value);
}

<*
 Get the value for a given argument key.

 @param [in] argument_name : "Argument name"
 @return "The argument value, or NOT_FOUND~ if the key does not exist"
*>
fn String? HttpPathArguments.get_argument_value(&self, String argument_name) @operator([])
{
	return *self.argument_map.get_ref(argument_name) @inline;
}

<*
 Get the number of arguments stored in the argument map.

 @return "The count of unique argument keys"
*>
fn sz HttpPathArguments.len(&self)
{
	return self.argument_map.len();
}

macro HttpPathArguments.@each(arguments; @body(key, value))
{
	arguments.argument_map.@each_entry(; map::Entry{String, String}* entry)
	{
		@body(entry.key, entry.value);
	};
}

macro HttpPathArguments.@each_entry(arguments; @body(entry))
{
	if (!arguments.argument_map.count) return;
	foreach (&entry : arguments.argument_map.table)
	{
		while (entry)
		{
			@body(entry);
			entry = entry.next;
		}
	}
}

<*
 Free the arguments collection and its internal resources.
*>
fn void HttpPathArguments.free(&self)
{
	self.argument_map.free();
}


<*
 Format the arguments collection using the underlying arguments map formatter.

 @param [inout] formatter : "Formatter to write output to"
 @return "The number of characters written, or an error"
*>
fn sz? HttpPathArguments.to_format(&self, Formatter* formatter) @dynamic
{
	return self.argument_map.to_format(formatter);
}
