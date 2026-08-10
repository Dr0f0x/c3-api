This example demonstrates route groups and nested groups in c3-api.

- Creates a route group for `/api/v1`.
- Registers middleware for the `/api/v1` group.
- Registers a route relative to the `/api/v1` group.
- Creates a nested `/users` group relative to `/api/v1`.
- Registers additional middleware for the `/api/v1/users` subgroup.
- Registers a route relative to the nested `/api/v1/users` group.
- Demonstrates how middleware can be scoped to different levels of nested groups.

## Files

- `main.c3` - Server setup, route groups, group middleware, and route registration.

## Run

From the project root:

```bash
c3c run groups-demo
```

Then open `http://127.0.0.1:8080/` and test:

- `/api/v1/test`
- `/api/v1/users/test`

The `/api/v1/test` route uses the `/api/v1` middleware.

The `/api/v1/users/test` route uses both the `/api/v1` middleware and the `/api/v1/users` middleware.

The middleware prints a message to the console when it is executed, allowing the middleware execution order to be observed while sending requests.
