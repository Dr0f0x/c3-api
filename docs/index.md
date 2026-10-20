<p align="center">
  <img src="c3api_full.svg" alt="c3-api logo" width="420">
</p>

<p align="center">
  <a href="https://github.com/Dr0f0x/c3-api/actions/workflows/compile-and-test.yml">
    <img src="https://github.com/Dr0f0x/c3-api/actions/workflows/compile-and-test.yml/badge.svg" alt="CI status">
  </a>
  <img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT license">
</p>

# c3-api

**c3-api** is a lightweight HTTP web framework for C3, inspired by Go's [Gin](https://github.com/gin-gonic/gin) and Node.js [Express](https://github.com/expressjs/express/). It brings routing, middleware, request binding, and response serialization to C3 while staying small, explicit, and easy to reason about.

The framework follows the ideas that make Gin and Express pleasant to use — composable middleware, route groups, and handlers that are just functions — and adapts them to C3's allocators and type system. Configuration is available through code or a JSON file, with control over concurrency, keep-alive, timeouts, connection limits, CORS, and logging.

!!! tip "New to c3-api?"

    The [quickstart](quickstart.md) walks through installation and builds a running server in a few minutes.

## Why c3-api?

- **Familiar API** — Routing and middleware modeled after Gin and Express.
- **Composable middleware** — Scope middleware to a path prefix, short-circuit the pipeline, or run code before and after the handler.
- **Typed handlers** — Use free functions or stateful type methods, with type-safe registration macros for both.
- **Request binding and response serialization** — Bind bodies into C3 types and serialize results as JSON, XML, or form data.
- **Route groups** — Organize endpoints under shared prefixes and attach middleware per group, including nested groups.
- **Configurable server** — Tune concurrency modes, keep-alive, timeouts, connection limits, and more through code or `c3api.conf.json`.
- **Built-in essentials** — CORS, logging, cookies, and static file serving are included.

## Installation

Download `c3api.c3l` from the [Releases page](https://github.com/Dr0f0x/c3-api/releases), place it in your project's `lib/` directory, and add `c3api` to your dependencies:

```json
{
  "dependencies": ["c3api"]
}
```

That is the whole setup, as long as `lib/` is in your project's `dependency-search-paths`. See the [quickstart](quickstart.md) for a complete first project and the [configuration overview](configuration/overview.md) for server settings.

## A taste of c3-api

```c3
module main;

import c3api;
import c3api::routing;
import c3api::routing::router;

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

fn int main(String[] args)
{
    c3api::Server server;
    server.init(tmem)!!;

    router::Router* router = server.get_router();
    router.get("/hello/{name}", &hello);

    routing::print_routes(router);
    server.run()!!;

    return 0;
}
```

Run it, then open `http://127.0.0.1:8080/hello/ada`:

```bash
c3c run hello-c3-api
```

## Explore the documentation

<div class="grid cards" markdown>

-   __Quickstart__

    ---

    Install the library, create a server, and register your first route.

    [Get started](quickstart.md)

-   __Routing__

    ---

    HTTP methods, path and query parameters, middleware, groups, and static files.

    [Routing guide](routing/http_methods.md)

-   __Requests & Responses__

    ---

    Inspect requests, build responses, and bind data as JSON, XML, or forms.

    [Request & response](http/request.md)

-   __Configuration__

    ---

    Configure the server, CORS, concurrency, logging, and HTTP behaviour.

    [Configuration](configuration/overview.md)

-   __Examples__

    ---

    Runnable examples for individual features and a complete todo application.

    [Browse examples](examples/index.md)

-   __API Reference__

    ---

    Complete API documentation generated from the C3 sources.

    [Open API reference](https://dr0f0x.github.io/c3-api/api-reference/)

</div>

## Project status

c3-api is under active development. The current focus is on a solid HTTP/1.1 foundation; planned work includes:

- An asynchronous HTTP backend for improved throughput
- HTTP/2 support, including multiplexing and the related encodings
- Pluggable template rendering
- Router performance work and benchmarks
- A broader test suite with unit, integration, and memory-leak coverage

## Contributing

Contributions are welcome. Fork the repository, create a feature branch, make your changes, and open a pull request. For larger changes, please open an issue first so the approach can be discussed.

## License

c3-api is released under the [MIT License](https://github.com/Dr0f0x/c3-api/blob/main/LICENSE).
