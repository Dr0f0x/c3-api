module c3api::log;

import std::time;
import std::core::string::ansi;
import std::collections::object;
import std::encoding::json;
import std::io;

<*
 Log entry encoder callback.

 Implementations transform a log entry into a final string representation.
*>
alias EncoderFunc = fn String(Allocator allocator, LogEntry* entry);

<*
 Encode a log entry as plain human-readable text.

 Format: [timestamp] [LEVEL] message

 @param [&inout] allocator : "Allocator used to build the encoded string"
 @param [in] entry : "Entry to encode"
 @return "Plain text encoded log line"
*>
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

<*
 Encode a log entry as ANSI-colored text for terminal output.

 @param [&inout] allocator : "Allocator used to build the encoded string"
 @param [in] entry : "Entry to encode"
 @return "ANSI-colored encoded log line"
*>
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

<*
 Encode a log entry as a JSON object.

 The output includes timestamp, level, message and all attached fields.

 @param [&inout] allocator : "Allocator used to build the encoded string"
 @param [in] entry : "Entry to encode"
 @return "JSON encoded log line"
*>
fn String json_encode(Allocator allocator, LogEntry* entry)
{
	DString out = dstring::new(allocator);

	out.append("{");

	out.appendf(`"timestamp":"%s"`, entry.timestamp.format(allocator, DateTimeFormat.RFC3339));
	out.appendf(`,"level":"%s"`, entry.level.name);
	out.appendf(`,"msg":"%s"`, entry.strct_msg);

	foreach (Field field : entry.fields)
	{
		out.appendf(`,"%s":`, field.name);

		switch (field.value.type.kind)
		{
			case BOOL:
			case SIGNED_INT:
			case UNSIGNED_INT:
			case FLOAT:
				out.appendf("%s", field.value);
				break;
			case ARRAY:
			case VECTOR:
			case SLICE:
			case UNTYPEDLIST:
				typeid inner = field.value.type.inner;
				if (inner == void) inner = char;

				sz size = inner.size;
				sz len;
				void* data_ptr;

				if (field.value.type.kind == SLICE)
				{
					String* slice = field.value.ptr;
					data_ptr = slice.ptr;
					len = slice.len;
				}
				else
				{
					data_ptr = field.value.ptr;
					len = field.value.type.len;
				}

				out.append("[");

				for (sz i = 0; i < len; i++)
				{
					if (i != 0) out.append(",");
					any elem = any_make(data_ptr, inner);

					switch (inner.kind)
					{
						case BOOL:
						case SIGNED_INT:
						case UNSIGNED_INT:
						case FLOAT:
							out.appendf("%s", field.value);
							break;
						default:
							out.appendf(`"%s"`, elem);
					}

					data_ptr += size;
				}

				out.append("]");
				break;
			default:
				out.appendf(`"%s"`, field.value);
		}
	}

	out.append("}");

	return out.str_view();
}
