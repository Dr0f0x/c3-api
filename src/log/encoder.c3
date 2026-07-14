module c3api::log;

import std::time;
import std::core::string::ansi;
import std::collections::object;
import std::encoding::json;
import std::io;

alias EncoderFunc = fn String(Allocator allocator, LogEntry* entry);

fn String plain_encode(Allocator allocator, LogEntry* entry)
{
	return string::format(
		allocator,
		"[%s] [%s] %s",
		entry.timestamp.format(allocator, DateTimeFormat.UNIXDATE),
		entry.level.name_upper,
		string::format(allocator, entry.fmt_msg, ...values(allocator, entry.fields))
	);
}

fn String color_encode(Allocator allocator, LogEntry* entry)
{
	Ansi color;
	switch (entry.level)
	{
		case TRACE:
			color = Ansi.BLACK;
		case DEBUG:
			color = Ansi.BLUE;
		case INFO:
			color = Ansi.GREEN;
		case WARN:
			color = Ansi.YELLOW;
		case ERROR:
		case FATAL:
			color = Ansi.RED;
	}

	return string::format(
		allocator,
		"%s[%s] [%s] %s%s",
		color,
		entry.timestamp.format(allocator, DateTimeFormat.UNIXDATE),
		entry.level.name_upper,
		string::format(allocator, entry.fmt_msg, ...values(allocator, entry.fields)),
		Ansi.RESET
	);
}

fn String json_encode(Allocator allocator, LogEntry* entry)
{
	DString out = dstring::new(allocator);

	out.append("{");

	out.appendf(`"timestamp":"%s"`, entry.timestamp.format(allocator, DateTimeFormat.UNIXDATE));
	out.appendf(`,"level":"%s"`, entry.level.name);
	out.appendf(`,"msg":"%s"`, entry.strct_msg);

	foreach (Field field : entry.fields)
	{
		out.appendf(`,"%s":`, field.name);

		if (field.value.type == String::typeid)
		{
			out.appendf(`"%s"`, field.value);
		}
		else
		{
			out.appendf("%s", field.value);
		}
	}

	out.append("}");

	return out.str_view();
}
