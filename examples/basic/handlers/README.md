# Handlers Example

This example demonstrates function-based and type-method route handlers in c3-api.

- Registers a stateless function handler for `/test`.
- Registers a stateful type-method handler for `/counter` using an instance pointer.
- Shows cast-based registration with `router.get(...)` for type methods.
- Shows type-safe generic registration with `router::get{T}(...)` without manual casts.
- Includes equivalent generic routes: `/generic` and `/generic-counter`.

## Files

- `main.c3` - Server setup, handler definitions, and route registration patterns.

## Run

From the project root:

```bash
c3c run handler-demo
```

Then open `http://127.0.0.1:8080/` and test:

- `/test`
- `/counter` (increments on each request)
- `/generic`
- `/generic-counter` (increments on each request)

