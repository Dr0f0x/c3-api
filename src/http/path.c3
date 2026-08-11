// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module c3api::http::args;

import std::collections;
import std::io;

struct HttpPathParams (Printable)
{
	HashMap{String, String} param_map;

	Allocator allocator;
}

<*
 Initialize the path arguments collection with an allocator.

 @param [&inout] allocator : "Allocator to use for internal allocations"
 @return "The initialized arguments collection"
*>
fn HttpPathParams* HttpPathParams.init(&self, Allocator allocator)
{
	self.param_map.init(allocator);
	self.allocator = allocator;
	return self;
}

<*
 Check if the arguments collection has been initialized.

 @return "true if initialized, false otherwise"
*>
fn bool HttpPathParams.is_initialized(&self)
{
	return self.param_map.is_initialized();
}

<*
 Set a parameter value in the parameters map.

 If the parameter key already exists, the value is replaced with the new value.

 @param [in] parameter_name : "Parameter name"
 @param [in] parameter_value : "Parameter value"
 @return "True if the parameter key already existed, false if a new parameter key was added"
*>
fn bool HttpPathParams.set_argument_value(&self, String parameter_name, String parameter_value) @operator([]=)
{
	return self.param_map.set(parameter_name, parameter_value);
}

<*
 Get the value for a given parameter key.

 @param [in] parameter_name : "Parameter name"
 @return "The parameter value, or NOT_FOUND~ if the key does not exist"
*>
fn String? HttpPathParams.get_argument_value(&self, String parameter_name) @operator([])
{
	return *self.param_map.get_ref(parameter_name) @inline;
}

<*
 Get the number of parameters stored in the parameters map.

 @return "The count of unique parameter keys"
*>
fn sz HttpPathParams.len(&self)
{
	return self.param_map.len();
}

macro HttpPathParams.@each(arguments; @body(key, value))
{
	arguments.param_map.@each_entry(; map::Entry{String, String}* entry)
	{
		@body(entry.key, entry.value);
	};
}

macro HttpPathParams.@each_entry(arguments; @body(entry))
{
	if (!arguments.param_map.count) return;
	foreach (&entry : arguments.param_map.table)
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
fn void HttpPathParams.free(&self)
{
	self.param_map.free();
}


<*
 Format the arguments collection using the underlying arguments map formatter.

 @param [inout] formatter : "Formatter to write output to"
 @return "The number of characters written, or an error"
*>
fn sz? HttpPathParams.to_format(&self, Formatter* formatter) @dynamic
{
	return self.param_map.to_format(formatter);
}