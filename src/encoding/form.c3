module c3api::encoding::form;

import std::collections::object;
import std::core::dstring;
import std::core::string;
import std::io;

import c3api::http::params;

faultdef FORM_MALFORMED;

fn int hex_nibble(char ch) @private
{
	if (ch >= '0' && ch <= '9') return (int)(ch - '0');
	if (ch >= 'a' && ch <= 'f') return 10 + (int)(ch - 'a');
	if (ch >= 'A' && ch <= 'F') return 10 + (int)(ch - 'A');
	return -1;
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
			out.append(" ");
			continue;
		}

		if (ch == '%')
		{
			if (i + 2 >= value.len) return FORM_MALFORMED~;

			int hi = hex_nibble(value[i + 1]);
			int lo = hex_nibble(value[i + 2]);
			if (hi < 0 || lo < 0) return FORM_MALFORMED~;

			char decoded = (char)((hi << 4) | lo);
			char[2] one = { decoded, 0 };
			out.append((String)&one);
			i += 2;
			continue;
		}

		out.append(value[i..i]);
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

fn Object* scalar_object_from_text(Allocator allocator, String value) @private
{
	String trimmed = value.trim();
	if (trimmed == "true") return object::new_bool(true);
	if (trimmed == "false") return object::new_bool(false);

	if (is_integer_literal(trimmed))
	{
		return object::new_int(allocator, trimmed.to_int128())!!;
	}

	if (is_float_literal(trimmed))
	{
		return object::new_float(allocator, trimmed.to_double())!!;
	}

	return object::new_string(allocator, trimmed);
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
			out.set(key, scalar_object_from_text(allocator, val));
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
					out.set(decoded_key, scalar_object_from_text(allocator, decoded_val));
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

fn void encode_component(DString* out, String value) @private
{
	for (sz i = 0; i < value.len; i++)
	{
		char ch = value[i];
		if ((ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') || ch == '-' || ch == '_'
			|| ch == '.'
			|| ch == '~')
		{
			out.append(value[i..i]);
			continue;
		}

		if (ch == ' ')
		{
			out.append("+");
			continue;
		}

		out.appendfn("%%%02X", (uint)(ch & 0xff));
	}
}

fn void append_form_pair(DString* out, bool* first, String key, String value) @private
{
	if (!*first)
	{
		out.append("&");
	}
	else
	{
		*first = false;
	}

	encode_component(out, key);
	out.append("=");
	encode_component(out, value);
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

fn void? serialize_form_struct(DString* out, bool* first, String prefix, Type value)<Type>
{
	$foreach $member : Type::members:

		{
			$if $member.name != "":
				String key = prefix == "" ? $member.name : string::format(tmem, "%s.%s", prefix, $member.name);
				serialize_form_value{$member.type}(out, first, key, value.$member)!;
			$endif
		}
	$endforeach
}

fn void? serialize_form_value(DString* out, bool* first, String key, TypeElement value)<TypeElement>
{
	$if TypeElement == String:
		append_form_pair(out, first, key, value);
		return;
	$else
		$switch TypeElement::kind:
			$case STRUCT:
				serialize_form_struct{TypeElement}(out, first, key, value)!;
			$case SIGNED_INT:
			$case UNSIGNED_INT:
			$case FLOAT:
			$case BOOL:
			$case ENUM:
				append_form_pair(out, first, key, string::format(tmem, "%s", value));
			$case TYPEDEF:
			$case CONSTDEF:
				serialize_form_value{TypeElement::inner}(out, first, key, value)!;
			$case ARRAY:
			$case VECTOR:
			$case SLICE:
				foreach (item : value)
				{
					serialize_form_value{TypeElement::inner}(out, first, key, item)!;
				}
			$default:
				@compile_error("marshal_form: unsupported type");
		$endswitch
	$endif
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
