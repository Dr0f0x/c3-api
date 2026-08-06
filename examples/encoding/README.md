# Encoding Example

This example is intended to demonstrate request binding and response serialization for multiple encodings in c3-api.

- Request binding APIs:
	- `request::from_json{Type}(...)`
	- `request::from_xml{Type}(...)`
	- `request::from_form{Type}(...)` (body and query params)
- Response serialization APIs:
	- `response::as_text(...)`
	- `response::as_json{Type}(...)`
	- `response::as_xml{Type}(...)`
	- `response::as_form{Type}(...)`
- Uses tag-based field mapping via `@Json`, `@Xml`, and `@Form`.

## Files

- `main.c3` - Example server and endpoints for JSON/XML/form request and response handling.

## Run

```bash
c3c run encoding-demo
```