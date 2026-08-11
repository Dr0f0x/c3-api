// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module c3api::context;

import std::io;
import std::collections::map;

struct Context (Printable)
{
	HashMap{typeid, void*} objects;
	HashMap{String, void*} map;
}

fn Context* Context.init(&self, Allocator allocator)
{
	self.objects.init(allocator);
	self.map.init(allocator);
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
	other.map.@each_entry(; map::Entry{String, void*}* entry)
	{
		self.map.set(entry.key, entry.value);
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

fn bool Context.set(&self, String key, void* val)
{
	return self.map.set(key, val);
}

fn void*? Context.get(&self, String key)
{
	void**? value = self.map.get_ref(key);
	if (catch value) return NOT_FOUND~;
	return *value;
}

fn sz? Context.to_format(&self, Formatter* formatter) @dynamic
{
	return self.objects.to_format(formatter);
}

fn void Context.free(&self)
{
	self.objects.free();
}