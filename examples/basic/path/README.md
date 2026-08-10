# Path Example

This example demonstrates path parameter extraction in c3-api.

- Registers a route with a single path parameter using `/test/{name}`.
- Accesses path parameters through `req.params`.
- Registers a route with multiple path parameters using `/test/{name}/{id}`.
- Accesses multiple path parameters from the request.

## Files

- `main.c3` - Server setup, path parameter handlers, and route registration.

## Run

From the project root:

```bash
c3c run path-demo
```

Then open `http://127.0.0.1:8080/` and access:

- `/test/charlie`
- `/test/charlie/12`
