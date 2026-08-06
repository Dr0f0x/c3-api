module c3api::encoding;

import std::io;
import std::collections::object;
import std::encoding::json;
import c3api::encoding::form;
import c3api::encoding::xml;
import c3api::http::params;

attrdef @Json(String field_name, bool required) = @tag("json", field_name), @tag("json_required", required);
attrdef @Form(String field_name, bool required) = @tag("form", field_name), @tag("form_required", required);
attrdef @Xml(String field_name, bool required) = @tag("xml", field_name), @tag("xml_required", required);

faultdef JSON_MALFORMED, JSON_MISSING_FIELD;
faultdef FORM_MALFORMED, FORM_MISSING_FIELD;
faultdef XML_MALFORMED, XML_MISSING_FIELD;

<*
 @require @kindof(*value) == STRUCT
 @require json::may_serialize($Typeof(*value)) : "Expected a serializable type"
*>
fn void? bind_json(
	Allocator allocator,
	Type* value,
	char[] bytes,
)<Type>
{
	Object*? json = json::tparse((String)bytes[..]);

	if (catch err = json)
	{
		return JSON_MALFORMED~;
	}

	String key;
	bool required;
	$foreach $member : Type::members:

		{
			$if $member.name != "" && $member.has_tag("json"):
				required = false;

				var $json_tag = $member.get_tag("json");
				key = $json_tag;

				$if $member.has_tag("json_required"):
					var $required_tag = $member.get_tag("json_required");
					required = $required_tag;
				$endif

				Object*? field_obj = json.get(key);
				if (required)
				{
					if (catch err = field_obj)
					{
						return JSON_MISSING_FIELD~;
					}
					else
					{
						value.$member = field_obj.to_value($member.type)!;
					}
				}
				else
				{
					if (try field_obj)
					{
						value.$member = field_obj.to_value($member.type)!;
					}
				}
			$endif
		}
	$endforeach
}

fn void? bind_xml(
	Allocator allocator,
	Type* value,
	char[] bytes,
)<Type>
{
	Object*? xml_obj = xml::tparse((String)bytes[..]);

	if (catch err = xml_obj)
	{
		return XML_MALFORMED~;
	}

	String key;
	bool required;
	$foreach $member : Type::members:

		{
			$if $member.name != "" && $member.has_tag("xml"):
				required = false;

				var $xml_tag = $member.get_tag("xml");
				key = $xml_tag;

				$if $member.has_tag("xml_required"):
					var $required_tag = $member.get_tag("xml_required");
					required = $required_tag;
				$endif

				Object*? field_obj = xml_obj.get(key);
				if (required)
				{
					if (catch err = field_obj)
					{
						return XML_MISSING_FIELD~;
					}
					else
					{
						value.$member = field_obj.to_value($member.type, false)!;
					}
				}
				else
				{
					if (try field_obj)
					{
						value.$member = field_obj.to_value($member.type, false)!;
					}
				}
			$endif
		}
	$endforeach
}

<*
 @require @kindof(*value) == STRUCT
 @require form::may_serialize($Typeof(*value)) : "Expected a serializable type"
*>
fn void? bind_form(
	Allocator allocator,
	Type* value,
	char[] bytes,
)<Type>
{
	Object*? form_obj = form::tparse((String)bytes[..]);

	if (catch err = form_obj)
	{
		return FORM_MALFORMED~;
	}

	String key;
	bool required;
	$foreach $member : Type::members:

		{
			$if $member.name != "" && $member.has_tag("form"):
				required = false;

				var $form_tag = $member.get_tag("form");
				key = $form_tag;

				$if $member.has_tag("form_required"):
					var $required_tag = $member.get_tag("form_required");
					required = $required_tag;
				$endif

				Object*? field_obj = form_obj.get(key);
				if (required)
				{
					if (catch err = field_obj)
					{
						return FORM_MISSING_FIELD~;
					}
					else
					{
						value.$member = field_obj.to_value($member.type)!;
					}
				}
				else
				{
					if (try field_obj)
					{
						value.$member = field_obj.to_value($member.type)!;
					}
				}
			$endif
		}
	$endforeach
}

<*
 @require @kindof(*value) == STRUCT
 @require form::may_serialize($Typeof(*value)) : "Expected a serializable type"
*>
fn void? bind_form_query_params(
	Allocator allocator,
	Type* value,
	params::HttpQueryParams* query,
)<Type>
{
	Object*? form_obj = form::parse_query_params(allocator, query);

	if (catch err = form_obj)
	{
		return FORM_MALFORMED~;
	}

	String key;
	bool required;
	$foreach $member : Type::members:

		{
			$if $member.name != "" && $member.has_tag("form"):
				required = false;

				var $form_tag = $member.get_tag("form");
				key = $form_tag;

				$if $member.has_tag("form_required"):
					var $required_tag = $member.get_tag("form_required");
					required = $required_tag;
				$endif

				Object*? field_obj = form_obj.get(key);
				if (required)
				{
					if (catch err = field_obj)
					{
						return FORM_MISSING_FIELD~;
					}
					else
					{
						value.$member = field_obj.to_value($member.type)!;
					}
				}
				else
				{
					if (try field_obj)
					{
						value.$member = field_obj.to_value($member.type)!;
					}
				}
			$endif
		}
	$endforeach
}
