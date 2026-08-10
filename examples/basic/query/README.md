# Query Example

This example demonstrates query parameter parsing and access in c3-api.

- Registers a route with a single query parameter using `/test?name={name}`.
- Accesses query parameters through `req.query`.
- Registers a route with multiple query parameters using `/search?query={query}&page={page}`.
- Accesses multiple query parameters from the request.
- Handles missing query parameters.

## Files

- `main.c3` - Server setup, query parameter handlers, and route registration.

## Run

From the project root:

```bash
c3c run query-demo
```

Then open `http://127.0.0.1:8080/` and test:

- `/test?name=charlie`
- `/test`
- `/search?query=c3-api&page=2`
- `/search`
