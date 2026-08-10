module c3api::encoding::json;

import std::io;
import std::math;
import std::encoding::json;

macro may_serialize($Type) => std::encoding::json::may_serialize($Type);

alias Indent = std::encoding::json::Indent;

<*
 Marshal a struct with primitive fields and nested structs to JSON.

 @param allocator : "The allocator to use for the result"
 @param value : "The struct value to marshal"
 @require @kindof(value) == STRUCT
 @require may_serialize($Typeof(value)) : "Expected a serializable type"
 @return "The JSON string representation"
*>
macro String marshal_json(Allocator allocator, value, json::Indent indent = NONE) => @pool()
{
	DString s;
	s.tinit();
	marshal_json_to(&s, value, indent)!!;
	return s.copy_str(allocator);
}

<*
 Marshal a struct with primitive fields and nested structs to JSON.

 @param stream : "The steam to serialize to"
 @param value : "The struct value to marshal"
 @param indent : "Indentation preference"
 @require @kindof(value) == STRUCT
 @require may_serialize($Typeof(value)) : "Expected a serializable type"
 @return ? io::fprintf!, json::INVALID_NUMBER
*>
macro void? marshal_json_to(OutStream stream, value, Indent indent = NONE)
{
	return serialize_json_struct{$Typeof(value)}(stream, value, indent, 0);
}

fn void? write_indent(OutStream stream, Indent indent, int indent_depth)
{
	if (indent == NONE) return;
	for (int i = 0; i < indent_depth; i++)
	{
		stream.write(indent.chars)!;
	}
}

fn void? serialize_json_struct(OutStream stream, Type value, Indent indent = NONE, int indent_depth = 0)<Type>
{
	bool pretty_print = indent != NONE;
	stream.write_byte('{')!;

	$if Type::members.len:
		if (pretty_print) stream.write_byte('\n')!;
	$endif

	var $first = true;

	$foreach $member : Type::members:
		$if $member.name != "":
			$if $member.has_tag("json"):
				$if $member.get_tag("json") != "-":
					if (!$first)
					{
						stream.write_byte(',')!;
						if (pretty_print) stream.write_byte('\n')!;
					}
					$first = false;

					if (pretty_print) write_indent(stream, indent, indent_depth + 1)!;

					// Add field name (always quoted)
					stream.write_byte('"')!;
					stream.write($member.get_tag("json"))!;
					stream.write(pretty_print ? `": ` : `":`)!;

					serialize_json_value{$member.type}(stream, value.$member, indent, indent_depth + 1)!;
				$endif
			$else
				if (!$first)
				{
					stream.write_byte(',')!;
					if (pretty_print) stream.write_byte('\n')!;
				}
				$first = false;

				if (pretty_print) write_indent(stream, indent, indent_depth + 1)!;

				// Add field name (always quoted)
				stream.write_byte('"')!;
				stream.write($member.name)!;
				stream.write(pretty_print ? `": ` : `":`)!;

				serialize_json_value{$member.type}(stream, value.$member, indent, indent_depth + 1)!;
			$endif
		$endif
	$endforeach

	$if Type::members.len:
		if (pretty_print)
		{
			stream.write_byte('\n')!;
			write_indent(stream, indent, indent_depth)!;
		}
	$endif
	stream.write_byte('}')!;
}

<*
 Marshal a value to JSON.

 @param value : "The value to marshal"
 @return ? json::INVALID_NUMBER : "If the float value is NaN or inf"
 @return ? io::fprintf! : "If there is an IO error"
*>
fn void? serialize_json_value(
	OutStream stream,
	TypeElement value,
	Indent indent = NONE,
	int indent_depth = 0
)<TypeElement>
{
	$switch TypeElement::kind:
		$case STRUCT:
			return serialize_json_struct{TypeElement}(stream, value, indent, indent_depth);
		$case ARRAY:
		$case VECTOR:
			return serialize_slice{$Typeof(value[0])}(stream, &value, indent, indent_depth);
		$case SLICE:
			return serialize_slice{$Typeof(value[0])}(stream, value, indent, indent_depth);
		$case SIGNED_INT:
		$case UNSIGNED_INT:
			io::fprintf(stream, "%d", value)!;
		$case FLOAT:
			if (math::is_nan(value) || math::is_inf(value)) return json::INVALID_NUMBER~;
			io::fprintf(stream, "%.17g", (double)value)!;
		$case BOOL:
			stream.write(value ? "true" : "false")!;
		$case CONSTDEF:
		$case TYPEDEF:
			$switch TypeElement:
				// Special handling of String
				$case String:
					serialize_string(stream, value)!;
				$default:
					var $Inner = TypeElement::inner;
					return serialize_value{$Inner}(stream, ($Inner)value, indent, indent_depth);
			$endswitch
		$case ENUM:
			io::fprintf(stream, `"%s"`, value.description)!;
		$default:
			$error "Unsupported type";
	$endswitch
}

<*
 Marshal a slice of primitive values to JSON.
*>
fn void? serialize_slice(OutStream stream, SliceType[] slice, Indent indent = NONE, int indent_depth = 0)<SliceType>
{
	bool pretty_print = indent != NONE;
	stream.write_byte('[')!;
	if (slice && pretty_print) stream.write_byte('\n')!;

	foreach (i, element : slice)
	{
		if (i > 0)
		{
			stream.write_byte(',')!;
			if (pretty_print) stream.write_byte('\n')!;
		}
		if (pretty_print) write_indent(stream, indent, indent_depth + 1)!;
		serialize_value{SliceType}(stream, element, indent, indent_depth + 1)!;
	}
	if (slice && pretty_print)
	{
		stream.write_byte('\n')!;
		write_indent(stream, indent, indent_depth)!;
	}

	stream.write_byte(']')!;
}

macro void? serialize_string(OutStream stream, String string) @private
{
	WriteFn write          = &stream.write;
	WriteByteFn write_byte = &stream.write_byte;
	write(stream, `"`)!;
	foreach (c : string)
	{
		if (c >= 0x80)
		{
			write_byte(stream, c)!;
			continue;
		}
		switch (c)
		{
			case '"': write(stream, `\"`)!;
			case '\\': write(stream, `\\`)!;
			case '\b': write(stream, `\b`)!;
			case '\f': write(stream, `\f`)!;
			case '\n': write(stream, `\n`)!;
			case '\r': write(stream, `\r`)!;
			case '\t': write(stream, `\t`)!;
			default:
				if (c >= 32)
				{
					write_byte(stream, c)!;
					continue;
				}
				io::fprintf(stream, `\u%04x`, c)!;
		}
	}
	write(stream, `"`)!;
}
