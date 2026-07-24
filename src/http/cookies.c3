module c3api::http::cookies;

import std::time;
import std::collections::list;

import c3api::http;

faultdef COOKIE_NOT_SET;

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

			String cookie_name = cookie[0..eq-1].trim();

			if (cookie_name == name)
			{
				return cookie[eq + 1..];
			}
		}
	}

	return COOKIE_NOT_SET~;
}

typedef CookieDuration = long;

const CookieDuration DURATION_ZERO = (CookieDuration)0;
const CookieDuration SECOND        = (CookieDuration)1;
const CookieDuration MINUTE        = 60 * SECOND;
const CookieDuration HOUR          = 60 * MINUTE;
const CookieDuration DAY           = 24 * HOUR;
const CookieDuration WEEK          = 7 * DAY;
const CookieDuration MONTH         = 30 * DAY;
const CookieDuration YEAR          = 365 * DAY;
const CookieDuration FAR_FUTURE       = (CookieDuration)long::max;

fn CookieDuration sec(long s) @inline => (CookieDuration)s;
fn CookieDuration min(long m) @inline => m * MINUTE;
fn CookieDuration hour(long h) @inline => h * HOUR;
fn CookieDuration day(long d) @inline => d * DAY;
fn CookieDuration week(long w) @inline => w * WEEK;
fn CookieDuration month(long m) @inline => m * MONTH;
fn CookieDuration year(long y) @inline => y * YEAR;

fn long CookieDuration.to_seconds(self) @inline => (long)self;
fn long CookieDuration.to_minutes(self) @inline => (long)self / 60;
fn long CookieDuration.to_hours(self) @inline => (long)self / 3600;
fn long CookieDuration.to_days(self) @inline => (long)self / 86400;

macro CookieDuration CookieDuration.mult(#d, long #n) @operator_s(*) @safemacro => (CookieDuration)((long)#d * #n);

// SameSite
enum SameSite
{
	DEFAULT,
	STRICT,
	LAX,
	NONE
}

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

struct CookieOptions
{
	CookieOption options;

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

fn void HttpResponse.set_cookie(
	&self,
	Allocator allocator,
	String name,
	String value,
	CookieOptions options = { }
)
{
	DString cookie = dstring::temp();

	cookie.append(name);
	cookie.append("=");
	cookie.append(value);

	if (options.options & CookieOption.EXPIRES)
	{
		cookie.append("; Expires=");
		cookie.append(options.expires.format(allocator, DateTimeFormat.RFC1123));
	}

	if (options.options & CookieOption.MAX_AGE)
	{
		cookie.appendf("; Max-Age=%d", (long)options.max_age);
	}

	if (options.options & CookieOption.DOMAIN)
	{
		cookie.append("; Domain=");
		cookie.append(options.domain);
	}

	if (options.options & CookieOption.PATH)
	{
		cookie.append("; Path=");
		cookie.append(options.path);
	}

	if (options.options & CookieOption.SECURE)
	{
		cookie.append("; Secure");
	}

	if ((options.options & CookieOption.HTTP_ONLY )&& options.http_only)
	{
		cookie.append("; HttpOnly");
	}

	if (options.options & CookieOption.SAME_SITE)
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

	if ((options.options & CookieOption.PARTITIONED) && options.partitioned)
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