module main;

import std::time;

faultdef INVALID_TIMESTAMP, TIMESTAMP_OVERFLOW;

<*
 Decode a Unix timestamp expressed as seconds.

 Examples:
   "0"          -> 1970-01-01 00:00:00 UTC
   "1"          -> 1970-01-01 00:00:01 UTC
   "1775778300" -> corresponding UTC DateTime

 Unix timestamps are seconds since:
   1970-01-01 00:00:00 UTC

 Returns INVALID_TIMESTAMP if the string is empty or contains
 non-numeric characters.

 Returns TIMESTAMP_OVERFLOW if the value cannot fit in a long.
*>
fn DateTime? from_unix_seconds(String str)
{
	if (str.len == 0) return INVALID_TIMESTAMP~;

	sz i          = 0;
	bool negative = false;

	if (str[0] == '-')
	{
		negative = true;
		i = 1;

		if (i == str.len) return INVALID_TIMESTAMP~;
	}

	long value = 0;

	for (; i < str.len; i++)
	{
		char c = str[i];

		if (c < '0' || c > '9')
		{
			return INVALID_TIMESTAMP~;
		}

		long digit = (long)(c - '0');

		// Check overflow before: value = value * 10 + digit
		if (value > (long::max - digit) / 10)
		{
			return TIMESTAMP_OVERFLOW~;
		}

		value = value * 10 + digit;
	}

	if (negative)
	{
		value = -value;
	}

	// Convert Unix seconds to the microsecond-based Time
	// representation used by std::time.
	Time timestamp = (Time)(value * (long)time::SEC);

	return datetime::from_time(timestamp);
}