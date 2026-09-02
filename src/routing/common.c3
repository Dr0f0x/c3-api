// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module c3api::routing;

import std::io;

<*
 ROUTE_NOT_FOUND: no route or method match for the request.
 ROUTE_ALREADY_PRESENT: route existed before replacement.
*>
faultdef ROUTE_NOT_FOUND, ROUTE_ALREADY_PRESENT;

<*
 Append one character to a string builder.

 @param data : "String builder receiving the character"
 @param c : "Character to append"
 @return "Success or the formatter error"
*>
fn void? append_fn(void* data, char c) @private
{
	DString* s = data;
	s.append_char(c) @inline;
}

<*
 Print the registered route tree.

 @param router : "Router or group whose routes are printed"
*>
macro void print_routes(router)
{
	DString output = dstring::temp();

	Formatter formatter;
	formatter.init(&append_fn, &output);

	router.to_route_format(&formatter)!!;

	io::print(output.str_view());
}