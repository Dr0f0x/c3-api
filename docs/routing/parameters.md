# Path & Query Parameters

Route parameters and query parameters both arrive as strings. Path parameters
are part of the route pattern; query parameters come from the part of the URL
after `?`.

```c3
router.get("/users/{id}", &get_user);
router.get("/search", &search);
```

## Path parameters

Wrap a path segment in braces to capture it:

```c3
router.get("/hello/{name}", &hello);
```

The handler reads the captured value from `req.params`:

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
and faults if the key is missing. Since the route guarantees the parameter, this
is convenient inside the handler.

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

### Path parameter rules

- A parameter matches exactly one segment. `/users/{id}` matches
  `/users/42`, but not `/users/42/posts`.
- A parameter does not match an empty segment. `/users/{id}` does not match
  `/users/`.
- There is no catch-all syntax. Use a fixed number of segments or read the
  remaining path from another source.
- Literal routes take precedence over parameter routes. With `/users/me` and
  `/users/{id}` registered, `GET /users/me` uses the literal handler.
- There is one dynamic branch per trie level. If you register `/users/{id}` and
  `/users/{name}`, both routes share that branch; keep the parameter name
  consistent.
- Parameter values are stored as received. Percent-encoding is not decoded
  automatically.

## Query parameters

The query string is parsed from the request URI and exposed through
`req.query`. Values are optional:

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
    String? query = req.query["q"];
    String? page = req.query["page"];

    if (try query && try page)
    {
        res.status = HttpStatus.OK;
        res.body = string::format(
            allocator,
            "Searching for '%s' on page %s",
            query,
            page
        );
    }
    else
    {
        res.status = HttpStatus.BAD_REQUEST;
        res.body = "Missing q or page parameter";
    }
}
```

A request to `/search?q=c3&page=2` produces:

```text
Searching for 'c3' on page 2
```

Use `!!` when a query parameter is required:

```c3
String q = req.query["q"]!!;
```

If the client omits it, the unwrap faults. Prefer the optional form when you
want to return a validation error instead.

### Query parameter rules

- Pairs are separated by `&` and must use the `name=value` form.
- The parser trims leading and trailing whitespace around keys and values.
- An empty value is allowed: `?q=` yields an empty string.
- If a key appears more than once, the last value is kept.
- Values are stored as received. Percent-encoding and `+` are not decoded
  automatically.
- The query string does not participate in route matching. `/search?q=c3` and
  `/search` use the same route.

## Checking for a parameter

Both parameter maps return `String?`, so the same pattern works for path and
query values:

```c3
String? id = req.params["id"];
if (try id)
{
    // id is valid inside this block
}
```

`req.params.len()` and `req.query.len()` return the number of stored keys. This
is useful for debugging or for deciding whether a request supplied any query
parameters.

## See also

- [HTTP methods](http_methods.md) — route matching and method registration.
- [Handlers](handlers.md) — handler signatures and stateful handlers.
- [Request](../http/request.md) — inspect headers, body, and other request data.
- [Struct binding](../http/encoding/binding.md) — bind form and body data into C3 types.
