# Groups

A group is a view over a path prefix. Routes registered on a group are
relative to that prefix, and middleware registered on the group applies to the
whole group.

```c3
router.get("/api/v1/users", &list_users);
router.get("/api/v1/users/{id}", &get_user);
router.post("/api/v1/users", &create_user);
```

Groups keep the same routes without repeating the prefix:

```c3
group::Group* api = router.group(tmem, "/api/v1");

api.get("/users", &list_users);
api.get("/users/{id}", &get_user);
api.post("/users", &create_user);
```

The resulting paths are still `/api/v1/users` and
`/api/v1/users/{id}`.

## Create a group

Create a group from the router and register routes on it:

```c3
module main;

import c3api;
import c3api::routing;
import c3api::routing::router;
import c3api::routing::group;

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

fn void get_user(
    void* self = null,
    Allocator allocator,
    HandlerContext* ctx,
    HttpRequest* req,
    HttpResponse* res,
)
{
    res.status = HttpStatus.OK;
    res.body = string::format(allocator, "user %s", req.params["id"]!!);
}

fn int main(String[] args)
{
    c3api::Server server;
    server.init(tmem)!!;

    router::Router* router = server.get_router();

    group::Group* api = router.group(tmem, "/api/v1");
    api.get("/users", &list_users);
    api.get("/users/{id}", &get_user);

    routing::print_routes(router);
    server.run()!!;

    return 0;
}
```

The group path must not be empty or `/`. A group is always relative to a
non-root path.

## Nested groups

Groups can contain other groups. Paths are resolved relative to the parent
group:

```c3
group::Group* api = router.group(tmem, "/api/v1");
group::Group* users = api.group(tmem, "/users");

users.get("/{id}", &get_user);
```

This registers `GET /api/v1/users/{id}`. Nested groups are useful for
splitting a large API into modules while keeping each module's paths short.

## Middleware and routes

Groups support all the route and middleware registration methods and macro
helpers the router has; the only difference is that the group prefix is
prepended to the path passed when registering:

```c3
group::Group* api = router.group(tmem, "/api/v1");

api.use("/", &api_middleware);
api.get("/users", &list_users);
group::get{Counter}(api, "/counter", &Counter.handle, &counter);
```

Middleware registered with `use("/")` applies to every route in the group,
including routes added later, and nested groups inherit it. See
[Middleware](middleware.md) for ordering and short-circuiting.

## Group lifetime

The group wrapper is only needed while registering routes. The routes
themselves are stored in the router, so creating groups in a temporary pool
is perfectly valid:

```c3
@pool()
{
    group::Group* api = router.group(tmem, "/api/v1");
    api.get("/users", &list_users);
};
```

The registered routes remain available after the pool ends. Keep any handler or
middleware instances alive for as long as their routes can be served.

## See also

- [HTTP methods](http_methods.md) — method registration and HEAD, OPTIONS, and
  TRACE behavior.
- [Handlers](handlers.md) — handler signatures and type methods.
- [Middleware](middleware.md) — ordering, short-circuiting, and built-ins.
- [Static files](static_files.md) — serve files from a router.
