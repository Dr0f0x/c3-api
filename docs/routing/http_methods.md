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

The router supports the following methods:

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

`add_route` and the method helpers return `true` when they replaced an existing
handler for the same method and path, and `false` when they added a new one.
This makes it possible to replace a route during setup without registering it
twice:

```c3
if (router.get("/health", &health))
{
    // A GET /health handler already existed and was replaced.
}
```

## Route matching

The router stores paths in a trie. Each path is split on `/`, and every segment
is matched independently:

- Literal segments match exactly. Matching is case-sensitive.
- A segment such as `{id}` matches one path segment.
- An exact child is preferred over a dynamic child. With both `/users/me` and
  `/users/{id}` registered, `GET /users/me` uses the literal route.
- A dynamic segment does not match across `/`. `/users/{id}` matches
  `/users/42`, but not `/users/42/posts`.
- There is one dynamic branch per trie level. Routes such as `/users/{id}` and
  `/users/{name}` share that branch, so keep the parameter name consistent.
- The query string is removed before routing. `/search?q=c3` is routed as
  `/search`.
- There is no catch-all or wildcard segment.

If no route matches, the server responds with the built-in 404 handler:

```json
{"type":"error","status":404}
```

## HEAD requests

If you register a `HEAD` handler, it is used for `HEAD` requests. Otherwise the
router falls back to the matching `GET` handler and the server removes the
response body before sending it. This lets clients inspect headers without
downloading the resource.

```c3
router.get("/articles/{id}", &get_article);
// HEAD /articles/42 runs get_article, then drops the body.
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

## Inspecting registered routes

`routing::print_routes(router)` prints the route trie, including methods and
nested paths. Call it after registration and before `server.run()`:

```c3
routing::print_routes(router);
```

## See also

- [Handlers](handlers.md) — handler signatures and stateful handlers.
- [Path & query parameters](parameters.md) — read values from the URL.
- [Middleware](middleware.md) — run code before and after handlers.
- [Groups](groups.md) — share prefixes across routes.
