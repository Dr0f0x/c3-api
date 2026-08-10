# Minimal Quickstart Example

This is the smallest complete c3-api setup with one dynamic route.

- Creates and initializes a `c3api::Server`.
- Registers `GET /test` on the router.
- Starts the HTTP server and prints registered routes.

## Files

- `main.c3` - Minimal server setup, route handler, and route registration.

## Run

From the project root:

```bash
c3c run minimal-demo
```

Then open `http://127.0.0.1:8080/test`.
