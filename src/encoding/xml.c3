module c3api::encoding::xml;

import std::encoding::xml;
import std::io;
import std::collections::object;

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

fn Object* xml_node_to_object(Allocator allocator, XmlNode* node) @private
{
	Object* out = object::new_obj(allocator);

	foreach (XmlNode* child : node.children)
	{
		if (child.kind != XmlEventKind.START_ELEMENT) continue;

		bool has_struct_children = false;
		foreach (XmlNode* grandchild : child.children)
		{
			if (grandchild.kind == XmlEventKind.START_ELEMENT)
			{
				has_struct_children = true;
				break;
			}
		}

		Object* value;
		if (has_struct_children)
		{
			value = xml_node_to_object(allocator, child);
		}
		else
		{
			String text = child.text() ?? "";
			value = scalar_object_from_text(allocator, text);
		}

		out.set(child.name, value);
	}

	return out;
}

fn Object*? parse(Allocator allocator, String value)
{
	XmlDocument* doc = std::encoding::xml::parse(allocator, value)!;
	defer doc.free();

	if (!doc.root || doc.root.kind != XmlEventKind.START_ELEMENT)
	{
		return object::new_obj(allocator);
	}

	return xml_node_to_object(allocator, doc.root);
}

fn Object*? tparse(String value)
{
	return parse(tmem, value);
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


<*
 Marshal a struct with primitive fields and nested structs to XML.

 @param allocator : "The allocator to use for the result"
 @param value : "The struct value to marshal"
 @param root : "Root element name"
 @require @kindof(value) == STRUCT
 @require xml::may_serialize($Typeof(value)) : "Expected a serializable type"
 @return "The XML string representation"
*>
macro String marshal_xml(Allocator allocator, value, String root = "response") => @pool()
{
	DString s;
	s.tinit();
	marshal_xml_to(&s, value, root)!!;
	return s.copy_str(allocator);
}

<*
 Marshal a struct with primitive fields and nested structs to XML.

 @param stream : "The stream to serialize to"
 @param value : "The struct value to marshal"
 @param root : "Root element name"
 @require @kindof(value) == STRUCT
 @require xml::may_serialize($Typeof(value)) : "Expected a serializable type"
*>
macro void? marshal_xml_to(OutStream stream, value, String root = "response")
{
	xml::XmlSerializer serializer;
	serializer.init(stream);
	serializer.start_doc()!;
	serialize_xml_struct{$Typeof(value)}(&serializer, root, value)!;
	serializer.end_doc()!;
}

fn void? serialize_xml_struct(xml::XmlSerializer* serializer, String name, Type value)<Type>
{
	serializer.start_element(name)!;

	$foreach $member : Type::members:
		$if $member.name != "":
			$if $member.has_tag("xml"):
				$if $member.get_tag("xml") != "-":
					serialize_xml_value{$member.type}(serializer, $member.get_tag("xml"), value.$member)!;
				$endif
			$else
				serialize_xml_value{$member.type}(serializer, $member.name, value.$member)!;
			$endif
		$endif
	$endforeach

	serializer.end_element(name)!;
}

fn void? serialize_xml_value(xml::XmlSerializer* serializer, String name, TypeElement value)<TypeElement>
{
	$if TypeElement == String:
		serializer.start_element(name)!;
		serializer.add_content(value)!;
		serializer.end_element(name)!;
		return;
	$else
		$switch TypeElement::kind:
			$case STRUCT:
				serialize_xml_struct{TypeElement}(serializer, name, value)!;
			$case SIGNED_INT:
			$case UNSIGNED_INT:
			$case FLOAT:
			$case BOOL:
			$case ENUM:
				serializer.start_element(name)!;
				serializer.add_content(string::format(tmem, "%s", value))!;
				serializer.end_element(name)!;
			$case TYPEDEF:
			$case CONSTDEF:
				serialize_xml_value{TypeElement::inner}(serializer, name, value)!;
			$case ARRAY:
			$case VECTOR:
			$case SLICE:
				foreach (item : value)
				{
					serialize_xml_value{TypeElement::inner}(serializer, name, item)!;
				}
			$default:
				@compile_error("marshal_xml: unsupported type");
		$endswitch
	$endif
}