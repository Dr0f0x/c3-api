module c3api::log;

import std::time;

alias EncoderFunc = fn String(Allocator allocator, LogEntry* entry);

fn String simple_encode(Allocator allocator, LogEntry* entry)
{
	return string::format(
		allocator,
		"[%s] [%s] %s",
		entry.timestamp.format(allocator, DateTimeFormat.UNIXDATE),
		entry.level.name_upper,
		entry.message
	);
}
