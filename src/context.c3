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
