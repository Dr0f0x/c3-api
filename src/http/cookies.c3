// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module c3api::http::cookies;

import std::time;
import std::collections::list;

import c3api::http;

<* Fault raised when a requested cookie is not present. *>
faultdef COOKIE_NOT_SET;

<*
 Retrieve a cookie value from a request.
 @param self : "Request containing Cookie headers"
 @param name : "Cookie name to retrieve"
 @return "Cookie value or COOKIE_NOT_SET~"
*>
fn String? HttpRequest.get_cookie(&self, String name)
{
	List{String}? values = self.headers.get_header_values("Cookie");
	if (catch err = values)
	{
		return COOKIE_NOT_SET~;
	}

	foreach (header : values)
	{
		foreach (cookie : header.tsplit(";"))
		{
			cookie = cookie.trim();

			sz eq = cookie.index_of_char('=') ?? -1;
			if (eq < 0) continue;

			String cookie_name = cookie[0..eq - 1].trim();

			if (cookie_name == name)
			{
				return cookie[eq + 1..];
			}
		}
	}

	return COOKIE_NOT_SET~;
}

<* Duration in seconds used for cookie expiration attributes. *>
typedef CookieDuration = long;

const CookieDuration DURATION_ZERO = (CookieDuration)0;
const CookieDuration SECOND        = (CookieDuration)1;
const CookieDuration MINUTE        = 60 * SECOND;
const CookieDuration HOUR          = 60 * MINUTE;
const CookieDuration DAY           = 24 * HOUR;
const CookieDuration WEEK          = 7 * DAY;
const CookieDuration MONTH         = 30 * DAY;
const CookieDuration YEAR          = 365 * DAY;
const CookieDuration FAR_FUTURE    = (CookieDuration)long::max;

<* Create a duration in seconds. @param s : "Number of seconds" @return "Cookie duration" *>
fn CookieDuration sec(long s) @inline => (CookieDuration)s;
<* Create a duration in minutes. @param m : "Number of minutes" @return "Cookie duration" *>
fn CookieDuration min(long m) @inline => m * MINUTE;
<* Create a duration in hours. @param h : "Number of hours" @return "Cookie duration" *>
fn CookieDuration hour(long h) @inline => h * HOUR;
<* Create a duration in days. @param d : "Number of days" @return "Cookie duration" *>
fn CookieDuration day(long d) @inline => d * DAY;
<* Create a duration in weeks. @param w : "Number of weeks" @return "Cookie duration" *>
fn CookieDuration week(long w) @inline => w * WEEK;
<* Create a duration in months. @param m : "Number of months" @return "Cookie duration" *>
fn CookieDuration month(long m) @inline => m * MONTH;
<* Create a duration in years. @param y : "Number of years" @return "Cookie duration" *>
fn CookieDuration year(long y) @inline => y * YEAR;

<* Convert a duration to seconds. @param self : "Cookie duration" @return "Duration in seconds" *>
fn long CookieDuration.to_seconds(self) @inline => (long)self;
<* Convert a duration to minutes. @param self : "Cookie duration" @return "Duration in minutes" *>
fn long CookieDuration.to_minutes(self) @inline => (long)self / 60;
<* Convert a duration to hours. @param self : "Cookie duration" @return "Duration in hours" *>
fn long CookieDuration.to_hours(self) @inline => (long)self / 3600;
<* Convert a duration to days. @param self : "Cookie duration" @return "Duration in days" *>
fn long CookieDuration.to_days(self) @inline => (long)self / 86400;

<* Multiply a cookie duration. @param d : "Cookie duration" @param n : "Multiplier" @return "Scaled cookie duration" *>
macro CookieDuration CookieDuration.mult(#d, long #n) @operator_s(*) @safemacro => (CookieDuration)((long)#d * #n);

<* SameSite cookie attribute values. *>
enum SameSite
{
	DEFAULT,
	STRICT,
	LAX,
	NONE
}

<* Flags that select CookieOptions fields to emit. *>
constdef CookieOption : ushort
{
	EXPIRES     = 1 << 0,
	MAX_AGE     = 1 << 1,
	DOMAIN      = 1 << 2,
	PATH        = 1 << 3,
	SECURE      = 1 << 4,
	HTTP_ONLY   = 1 << 5,
	SAME_SITE   = 1 << 6,
	PARTITIONED = 1 << 7,
}

<* Cookie attributes used when creating a Set-Cookie header. *>
struct CookieOptions
{
	CookieOption use;

	// Lifetime
	DateTime expires; // e.g. "Wed, 09 Jun 2027 10:18:14 GMT"
	CookieDuration max_age; // Seconds

	// Scope
	String domain;
	String path;

	// Security
	bool secure;
	bool http_only;

	SameSite same_site;

	// CHIPS
	bool partitioned;
}

<*
 Set or replace a response cookie.
 @param self : "Response receiving the Set-Cookie header"
 @param allocator : "Allocator used to format date values"
 @param name : "Cookie name"
 @param value : "Cookie value"
 @param options : "Cookie attributes to emit"
*>
fn void HttpResponse.set_cookie(&self, Allocator allocator, String name, String value, CookieOptions options = { })
{
	DString cookie = dstring::temp();

	cookie.append(name);
	cookie.append("=");
	cookie.append(value);

	if (options.use & CookieOption.EXPIRES)
	{
		cookie.append("; Expires=");
		cookie.append(options.expires.format(allocator, DateTimeFormat.RFC1123));
	}

	if (options.use & CookieOption.MAX_AGE)
	{
		cookie.appendf("; Max-Age=%d", (long)options.max_age);
	}

	if (options.use & CookieOption.DOMAIN)
	{
		cookie.append("; Domain=");
		cookie.append(options.domain);
	}

	if (options.use & CookieOption.PATH)
	{
		cookie.append("; Path=");
		cookie.append(options.path);
	}

	if (options.use & CookieOption.SECURE)
	{
		cookie.append("; Secure");
	}

	if ((options.use & CookieOption.HTTP_ONLY) && options.http_only)
	{
		cookie.append("; HttpOnly");
	}

	if (options.use & CookieOption.SAME_SITE)
	{
		switch (options.same_site)
		{
			case SameSite.LAX:
				cookie.append("; SameSite=Lax");

			case SameSite.STRICT:
				cookie.append("; SameSite=Strict");

			case SameSite.NONE:
				cookie.append("; SameSite=None");

			default:
				break;
		}
	}

	if ((options.use & CookieOption.PARTITIONED) && options.partitioned)
	{
		cookie.append("; Partitioned");
	}

	String cookie_str = cookie.copy_str(self.headers.allocator);

	if (try values = self.headers.get_header_values("Set-Cookie"))
	{
		foreach (i, existing : values)
		{
			sz eq = existing.index_of_char('=') ?? -1;
			if (eq < 0) continue;

			String existing_name = existing[0..eq].trim();

			if (existing_name == name)
			{
				values[i] = cookie_str;
				return;
			}
		}
	}

	self.headers.add_header_value("Set-Cookie", cookie_str);
}