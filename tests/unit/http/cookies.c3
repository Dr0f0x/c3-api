// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module test::http::cookies;

import std::core::mem;
import std::core::mem::allocators;
import std::collections::list;
import std::time::datetime;

import c3api::http::cookies;
import c3api::http::response;

fn void test_cookie_options_builder_sets_flags_and_values() @test
{
	DateTime expires = datetime::now();

	CookieOptions options = { };
	options.with_expires(expires).with_max_age(cookies::HOUR).with_domain("example.com").with_path("/app").with_secure()
		.with_http_only()
		.with_same_site(SameSite.LAX)
		.with_partitioned();

	assert((options.use & CookieOption.EXPIRES) != (CookieOption)0);
	assert((options.use & CookieOption.MAX_AGE) != (CookieOption)0);
	assert((options.use & CookieOption.DOMAIN) != (CookieOption)0);
	assert((options.use & CookieOption.PATH) != (CookieOption)0);
	assert((options.use & CookieOption.SECURE) != (CookieOption)0);
	assert((options.use & CookieOption.HTTP_ONLY) != (CookieOption)0);
	assert((options.use & CookieOption.SAME_SITE) != (CookieOption)0);
	assert((options.use & CookieOption.PARTITIONED) != (CookieOption)0);

	assert(options.expires == expires);
	assert(options.max_age == cookies::HOUR);
	assert(options.domain == "example.com");
	assert(options.path == "/app");
	assert(options.secure);
	assert(options.http_only);
	assert(options.same_site == SameSite.LAX);
	assert(options.partitioned);
}

fn void test_cookie_options_builder_produces_set_cookie_header() @test
{
	DynamicArenaAllocator arena;
	arena.init(mem, 4096);
	defer arena.free();

	HttpResponse res;
	res.init(&arena);
	defer res.free();

	CookieOptions options = { };
	options.with_max_age(cookies::HOUR).with_domain("example.com").with_path("/app").with_secure().with_http_only()
		.with_same_site(SameSite.LAX)
		.with_partitioned();

	res.set_cookie(mem, "session", "abc", options);

	if (try values = res.headers.get_header_values("Set-Cookie"))
	{
		assert(values.len() == 1);
		assert(values[0]
			== "session=abc; Max-Age=3600; Domain=example.com; Path=/app; Secure; HttpOnly; SameSite=Lax; Partitioned");
	}
	else
	{
		assert(false);
	}
}

fn void test_set_cookie_keeps_manual_options_api() @test
{
	DynamicArenaAllocator arena;
	arena.init(mem, 4096);
	defer arena.free();

	HttpResponse res;
	res.init(&arena);
	defer res.free();

	res.set_cookie(
		mem,
		"legacy",
		"1",
		{
			.use = CookieOption.PATH | CookieOption.SECURE,
			.path = "/",
			.secure = true,
		}
	);

	if (try values = res.headers.get_header_values("Set-Cookie"))
	{
		assert(values.len() == 1);
		assert(values[0] == "legacy=1; Path=/; Secure");
	}
	else
	{
		assert(false);
	}
}