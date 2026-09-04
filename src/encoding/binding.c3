// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module c3api::encoding;

import std::io;
import std::collections::object;
import std::encoding::json;
import c3api::encoding::form;
import c3api::encoding::xml;
import c3api::http::params;

<*
 Configure a struct member's JSON field name and required status.
*>
attrdef @Json(String field_name, bool required) = @tag("json", field_name), @tag("json_required", required);
<*
 Configure a struct member's form field name and required status.
*>
attrdef @Form(String field_name, bool required) = @tag("form", field_name), @tag("form_required", required);
<*
 Configure a struct member's XML field name and required status.
*>
attrdef @Xml(String field_name, bool required) = @tag("xml", field_name), @tag("xml_required", required);

<*
 Faults raised while binding JSON, form, or XML values.
*>
faultdef JSON_MALFORMED, JSON_MISSING_FIELD;
<*
 Faults raised while binding form values.
*>
faultdef FORM_MALFORMED, FORM_MISSING_FIELD;
<*
 Faults raised while binding XML values.
*>
faultdef XML_MALFORMED, XML_MISSING_FIELD;

<*
 Bind JSON bytes into a typed struct.

 @param allocator : "Allocator used for temporary objects"
 @param value : "Struct value to populate"
 @param bytes : "JSON document bytes"
 @require @kindof(*value) == STRUCT
 @require json::may_serialize($Typeof(*value)) : "Expected a serializable type"
 @return "Success or a JSON binding error"
*>
fn void? bind_json(Allocator allocator, Type* value, char[] bytes)<Type>
{
	Object*? json = json::tparse((String)bytes[..]);

	if (catch err = json)
	{
		return JSON_MALFORMED~;
	}

	bind_json_object{Type}(allocator, value, json)!;
}

<*
 Bind a parsed JSON object into a typed struct.

 @param allocator : "Allocator used for temporary objects"
 @param value : "Struct value to populate"
 @param json : "Parsed JSON object"
 @require @kindof(*value) == STRUCT
 @require json::may_serialize($Typeof(*value)) : "Expected a serializable type"
 @return "Success or a JSON binding error"
*>
fn void? bind_json_object(Allocator allocator, Type* value, Object* json)<Type> @private
{
	String key;
	bool required;

	$foreach $member : Type::members:

		{
			$if $member.name != "":
				$if $member.has_tag("json"):
					var $json_tag = $member.get_tag("json");

					// @Json("-") explicitly excludes this member.
					$if $json_tag != "-":
						bind_json_field{Type}($member, json, allocator, value, $json_tag)!;
					$endif
				$else
					// No @Json tag: use the C3 member name.
					bind_json_field{Type}($member, json, allocator, value, $member.name)!;
				$endif
			$endif
		}
	$endforeach
}

<*
 Bind one JSON field into a struct member.

 @param member : "Compile-time member metadata"
 @param json : "Parsed JSON object"
 @param allocator : "Allocator used for temporary objects"
 @param value : "Struct value to populate"
 @param key : "JSON field name"
 @return "Success or a JSON binding error"
*>
macro void? bind_json_field($member, Object* json, Allocator allocator, Type* value, String key) <Type> @private
{
	bool required = false;

	$if $member.has_tag("json_required"):
		var $required_tag = $member.get_tag("json_required");
		required = $required_tag;
	$endif

	Object*? field_obj = json.get(key);

	if (catch err = field_obj)
	{
		if (required)
		{
			return JSON_MISSING_FIELD~;
		}
	}
	else
	{
		$if is_struct($member.type):
			bind_json_object{$member.type}(allocator, &value.$member, field_obj)!;
		$else
			value.$member = field_obj.to_value($member.type, false)!;
		$endif
	}
}

<*
 Bind XML bytes into a typed struct.

 @param allocator : "Allocator used for temporary objects"
 @param value : "Struct value to populate"
 @param bytes : "XML document bytes"
 @require @kindof(*value) == STRUCT
 @require xml::may_serialize($Typeof(*value)) : "Expected a serializable type"
 @return "Success or an XML binding error"
*>
fn void? bind_xml(Allocator allocator, Type* value, char[] bytes)<Type>
{
	Object*? xml_obj = xml::tparse((String)bytes[..]);

	if (catch err = xml_obj)
	{
		return XML_MALFORMED~;
	}

	bind_xml_object(allocator, value, xml_obj)!;
}

<*
 Bind a parsed XML object into a typed struct.

 @param allocator : "Allocator used for temporary objects"
 @param value : "Struct value to populate"
 @param xml_obj : "Parsed XML object"
 @require @kindof(*value) == STRUCT
 @require xml::may_serialize($Typeof(*value)) : "Expected a serializable type"
 @return "Success or an XML binding error"
*>
fn void? bind_xml_object(Allocator allocator, Type* value, Object* xml_obj)<Type> @private
{
	String key;
	bool required;

	$foreach $member : Type::members:

		{
			$if $member.name != "":
				$if $member.has_tag("xml"):
					var $xml_tag = $member.get_tag("xml");

					// @Xml("-") explicitly excludes this member.
					$if $xml_tag != "-":
						bind_xml_field{Type}($member, xml_obj, allocator, value, $xml_tag)!;
					$endif
				$else
					// No @Xml tag: use the C3 member name.
					bind_xml_field{Type}($member, xml_obj, allocator, value, $member.name)!;
				$endif
			$endif
		}
	$endforeach
}

<*
 Bind one XML field into a struct member.

 @param member : "Compile-time member metadata"
 @param xml_obj : "Parsed XML object"
 @param allocator : "Allocator used for temporary objects"
 @param value : "Struct value to populate"
 @param key : "XML field name"
 @return "Success or an XML binding error"
*>
macro void? bind_xml_field($member, Object* xml_obj, Allocator allocator, Type* value, String key) <Type> @private
{
	bool required = false;

	$if $member.has_tag("xml_required"):
		var $required_tag = $member.get_tag("xml_required");
		required = $required_tag;
	$endif

	Object*? field_obj = xml_obj.get(key);

	if (catch err = field_obj)
	{
		if (required)
		{
			return XML_MISSING_FIELD~;
		}
	}
	else
	{
		$if is_struct($member.type):
			bind_xml_object{$member.type}(allocator, &value.$member, field_obj)!;
		$else
			value.$member = field_obj.to_value($member.type, false)!;
		$endif
	}
}

<*
 Bind form bytes into a typed struct.

 @param allocator : "Allocator used for temporary objects"
 @param value : "Struct value to populate"
 @param bytes : "Form-encoded document bytes"
 @require @kindof(*value) == STRUCT
 @require form::may_serialize($Typeof(*value)) : "Expected a serializable type"
 @return "Success or a form binding error"
*>
fn void? bind_form(Allocator allocator, Type* value, char[] bytes)<Type>
{
	Object*? form_obj = form::tparse((String)bytes[..]);

	if (catch err = form_obj)
	{
		return FORM_MALFORMED~;
	}

	bind_form_object(allocator, value, form_obj)!;
}

<*
 Bind query parameters into a typed struct.

 @param allocator : "Allocator used for temporary objects"
 @param value : "Struct value to populate"
 @param query : "Query parameter collection"
 @require @kindof(*value) == STRUCT
 @require form::may_serialize($Typeof(*value)) : "Expected a serializable type"
 @return "Success or a form binding error"
*>
fn void? bind_form_query_params(Allocator allocator, Type* value, HttpQueryParams* query)<Type>
{
	Object*? form_obj = form::parse_query_params(allocator, query);

	if (catch err = form_obj)
	{
		return FORM_MALFORMED~;
	}

	bind_form_object(allocator, value, form_obj)!;
}

<*
 Bind a parsed form object into a typed struct.

 @param allocator : "Allocator used for temporary objects"
 @param value : "Struct value to populate"
 @param form_obj : "Parsed form object"
 @require @kindof(*value) == STRUCT
 @require form::may_serialize($Typeof(*value)) : "Expected a serializable type"
 @return "Success or a form binding error"
*>
fn void? bind_form_object(Allocator allocator, Type* value, Object* form_obj)<Type> @private
{
	String key;
	bool required;

	$foreach $member : Type::members:

		{
			$if $member.name != "":
				$if $member.has_tag("form"):
					var $form_tag = $member.get_tag("form");

					// @Form("-") explicitly excludes this member.
					$if $form_tag != "-":
						bind_form_field{Type}($member, form_obj, allocator, value, $form_tag)!;
					$endif
				$else
					// No @Form tag: use the C3 member name.
					bind_form_field{Type}($member, form_obj, allocator, value, $member.name)!;
				$endif
			$endif
		}
	$endforeach
}

<*
 Bind one form field into a struct member.

 @param member : "Compile-time member metadata"
 @param form_obj : "Parsed form object"
 @param allocator : "Allocator used for temporary objects"
 @param value : "Struct value to populate"
 @param key : "Form field name"
 @return "Success or a form binding error"
*>
macro void? bind_form_field($member, Object* form_obj, Allocator allocator, Type* value, String key) <Type> @private
{
	bool required = false;

	$if $member.has_tag("form_required"):
		var $required_tag = $member.get_tag("form_required");
		required = $required_tag;
	$endif

	Object*? field_obj = form_obj.get(key);

	if (catch err = field_obj)
	{
		if (required)
		{
			return FORM_MISSING_FIELD~;
		}
	}
	else
	{
		$if is_struct($member.type):
			bind_form_object{$member.type}(allocator, &value.$member, field_obj)!;
		$else
			value.$member = field_obj.to_value($member.type, false)!;
		$endif
	}
}

<*
 Check whether a compile-time type is a struct.

 @return "True when the type is a struct"
*>
macro bool is_struct($Type) @const @private
{
	return $Type::kind == STRUCT;
}