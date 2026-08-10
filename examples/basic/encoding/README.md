# Encoding Example

This example demonstrates request binding and response serialization for multiple encodings in c3-api.

The same `Product` structure can be received as JSON, XML, or form data and serialized back into the corresponding format. It also demonstrates binding and serialization of a nested `Supplier` structure.

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
- Nested struct binding and serialization.
- Form encoding of nested structures using dotted field names.

## Files

- `main.c3` - Example server with JSON, XML, and form request and response handlers.

## Run

```bash
c3c run encoding-demo
```

To test the endpoints using curl then use:

### JSON

```pwsh
'{ "name": "Mechanical Keyboard", "category": "electronics", "price": 89.99, "quantity": 2, "supplier": { "name": "Example Electronics", "email": "sales@example.com" } }' | curl.exe -v --http1.1 -X POST "http://127.0.0.1:8080/json" -H "Content-Type: application/json" -H "Transfer-Encoding: chunked" --data-binary "@-"
```

```bash
echo '{ "name": "Mechanical Keyboard", "category": "electronics", "price": 89.99, "quantity": 2, "supplier": { "name": "Example Electronics", "email": "sales@example.com" } }' | curl -v --http1.1 -X POST "http://127.0.0.1:8080/json" -H "Content-Type: application/json" -H "Transfer-Encoding: chunked" --data-binary @-
```

### XML

```pwsh
'<product><name>Mechanical Keyboard</name><category>electronics</category><price>89.99</price><quantity>2</quantity><supplier><name>Example Electronics</name><email>sales@example.com</email></supplier></product>' | curl.exe -v --http1.1 -X POST "http://127.0.0.1:8080/xml" -H "Content-Type: application/xml" -H "Transfer-Encoding: chunked" --data-binary "@-"
```

```bash
echo '<product><name>Mechanical Keyboard</name><category>electronics</category><price>89.99</price><quantity>2</quantity><supplier><name>Example Electronics</name><email>sales@example.com</email></supplier></product>' | curl -v --http1.1 -X POST "http://127.0.0.1:8080/xml" -H "Content-Type: application/xml" -H "Transfer-Encoding: chunked" --data-binary @-
```

### Form

```pwsh
'name=Mechanical+Keyboard&category=electronics&price=89.99&quantity=2&supplier%5Bname%5D=Example+Electronics&supplier%5Bemail%5D=sales%40example.com' | curl.exe -v --http1.1 -X POST "http://127.0.0.1:8080/form" -H "Content-Type: application/x-www-form-urlencoded" --data-binary "@-"
```

```bash
echo 'name=Mechanical+Keyboard&category=electronics&price=89.99&quantity=2&supplier%5Bname%5D=Example+Electronics&supplier%5Bemail%5D=sales%40example.com' | curl -v --http1.1 -X POST "http://127.0.0.1:8080/form" -H "Content-Type: application/x-www-form-urlencoded" --data-binary @-

```

## Example Data

All three requests represent the same product:

- Name: `Mechanical Keyboard`
- Category: `electronics`
- Price: `89.99`
- Quantity: `2`
- Supplier: `Example Electronics`
- Supplier email: `sales@example.com`

The encoding changes, but the request is bound to the same C3 Product structure.

## Response

Each successful request returns HTTP `201 Created` and a `ProductResponse` containing:

- A `message` field with the value `Product entered`.
- The submitted `Product`.
- The nested `Supplier`.
