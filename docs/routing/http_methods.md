# HTTP Methods

A route is a pair of an HTTP method and a path. The server owns a router, and
you register handlers on that router before calling `server.run()`.

```c3
module main;

import c3api;
import c3api::routing;
import c3api::routing::router;

fn void list_users(
    void* self = null,
    Allocator allocator,
    HandlerContext* ctx,
    HttpRequest* req,
    HttpResponse* res,
)
{
    res.status = HttpStatus.OK;
    res.body = "[]";
}

fn void create_user(
    void* self = null,
    Allocator allocator,
    HandlerContext* ctx,
    HttpRequest* req,
    HttpResponse* res,
)
{
    res.status = HttpStatus.CREATED;
}

fn int main(String[] args)
{
    c3api::Server server;
    server.init(tmem)!!;

    router::Router* router = server.get_router();

    router.get("/users", &list_users);
    router.post("/users", &create_user);

    routing::print_routes(router);
    server.run()!!;

    return 0;
}
```

The router supports all common HTTP methods through builtin-in macros:

| Registration | `RouteMethod` | Common use |
| --- | --- | --- |
| `router.get(...)` | `RouteMethod.GET` | Read a resource |
| `router.post(...)` | `RouteMethod.POST` | Create a resource |
| `router.put(...)` | `RouteMethod.PUT` | Replace a resource |
| `router.patch(...)` | `RouteMethod.PATCH` | Update part of a resource |
| `router.delete(...)` | `RouteMethod.DELETE` | Delete a resource |
| `router.head(...)` | `RouteMethod.HEAD` | Return headers without a body |

Each helper is a shortcut for `router.add_route(...)`. Use `add_route` when
the method is selected at runtime:

```c3
router.add_route(RouteMethod.PATCH, "/users/{id}", &update_user);
```

Route patterns have to be compile-time values as `add_route` and the method helpers
use a Precondition to reject patterns that repeat a parameter name, such as
`/path/{name}/test/{name}`, during compilation. Registering the same path shape twice,
but with a different parameter name at runtime logs an error and aborts.

`add_route` and the method helpers return `true` when they replaced an existing
handler for the same method and path, and `false` when they added a new one.

```c3
if (router.get("/health", &health))
{
    // A GET /health handler already existed and was replaced.
}
```

## HEAD requests

A registered `HEAD` handler takes precedence for `HEAD` requests to that path.
If none exists, the router falls back to the matching `GET` handler, and the
server strips the response body before sending it.

```c3
router.get("/articles/{id}", &get_article);
// HEAD /articles/42 runs get_article, then drops the body.
```

!!! note "HEAD responses never include a body"

    The server always removes the response body from HEAD responses before sending
    them to the client, even if a registered HEAD handler sets one.

If no matching `GET` or `HEAD` handler is found, the server responds with the
built-in 404 handler:

```json
{"type":"error","status":404}
```

## OPTIONS requests

`OPTIONS` is handled by the server, not by a route handler. When the path
exists, the server runs the matching middleware chain and responds with
`204 No Content` and an `Allow` header that includes `HEAD`, `OPTIONS`, and the
methods registered for that path.

```text
Allow: HEAD, OPTIONS, GET, POST
```

If the path does not exist, the built-in 404 response is returned.

## TRACE requests

`TRACE` is handled by the server before routing, not by a route handler. It is
disabled by default and must be enabled with `http.trace_enabled` in
`c3api.conf.json` (or the corresponding `Config` field):

```json
{
  "http": {
    "trace_enabled": true
  }
}
```
!!! warning "TRACE can expose sensitive information"

    `TRACE` is disabled by default because it can echo sensitive request headers, such as cookies and `Authorization`, back to the caller. It has historically been abused in Cross-Site Tracing (XST) attacks. Enable it only for controlled debugging on trusted networks, and disable it again when debugging is complete.

When enabled, the server responds with `200 OK` and a body that echoes the
request line, headers, and body. This is useful for diagnosing how a proxy or
client modified a request in transit. When disabled, `TRACE` requests receive
`405 Method Not Allowed`, and the connection is closed.

## Inspecting registered routes

The macro `routing::print_routes(router)` prints the route trie to standard output,
including every registered method and nested path. Call it after registering all
routes and before `server.run()` to confirm the final route table before the
server starts accepting traffic:

```c3
routing::print_routes(router);
```

## See also

- [Handlers](handlers.md) — handler signatures and type methods.
- [Path & query parameters](parameters.md) — route matching, path parameters,
  and query parameters.
- [Middleware](middleware.md) — ordering, short-circuiting, and built-ins.
- [Groups](groups.md) — group routes under a shared prefix.
