# Path & Query Parameters

Route parameters and query parameters both arrive as strings. Path parameters
are part of the route pattern; query parameters come from the part of the URL
after `?`.

```c3
router.get("/users/{id}", &get_user);
router.get("/search", &search);
```

## Route matching

The router stores paths in a trie. Each path is split on `/`, and every segment
is matched independently. Literal segments match exactly and are
case-sensitive. The detailed rules are covered in
[Path parameter rules](#path-parameter-rules) and
[Query parameter rules](#query-parameter-rules).

If no route matches, the built-in 404 handler responds.

```json
{"type":"error","status":404}
```

## Path parameters

Wrap a path segment in braces to capture it:

```c3
router.get("/hello/{name}", &hello);
```

A handler can read the captured value from `req.params`:

```c3
fn void hello(
    void* self = null,
    Allocator allocator,
    HandlerContext* ctx,
    HttpRequest* req,
    HttpResponse* res,
)
{
    res.status = HttpStatus.OK;
    res.body = string::format(allocator, "Hello %s!", req.params["name"]!!);
}
```

`req.params["name"]` returns `String?`. The `!!` operator unwraps the optional
and faults if the key is missing. Since the route guarantees that the parameter
exists, unwrapping it is safe here.

!!! warning "Keep route and handler parameter names in sync"

    If the parameter name in the route and the name used to access it in the
    handler get out of sync, the lookup may fail and `!!` will fault. Make sure
    the `{name}` segment and the `req.params["name"]` lookup use the same name.


A route can contain several parameters:

```c3
router.get("/users/{user_id}/posts/{post_id}", &get_post);
```

```c3
res.body = string::format(
    allocator,
    "user %s, post %s",
    req.params["user_id"]!!,
    req.params["post_id"]!!
);
```

Each parameter in a route must have a different name. Registering the same
name twice is rejected at compile time:

```c3
router.get("/users/{user_id}/posts/{user_id}", &get_post);
```

```text
error: @require "!internal::has_duplicate_path_params($uri)" violated: 'Route contains duplicate path parameter names'.
```

### Path parameter rules

- A parameter matches exactly one segment. `/users/{id}` matches
  `/users/42`, but not `/users/42/posts`.
- A parameter does not match an empty segment. `/users/{id}` does not match
  `/users/`.
- There is no catch-all syntax. Use a fixed number of segments or read the
  remaining path from another source.
- Literal routes take precedence over parameter routes. With `/users/me` and
  `/users/{id}` registered, `GET /users/me` uses the literal handler.
- There is one dynamic branch per trie level. Registering `/users/{id}` and
  then `/users/{name}` is an error: the router logs it and aborts instead
  of registering the second route.
- Parameter names must be unique within a route. Duplicate names are rejected
  at compile time.
- Parameter values are stored as received. Percent-encoding is not decoded
  automatically.

## Query parameters

The query string is parsed from the request URI and exposed through
`req.query`. Every lookup returns `String?`.

!!! warning "Never unwrap a query parameter"

    Do not use `!!` on `req.query` values, even when a parameter is functionally required:
    a missing value faults and terminates the server. Bind the optional with
    `try` and handle the missing branch instead.

    This rule applies only to query parameters. Path parameters are guaranteed
    by the matched route, so `req.params["name"]!!` is safe there.

```c3
router.get("/search", &search);

fn void search(
    void* self = null,
    Allocator allocator,
    HandlerContext* ctx,
    HttpRequest* req,
    HttpResponse* res,
)
{
    if (try q = req.query["q"])
    {
        String page = req.query["page"] ?? "1";

        res.status = HttpStatus.OK;
        res.body = string::format(
            allocator,
            "Searching for '%s' on page %s",
            q,
            page
        );
    }
    else
    {
        res.status = HttpStatus.BAD_REQUEST;
        res.body = "Missing q parameter";
    }
}
```

A request to `/search?q=c3&page=2` produces:

```text
Searching for 'c3' on page 2
```

A request without `q` returns `400 Bad Request`.

### Multiple required query parameters

Bind each value to a separate optional, then check them together:

```c3
String? q = req.query["q"];
String? page = req.query["page"];

if (try q && try page)
{
    // Both q and page are valid here.
}
else
{
    res.status = HttpStatus.BAD_REQUEST;
    res.body = "Missing q or page parameter";
}
```

`try` checks presence, not content. A request with `?q=` produces an empty
string, which still passes. Add a length check when an empty value should be
rejected as well:

```c3
if (try q = req.query["q"] && q.len > 0)
{
    // q is non-empty.
}
```

### Query parameter rules

- Pairs are separated by `&` and must use the `name=value` form.
- The parser trims leading and trailing whitespace around keys and values.
- An empty value is allowed: `?q=` yields an empty string.
- If a key appears more than once, the last value is kept.
- Values are stored as received. Percent-encoding and `+` are not decoded
  automatically.
- The query string does not participate in route matching. `/search?q=c3` and
  `/search` use the same route.

## See also

- [HTTP methods](http_methods.md) — method registration and HEAD, OPTIONS, and
  TRACE behavior.
- [Handlers](handlers.md) — handler signatures and type methods.
- [Request](../http/request.md) — inspect headers, body, and other request data.
- [Struct binding](../http/encoding/binding.md) — bind request data into C3
  types.
