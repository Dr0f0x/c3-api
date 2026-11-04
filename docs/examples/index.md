# Examples

The c3-api repository includes runnable examples for individual features and a
complete todo application. Every example is an executable target in
[`project.json`](https://github.com/Dr0f0x/c3-api/blob/main/project.json) and
lives under [`examples/`](https://github.com/Dr0f0x/c3-api/tree/main/examples).

## Running the examples

From a source checkout, build the library once:

```bash
c3c build c3api
```

Then run any target from the repository root:

```bash
c3c run minimal-demo
```

The examples listen on `http://127.0.0.1:8080` by default. Stop a running
example with `Ctrl+C`. If port `8080` is already in use, change `port` in
`c3api.conf.json`.

## At a glance

| Example | Focus | Target |
| --- | --- | --- |
| [Minimal server](#minimal-server) | Smallest complete server | `minimal-demo` |
| [Handlers](#handlers) | Function, type-method, and generic handlers | `handler-demo` |
| [Middleware](#middleware) | Function and type-method middleware | `middleware-demo` |
| [Route groups](#route-groups) | Prefixes, nesting, and group middleware | `group-demo` |
| [Path parameters](#path-parameters) | Single and multiple path values | `path-demo` |
| [Query parameters](#query-parameters) | Reading and validating query values | `query-demo` |
| [Cookies](#cookies) | Reading and setting HTTP cookies | `cookie-demo` |
| [Encoding](#encoding) | JSON, XML, and form binding | `encoding-demo` |
| [Static files](#static-files) | Serving frontend assets | `static-demo` |
| [Logger](#logger) | Console and rotating file sinks | `logger-demo` |
| [Todo application](#todo-application) | Complete app combining features | `todo-demo` |

## Basic examples

These examples focus on a single feature and are the fastest way to see the API
in use.

### Minimal server

[Source](https://github.com/Dr0f0x/c3-api/tree/main/examples/basic/minimal) ·
`c3c run minimal-demo`

The smallest complete c3-api setup: create and initialize a server, register a
route on the router, print the route table, and start the HTTP listener.

- **Routes:** `GET /test`
- **Files:** `main.c3`

### Handlers

[Source](https://github.com/Dr0f0x/c3-api/tree/main/examples/basic/handlers) ·
`c3c run handler-demo`

Compares free-function handlers with type method handlers. It also shows
cast-based registration and the type-safe generic helpers that avoid manual
casts.

- **Routes:** `GET /test`, `GET /counter`, `GET /generic`, `GET /generic-counter`
- **Files:** `main.c3`
- The counter routes increment their value on every request.

### Middleware

[Source](https://github.com/Dr0f0x/c3-api/tree/main/examples/basic/middleware) ·
`c3c run middleware-demo`

Demonstrates function and type-method middleware. One middleware adds an
`X-Middleware` response header; the type method middleware increments a counter
and stores it in the request context for the handler.

- **Routes:** `GET /test`, `GET /generic`
- **Files:** `main.c3`
- Shows both `router.use(...)` and the generic `router::use{T}(...)` form.

### Route groups

[Source](https://github.com/Dr0f0x/c3-api/tree/main/examples/basic/group) ·
`c3c run group-demo`

Creates a `/api/v1` group, adds group middleware, and nests a `/users` group
under it. Requests to the nested group pass through both middleware layers.

- **Routes:** `GET /api/v1/test`, `GET /api/v1/users/test`
- **Files:** `main.c3`
- The group middleware sets `X-V1-Middleware` and `X-User-Middleware`.

### Path parameters

[Source](https://github.com/Dr0f0x/c3-api/tree/main/examples/basic/path) ·
`c3c run path-demo`

Extracts values captured by the route pattern and reads them through
`req.params`. Both a single parameter and multiple parameters are registered.

- **Routes:** `GET /test/{name}`, `GET /test/{name}/{id}`
- **Files:** `main.c3`
- Try `/test/charlie` and `/test/charlie/12`.

### Query parameters

[Source](https://github.com/Dr0f0x/c3-api/tree/main/examples/basic/query) ·
`c3c run query-demo`

Reads query string values through `req.query` and handles missing parameters.
The second route requires both `query` and `page`.

- **Routes:** `GET /test?name={name}`, `GET /search?query={query}&page={page}`
- **Files:** `main.c3`
- Try `/test?name=charlie` and `/search?query=c3-api&page=2`.

### Cookies

[Source](https://github.com/Dr0f0x/c3-api/tree/main/examples/basic/cookies) ·
`c3c run cookie-demo`

Reads a `lastVisit` cookie, parses its Unix timestamp, and reports the previous
visit. The handler then sets an updated cookie with expiration, `Max-Age`,
`Path`, and `Secure` attributes.

- **Routes:** `GET /test`
- **Files:** `main.c3`, `timeutil.c3`
- Handles both missing cookies and invalid timestamp values.

### Encoding

[Source](https://github.com/Dr0f0x/c3-api/tree/main/examples/basic/encoding) ·
`c3c run encoding-demo`

Binds the same `Product` structure from JSON, XML, and form data, then serializes
the response in the corresponding format. It also demonstrates nested structure
binding and tag-based field mapping with `@Json`, `@Xml`, and `@Form`.

- **Routes:** `POST /json`, `POST /xml`, `POST /form`
- **Files:** `main.c3`
- See the [example README](https://github.com/Dr0f0x/c3-api/blob/main/examples/basic/encoding/README.md)
  for ready-to-run request payloads.

### Static files

[Source](https://github.com/Dr0f0x/c3-api/tree/main/examples/basic/static) ·
`c3c run static-demo`

Serves a complete static frontend with a caller-owned `StaticFiles` store. The
`/` route maps to the example's `public` directory.

- **Routes:** `GET /` and the files below it
- **Files:** `main.c3`, `public/index.html`, `public/style.css`, `public/favicon.svg`

### Logger

[Source](https://github.com/Dr0f0x/c3-api/tree/main/examples/basic/logger) ·
`c3c run logger-demo`

Configures the c3-api logger with console output and a custom rotating file
sink. Log levels are read from `c3api.conf.json`, and the logs are written under
`log/`.

- **Routes:** `GET /test`
- **Files:** `main.c3`, `rotating_file_sink.c3`

## Complete example

### Todo application

[Source](https://github.com/Dr0f0x/c3-api/tree/main/examples/complete/todo) ·
`c3c run todo-demo`

A larger application that combines routing, nested groups, router/group/endpoint
middleware, typed handlers, cookies, static files, and form binding.

- **Routes:**
    - `GET /v1/example/{name}`
    - `GET /v1/example/static/yay`
    - `GET /v1/example/staticc/ctrl`
    - `GET /staticc/ctrl`
    - `GET /files/*`
    - `POST /todo` with form-encoded todo data
- **Files:** `main.c3`, `public/index.html`, `public/main.html`
- The static frontend is available under `http://127.0.0.1:8080/files/`.

## See also

- [Quickstart](../quickstart.md) — build and run a first server.
- [Routing](../routing/http_methods.md) — method registration and HEAD, OPTIONS,
  and TRACE behavior.
- [Request binding](../http/encoding/binding.md) — bind request data into C3
  types.
