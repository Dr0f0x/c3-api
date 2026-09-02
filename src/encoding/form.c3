// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module c3api::encoding::form;

import std::collections::list;
import std::collections::object;
import std::core::dstring;
import std::core::string;
import std::io;

import c3api::http::params;

faultdef FORM_MALFORMED;

const String HEX_DIGITS = "0123456789ABCDEF";

fn int hex_nibble(char ch) @private
{
	if (ch >= '0' && ch <= '9') return (int)(ch - '0');
	if (ch >= 'a' && ch <= 'f') return 10 + (int)(ch - 'a');
	if (ch >= 'A' && ch <= 'F') return 10 + (int)(ch - 'A');
	return -1;
}

fn char hex_digit(int nibble) @private
{
	return HEX_DIGITS[nibble & 0xF];
}

fn String? decode_component(String value) @private
{
	DString out;
	out.tinit();

	for (sz i = 0; i < value.len; i++)
	{
		char ch = value[i];

		if (ch == '+')
		{
			out.append_char(' ');
			continue;
		}

		if (ch == '%')
		{
			if (i + 2 >= value.len) return FORM_MALFORMED~;

			int hi = hex_nibble(value[i + 1]);
			int lo = hex_nibble(value[i + 2]);

			if (hi < 0 || lo < 0) return FORM_MALFORMED~;

			out.append_char((char)((hi << 4) | lo));

			i += 2;
			continue;
		}

		out.append_char(ch);
	}

	return out.str_view();
}

fn bool is_integer_literal(String value) @private
{
	if (value == "") return false;
	sz start = 0;
	if (value[0] == '-' || value[0] == '+')
	{
		if (value.len == 1) return false;
		start = 1;
	}

	for (sz i = start; i < value.len; i++)
	{
		char ch = value[i];
		if (ch < '0' || ch > '9') return false;
	}
	return true;
}

fn bool is_float_literal(String value) @private
{
	if (value == "") return false;
	bool seen_dot   = false;
	bool seen_digit = false;
	sz start        = 0;
	if (value[0] == '-' || value[0] == '+')
	{
		if (value.len == 1) return false;
		start = 1;
	}

	for (sz i = start; i < value.len; i++)
	{
		char ch = value[i];
		if (ch == '.')
		{
			if (seen_dot) return false;
			seen_dot = true;
			continue;
		}
		if (ch < '0' || ch > '9') return false;
		seen_digit = true;
	}

	return seen_dot && seen_digit;
}

fn Object*? create_scalar_object_from_text(Allocator allocator, String value) @private
{
	String trimmed = value.trim();
	if (trimmed == "true") return object::new_bool(true);
	if (trimmed == "false") return object::new_bool(false);

	if (is_integer_literal(trimmed))
	{
		return object::new_int(allocator, trimmed.to_int128())!;
	}

	if (is_float_literal(trimmed))
	{
		return object::new_float(allocator, trimmed.to_double())!;
	}

	return object::new_string(allocator, trimmed);
}

fn void? set_scalar_object_from_text(Object* parent, String key, String value) @private
{
	String trimmed = value.trim();
	if (trimmed == "true") parent.set(key, true);
	if (trimmed == "false") parent.set(key, false);

	if (is_integer_literal(trimmed))
	{
		parent.set(key, trimmed.to_int128())!;
	}

	if (is_float_literal(trimmed))
	{
		parent.set(key, trimmed.to_double())!;
	}

	parent.set(key, trimmed);
}

fn Object* get_or_create_nested_object(Object* obj, String[] path)
{
	Object* current = obj;

	for (sz i = 0; i < path.len; i++)
	{
		current = obj.get_or_create_obj(path[i]);
	}
	return current;
}

fn void? set_bracket_value(Allocator allocator, Object* root, String[] parts, String value) @private
{
	Object* parent = get_or_create_nested_object(root, parts[..parts.len - 2]);

	String key = parts[parts.len - 1];

	// Array in brackets notation
	if (key == "")
	{
		Object* value_obj = create_scalar_object_from_text(allocator, value)!;
		if (parent.is_array())
		{
			parent.push(value_obj);
		}
		else if (parent.is_empty())
		{
			parent.push_object(value_obj);
		}
	}
	else
	{
		set_scalar_object_from_text(parent, key, value)!;
	}
}

fn String[] parse_bracket_key(String key) @private
{
	String[] raw_parts = key.tsplit("[");
	String[] parts     = alloc::alloc_array(tmem, String, raw_parts.len);

	for (sz i = 0; i < raw_parts.len; i++)
	{
		if (raw_parts[i][raw_parts[i].len - 1] == ']')
		{
			parts[i] = raw_parts[i][..raw_parts[i].len - 2];
		}
		else
		{
			parts[i] = raw_parts[i];
		}
	}
	return parts;
}

fn Object*? parse(Allocator allocator, String value)
{
	Object* out = object::new_obj(allocator);

	if (value.trim() == "") return out;

	@pool()
	{
		foreach (String pair : value.tsplit("&"))
		{
			if (pair == "") continue;

			sz eq = pair.index_of_char('=') ?? -1;
			String raw_key;
			String raw_val;

			if (eq < 0)
			{
				raw_key = pair;
				raw_val = "";
			}
			else
			{
				raw_key = pair[0..eq - 1];
				raw_val = pair[eq + 1..];
			}

			String key = decode_component(raw_key)!;
			String val = decode_component(raw_val)!;

			if (key == "") continue;
			String[] parts = parse_bracket_key(key);

			set_bracket_value(allocator, out, parts, val)!;
		}
	};

	return out;
}

fn Object*? tparse(String value)
{
	return parse(tmem, value);
}

<*
 Decode query parameters into an Object map using form scalar coercion rules.

 Keys and values are URL-decoded and converted to primitive object values
 (bool, int, float, or string).

 @param allocator : "Allocator used for the produced object tree"
 @param query : "Query parameter container"
*>
fn Object*? parse_query_params(Allocator allocator, params::HttpQueryParams* query)
{
	Object* out = object::new_obj(allocator);

	@pool()
	{
		query.@each(; String key, String value)
		{
			if (key != "")
			{
				String decoded_key = decode_component(key)!;
				String decoded_val = decode_component(value)!;

				if (decoded_key != "")
				{
					String[] parts = parse_bracket_key(decoded_key);

					set_bracket_value(allocator, out, parts, decoded_val)!;
				}
			}
		};
	};

	return out;
}

<*
 Decode query parameters into an Object map using temporary memory.

 @param query : "Query parameter container"
*>
fn Object*? tparse_query_params(params::HttpQueryParams* query)
{
	return parse_query_params(tmem, query);
}

fn void? encode_component(OutStream out, String value) @private
{
	for (sz i = 0; i < value.len; i++)
	{
		char ch = value[i];
		if ((ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') || ch == '-' || ch == '_'
			|| ch == '.'
			|| ch == '~')
		{
			out.write(value[i..i])!;
			continue;
		}

		if (ch == ' ')
		{
			out.write("+")!;
			continue;
		}

		out.write_byte('%')!;
		uint byte = (uint)ch & 0xFF;
		out.write_byte(hex_digit((int)(byte >> 4)))!;
		out.write_byte(hex_digit((int)byte))!;
	}
}

fn void? append_form_pair(OutStream out, bool* first, String prefix, String key, String value) @private
{
	if (!*first)
	{
		out.write("&")!;
	}
	else
	{
		*first = false;
	}

	String pair_prefix;
	if (prefix == "")
	{
		pair_prefix = key;
	}
	else
	{
		pair_prefix = string::tformat("%s[%s]", prefix, key);
	}
	encode_component(out, pair_prefix)!;
	out.write("=")!;
	encode_component(out, value)!;
}

macro bool may_serialize($Type) @const
{
	$switch $Type::kind:
		$case STRUCT:
			$foreach $member : $Type::members:
				$if $member.name == "" ||| !may_serialize($member.type):
					return false;
				$endif
			$endforeach
			return true;
		$case SIGNED_INT:
		$case UNSIGNED_INT:
		$case FLOAT:
		$case BOOL:
		$case ENUM:
			return true;
		$case TYPEDEF:
		$case CONSTDEF:
		$case ARRAY:
		$case VECTOR:
		$case SLICE:
			return may_serialize($Type::inner);
		$default:
			return false;
	$endswitch
}

fn void? serialize_form_struct(OutStream out, bool* first, String prefix, Type value)<Type>
{
	$foreach $member : Type::members:
		$if $member.name != "":
			$if $member.has_tag("form"):
				// @Form("-") explicitly excludes the member.
				$if $member.get_tag("form") != "-":
					serialize_form_value{$member.type}(out, first, prefix, $member.get_tag("form"), value.$member)!;
				$endif
			$else
				serialize_form_value{$member.type}(out, first, prefix, $member.name, value.$member)!;
			$endif
		$endif

	$endforeach
}

fn void? serialize_form_value(OutStream out, bool* first, String prefix, String key, TypeElement value)<TypeElement>
{
	$switch TypeElement::kind:
		$case STRUCT:
			String struct_prefix;
			if (prefix == "")
			{
				struct_prefix = key;
			}
			else
			{
				struct_prefix = string::tformat("%s[%s]", prefix, key);
			}
			serialize_form_struct{TypeElement}(out, first, struct_prefix, value)!;
		$case SIGNED_INT:
		$case UNSIGNED_INT:
		$case FLOAT:
		$case BOOL:
		$case ENUM:
			append_form_pair(out, first, prefix, key, string::format(tmem, "%s", value))!;
		$case TYPEDEF:
		$case CONSTDEF:
			$switch TypeElement:
				// Special handling of String
				$case String:
					append_form_pair(out, first, prefix, key, value)!;
				$default:
					var $Inner = TypeElement::inner;
					return serialize_form_value{$Inner}(stream, first, prefix, key, ($Inner)value);
			$endswitch
		$case ARRAY:
		$case VECTOR:
		$case SLICE:
			serialize_slice{$Typeof(value[0])}(out, first, value, prefix, key)!;
		$default:
			@compile_error("marshal_form: unsupported type");
	$endswitch
}

fn void? serialize_slice(OutStream stream, bool* first, SliceType[] slice, String prefix, String key)<SliceType>
{
	String slice_prefix;
	if (prefix != "")
	{
		slice_prefix = string::tformat("%s[%s]", prefix, key);
	}
	else
	{
		slice_prefix = key;
	}
	foreach (element : slice)
	{
		serialize_form_value{SliceType}(stream, first, slice_prefix, "", element)!;
	}
}

<*
 Marshal a struct to application/x-www-form-urlencoded.

 @param allocator : "The allocator to use for the result"
 @param value : "The struct value to marshal"
 @require @kindof(value) == STRUCT
 @require may_serialize($Typeof(value)) : "Expected a serializable type"
 @return "The form-encoded string representation"
*>
macro String marshal_form(Allocator allocator, value) => @pool()
{
	DString s;
	s.tinit();
	marshal_form_to(&s, value)!!;
	return s.copy_str(allocator);
}

<*
 Marshal a struct to application/x-www-form-urlencoded.

 @param stream : "The stream to serialize to"
 @param value : "The struct value to marshal"
 @require @kindof(value) == STRUCT
 @require may_serialize($Typeof(value)) : "Expected a serializable type"
*>
macro void? marshal_form_to(OutStream stream, value)
{
	DString s;
	s.tinit();
	bool first = true;
	serialize_form_struct{$Typeof(value)}(&s, &first, "", value)!;
	stream.write(s.str_view())!;
}