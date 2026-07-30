// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module c3api;

import std::io;
import std::collections::map;

struct Context (Printable)
{
	HashMap{typeid, void*} objects;
}

fn Context* Context.init(&self, Allocator allocator)
{
	self.objects.init(allocator);
	return self;
}

<*
 Copy all registered objects from another context.

 Existing entries with the same type id will be overwritten.

 @param [&in] other : "Source context to copy registrations from"
*>
fn void Context.add_from(&self, Context* other)
{
	other.objects.@each_entry(; map::Entry{typeid, void*}* entry)
	{
		self.objects.set(entry.key, entry.value);
	};
}

macro void Context.register(&self, $Type, value)
{
	$assert $Typeof(value) == $Type*;
	self.objects.set($Type, value);
}


macro Context.resolve(&self, $Type)
{
	void*? value = self.objects.get($Type);

	if (catch value) return NOT_FOUND~;

	return ($Type*)value;
}

fn sz? Context.to_format(&self, Formatter* formatter) @dynamic
{
	return self.objects.to_format(formatter);
}

fn void Context.free(&self)
{
	self.objects.free();
}




