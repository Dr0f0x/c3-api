module c3api::routing;

import std::io;
import std::collections::enummap;

import c3api::http;

alias HandleFunc = fn void(Allocator allocator, HttpRequest*, HttpResponse*);

fn void e404(Allocator allocator, HttpRequest* req, HttpResponse* res)
{
	res.status = HttpStatus.NOT_FOUND;
	res.body = string::format(mem, `{"type":"error","status":404}`);

	res.headers.set_header_value("Content-Type", "application/json");
}

struct HandlerCollection (Printable)
{
	EnumMap{RouteMethod, HandleFunc} handler_map;
}

fn HandlerCollection* HandlerCollection.init(&self)
{
	self.handler_map.init(null);
	return self;
}

fn bool HandlerCollection.set_handler(&self, RouteMethod method, HandleFunc handler)
{
	bool already_present = self.has_handler(method);
	self.handler_map.set(method, handler);
	return already_present;
}

fn bool HandlerCollection.set_get(&self, HandleFunc handler) => self.set_handler(RouteMethod.GET, handler);
fn bool HandlerCollection.set_patch(&self, HandleFunc handler) => self.set_handler(RouteMethod.PATCH, handler);
fn bool HandlerCollection.set_put(&self, HandleFunc handler) => self.set_handler(RouteMethod.PUT, handler);
fn bool HandlerCollection.set_post(&self, HandleFunc handler) => self.set_handler(RouteMethod.POST, handler);
fn bool HandlerCollection.set_delete(&self, HandleFunc handler) => self.set_handler(RouteMethod.DELETE, handler);

fn HandleFunc? HandlerCollection.get_handler(&self, RouteMethod method)
{
	HandleFunc val = self.handler_map.get(method);
	if (val == null)
	{
		return NOT_FOUND~;
	}
	return val;
}

fn HandleFunc? HandlerCollection.get_get(&self) => self.get_handler(RouteMethod.GET);
fn HandleFunc? HandlerCollection.get_patch(&self) => self.get_handler(RouteMethod.PATCH);
fn HandleFunc? HandlerCollection.get_put(&self) => self.get_handler(RouteMethod.PUT);
fn HandleFunc? HandlerCollection.get_post(&self) => self.get_handler(RouteMethod.POST);
fn HandleFunc? HandlerCollection.get_delete(&self) => self.get_handler(RouteMethod.DELETE);

fn bool HandlerCollection.has_handler(&self, RouteMethod method)
{
	return self.handler_map.get(method) != null;
}

fn bool HandlerCollection.has_get(&self) => self.has_handler(RouteMethod.GET);
fn bool HandlerCollection.has_patch(&self) => self.has_handler(RouteMethod.PATCH);
fn bool HandlerCollection.has_put(&self) => self.has_handler(RouteMethod.PUT);
fn bool HandlerCollection.has_post(&self) => self.has_handler(RouteMethod.POST);
fn bool HandlerCollection.has_delete(&self) => self.has_handler(RouteMethod.DELETE);


fn void HandlerCollection.free(&self)
{
	// placeholder
}

fn sz? HandlerCollection.to_format(&self, Formatter* formatter) @dynamic
{
	sz len = formatter.print("HandlerCollection {")!;
	foreach (i, &value : self.handler_map.values)
	{
		if (i != 0) len += formatter.print(", ")!;
		len += formatter.printf("%s: %s", RouteMethod::from_ordinal(i), *value != null)!;
	}
	len += formatter.print(" }")!;
	return len;
}
