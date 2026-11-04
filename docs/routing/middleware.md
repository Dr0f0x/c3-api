# Middleware

Middleware runs before and, optionally, after a route handler. Use it for
cross-cutting work such as authentication, request logging, CORS headers, or
loading shared data into the request context.

A middleware is a function with the `MiddlewareFunc` signature:

```c3
fn void request_logger(
    void* self = null,
    Allocator allocator,
    MiddlewareContext* ctx,
    HttpRequest* req,
    HttpResponse* res,
)
{
    io::printn("request started");

    ctx.next(allocator, req, res);

    io::printn("request finished");
}
```

`ctx.next(...)` continues the pipeline. Code before the call runs before the
remaining middleware and the handler; code after it runs once they return.

!!! warning "Always continue the pipeline"

    If a middleware returns without calling `ctx.next(...)`, the remaining
    middleware and the route handler do not run. This is how middleware
    short-circuits a request, for example to reject an unauthenticated client.

## Register middleware

Register middleware on a path prefix:

```c3
router.use("/admin", &request_logger);
```

This middleware runs for `/admin` and every path below it, such as
`/admin/users` and `/admin/settings`. Use `"/"` to apply it to every route:

```c3
router.use("/", &request_logger);
```

!!! warning "Match dynamic parameter names"

    Middleware registered on a dynamic path must use the same parameter name as
    the routes on that branch. Registering a conflicting name logs an error and
    aborts the program.

Middleware can also be scoped to a group. See [Groups](groups.md).

## Short-circuit a request

A middleware that writes a response and returns without calling `next` stops
the request:

```c3
fn void require_auth(
    void* self = null,
    Allocator allocator,
    MiddlewareContext* ctx,
    HttpRequest* req,
    HttpResponse* res,
)
{
    if (catch err = req.headers.get_header_values("Authorization"))
    {
        res.status = HttpStatus.UNAUTHORIZED;
        res.body = "Missing Authorization header";
        return;
    }

    ctx.next(allocator, req, res);
}
```

Register it on the routes that need protection:

```c3
router.use("/admin", &require_auth);
```

## Type method middleware

Like handlers, middleware can be a type method on a struct. The instance is
passed as `self`:

```c3
struct Auth
{
    String token;
}

fn void Auth.check(
    &self,
    Allocator allocator,
    MiddlewareContext* ctx,
    HttpRequest* req,
    HttpResponse* res,
)
{
    if (try values = req.headers.get_header_values("Authorization"))
    {
        if (values.len() > 0 && values[0] == self.token)
        {
            ctx.next(allocator, req, res);
            return;
        }
    }

    res.status = HttpStatus.FORBIDDEN;
    res.body = "Forbidden";
}
```

With the non-generic helper, cast the method to `MiddlewareFunc`:

```c3
Auth auth = { .token = "secret" };
router.use("/private", (MiddlewareFunc)&Auth.check, &auth);
```

The generic helper preserves the instance type and removes the cast:

```c3
router::use{Auth}(router, "/private", &Auth.check, &auth);
```

## Order and scope

Middleware is collected along the matched path. Root middleware runs first,
followed by middleware attached to deeper path segments, followed by the route
handler:

```c3
router.use("/", &root_middleware);
router.use("/api", &api_middleware);
router.use("/api/users", &user_middleware);

router.get("/api/users/{id}", &get_user);
```

For `GET /api/users/42`, the order is:

```text
root_middleware
  api_middleware
    user_middleware
      get_user
```

Multiple Middlewares registered for the same path run in registration order. The first `use` call runs first, and code after `ctx.next(...)` unwinds in reverse order:

```c3
router.use("/api", &first_middleware);
router.use("/api", &second_middleware);
```

For a request under `/api`, `first_middleware` runs before `second_middleware`,
and `second_middleware` resumes after `ctx.next(...)` before `first_middleware`
does.

Middleware registered for a path does not run for unrelated paths.
`/administrator` does not match middleware registered on `/admin`.

## Built-in middleware

The server registers request logging by default, but you can disable
it before starting the server:

```c3
server.use_builtin_logging_middleware(false);
server.run()!!;
```

The built-in CORS middleware is enabled through the server configuration. It
adds the configured `Access-Control-Allow-*` headers to `OPTIONS` requests. See
[CORS configuration](../configuration/cors.md).

## See also

- [Handlers](handlers.md) — handler signatures and type methods.
- [Groups](groups.md) — group routes under a shared prefix.
- [Context](../http/context.md) — share values across the request pipeline.
- [Logger](../logging/logger.md) — configure and use logging.
