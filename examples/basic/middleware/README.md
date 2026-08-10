# Middleware Example

This example demonstrates pure function and type-method middleware in c3-api.

- Registers a stateless middleware for `/test` that adds a custom `X-Middleware` response header.
- Registers a stateful type-method middleware that maintains a request counter.
- Stores the current counter value in the request context for the route handler.
- Shows cast-based registration with `router.use(...)` for type-method middleware.
- Shows type-safe generic registration with `router::use{T}(...)` without manual casts.

## Files

- `main.c3` - Server setup, middleware definitions, handler, and middleware registration patterns.

## Run

From the project root:

```bash
c3c run middleware-demo
```

Then open `http://127.0.0.1:8080/` and test:

- `/test`
- `/generic`
