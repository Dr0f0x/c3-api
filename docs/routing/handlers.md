# Handlers

A handler is a function that receives a request and fills in a response. Every
handler has the same signature, whether it is a free function or a method on a
struct.

```c3
fn void handler(
    void* self = null,
    Allocator allocator,
    HandlerContext* ctx,
    HttpRequest* req,
    HttpResponse* res,
)
{
    res.status = HttpStatus.OK;
    res.body = string::format(allocator, "Hello from c3-api");
}
```

Register it with any of the method helpers:

```c3
router.get("/hello", &handler);
```

## Handler parameters

| Parameter | Purpose |
| --- | --- |
| `self` | Optional instance pointer. It is `null` for free functions. |
| `allocator` | Request-scoped allocator for response data. It is valid until request processing completes. |
| `ctx` | Shared request context used to pass values between middleware and handlers. |
| `req` | The parsed request, including method, URI, headers, path parameters, query parameters, and body. |
| `res` | The response to populate with a status, headers, and body. |

Handlers return `void`. They signal the result by writing to `res`; the server
sends the response after the handler and middleware pipeline finish.

!!! note "Allocator lifetime"

    Data allocated with `allocator` is valid for the current request. Do not
    store pointers allocated from it in global state or in objects that outlive
    the request. Use a longer-lived allocator for persistent data.

## Stateful handlers

A handler can be a method on a struct. The `self` parameter then points at the
instance supplied during registration:

```c3
struct Counter
{
    int value;
}

fn void Counter.handle(
    &self,
    Allocator allocator,
    HandlerContext* ctx,
    HttpRequest* req,
    HttpResponse* res,
)
{
    res.status = HttpStatus.OK;
    res.body = string::format(allocator, "Counter: %d", self.value);
    self.value++;
}
```

Create the instance before registering the route and keep it alive for as long
as the server may handle requests:

```c3
Counter counter;
router.get("/counter", (HandleFunc)&Counter.handle, &counter);
```

The cast is required because the non-generic registration helpers accept the
plain `HandleFunc` type, whose `self` parameter is `void*`.

The generic helpers preserve the instance type, so no cast is needed:

```c3
router::get{Counter}(router, "/typed-counter", &Counter.handle, &counter);
```

For an arbitrary method, use the generic `route` helper:

```c3
router::route{Counter}(
    router,
    RouteMethod.PUT,
    "/typed-counter",
    &Counter.handle,
    &counter
);
```

The generic forms are type-safe: the instance argument must match the type of
the handler's `self` parameter.

!!! warning "Shared state"

    A handler instance is shared by every request that reaches its route. If
    the server can process requests concurrently, protect mutable instance
    state with appropriate synchronization. Prefer request-local data when the
    state does not need to survive between requests.

## Handler types

The routing module exposes two aliases:

| Alias | `self` type | Use |
| --- | --- | --- |
| `HandleFunc` | `void*` | Free functions and manually cast type methods |
| `HandleFuncGen{Type}` | `Type*` | Type-safe type-method handlers |

Both have the same remaining parameters: `Allocator`, `HandlerContext*`,
`HttpRequest*`, and `HttpResponse*`.

## Registering one handler for several methods

Register the same function more than once when the behavior is identical:

```c3
router.get("/status", &status);
router.post("/status", &status);
```

A `HEAD` request can use an explicit `HEAD` route or fall back to `GET`. See
[HTTP methods](http_methods.md) for the fallback rules.

## Unmatched requests

When no route matches, the server uses the built-in 404 handler. It sets
`Content-Type: application/json` and returns:

```json
{"type":"error","status":404}
```

The 404 handler is not configurable at the moment.

## See also

- [HTTP methods](http_methods.md) — method helpers and route matching.
- [Path & query parameters](parameters.md) — read values from the request URL.
- [Middleware](middleware.md) — run code around handlers.
- [Context](../http/context.md) — share values across the pipeline.
- [Response](../http/response.md) — status codes, headers, and response bodies.
