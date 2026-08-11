<p align="center">
    <img src="docs/c3api_full.svg" alt="c3api-logo" height="160">
</p>

**c3-api** is a lightweight HTTP web framework for C3, inspired by Go's [Gin](https://github.com/gin-gonic/gin) and Node.js [Express](https://github.com/expressjs/express/). With extensive support for routing, middleware and request handling, c3-api focuses on simplicity, performance, and developer productivity while staying lightweight and easy to use. The framework is highly configurable, allowing fine-grained control over server behavior such as concurrency models, keep-alive settings, timeouts, and other networking options.

This project originally started as a fork of the original [c3-api](https://github.com/velikoss/c3-api), which is why it retains the same name. However while adding the new features and changing the API to match Gin and Express, I found myself essentially rewriting everything and thus made it an independent project.

### Key Features:

- **Middleware support** - Extensible middleware system for authentication, logging, etc.
- **Route grouping** - Organize related routes and apply common middleware
- **Built-in CORS support** - Simple and flexible Cross-Origin Resource Sharing configuration.
- **Highly configurable server** - Configure server behavior through code or JSON configuration files, with fine-grained control over concurrency modes, keep-alive settings, timeouts, connection limits, and other networking options

## Table of contents

- [Installation](#installation)
- [Quickstart](#quickstart)
- [Overview](#overview)
  - [Route handlers](#route-handlers)
  - [Middleware](#middleware)
  - [Path parameters](#path-parameters)
  - [Query parameters](#query-parameters)
  - [Route groups](#route-groups)
- [Documentation](#documentation)
- [Configuration](#configuration)
- [Docker](#docker)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)

## Installation

- Download latest `c3api.c3l` from [Releases](TO-DO)
- Move the file to your projects `lib/` folder
- Add c3api to your dependencies in `project.json`

```json
{
    ...
  "dependencies": ["c3api"],
    ...
}
```

## Quickstart

Here's a minimal example showing how to setup c3-api and a first route handler:

```c3
module main;

import c3api;
import c3api::routing;
import c3api::routing::router;

<*
 Simple route handler.
 Handles requests to: GET /test/{name}

 The value of `{name}` is extracted from the route parameters and
 returned to the client as part of the response body.
*>
fn void handler(void* self = null, Allocator allocator, Context* ctx, HttpRequest* req, HttpResponse* res)
{
    // Set HTTP status code.
    res.status = HttpStatus.OK;

    @pool()
    {
        // Build the response message.
        DString greeting = dstring::temp();

        // Access the path parameter under "name".
        greeting.appendfn("hello %s, c3-api is running!", req.params["name"]!!);

        // Write the response body.
        res.body = string::format(allocator, greeting.tcopy_str(), req.method, req.uri);
    };
}

fn int main(String[] args)
{
    // Create and initialize the server.
    c3api::Server server;
    server.init(tmem)!!;

    // Get the router instance from the server.
    router::Router* router = server.get_router();

    // Register the route with a path parameter.
    router.get("/test/{name}", &handler);

    // Print all registered routes.
    routing::print_routes(router);

    // Start the HTTP server.
    server.run()!!;

    return 0;
}
```

### Running the application

1. Paste the code above into your applications `main.c3` file
2. Run the the application with

   ```bash
   c3c run <project-name>
   ```

   You should see this

   ```
   test
     {name} - GET
   [Wed Aug  5 15:52:25 GMT 2026] [INFO] listening on <127.0.0.1:8080>
   ```

   being printed to the console.

3. Open you browser and visit http://localhost:8080/test/charlie

4. You should see: `hello charlie, c3-api is running!` and logs similar to

   ```
   [Wed Aug  5 16:10:15 GMT 2026] [INFO] GET /test/charlie | Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:153.0) Gecko/20100101 Firefox/153.0
   ```

   being printed to the console.

### What this example demonstrates

- Creating a c3-api server and router with default middleware
- Defining a simple HTTP endpoint with its handler function
- using dynamic routes and accessing path parameters in the handler
- Starting the server

For other and more complete examples checkout the [examples](examples/) folder.

## Overview

### Route Handlers

Every route in **c3-api** is handled by a function with the following signature:

```c3
fn void handler(void* self = null,
    Allocator allocator,
    Context* ctx,
    HttpRequest* req,
    HttpResponse* res
)
{
    // ...
}
```

The parameters have the following purpose:

- `self` – Optional instance pointer. This enables using type methods as route handlers. For regular free functions, this parameter is left as `null`.
- `allocator` – A request-scoped allocator that remains valid for the entire lifetime of the request. Any memory allocated using this allocator is automatically released once request processing has completed. Inside handlers the same is true for the builtin `tmem` allocator (if you dont nest `@pool` further)
- `ctx` – A request context shared between middleware and the final route handler. It can be used to store and retrieve arbitrary data throughout the processing pipeline. The server can also be configured to populate the context with initial values for every incoming request.
- `req` – The incoming HTTP request, containing information such as the method, URI, headers, query parameters, route parameters, and request body.
- `res` – The HTTP response that the handler populates by setting the status code, headers, and response body.

Routes are registered on a `Router` instance. The underlying API accepts the HTTP method, URI, handler function, and an optional instance pointer:

```c3
router.add_route(RouteMethod.GET, "/example", &handler);
```

For convenience, the router provides shorthand macros for every HTTP method:

```c3
router.get("/example", &handler);
router.post("/example", &handler);
router.put("/example", &handler);
router.patch("/example", &handler);
router.delete("/example", &handler);
```

While these methods do allow passing an instance pointer, using them directly for type methods requires casting:

```c3
Controller controller;
router.get("/controller", (HandleFunc)&Controller.handle, &controller);
```

The recommended apporach for this would be to use the provided generic and typesafe macros, These ensure the correct handler and instance type and eliminate the need for manual casts:

```c3
Controller controller;
router::get{Controller}(router, "/controller", &Controller.handle, &controller);
```

### Middleware

Every middleware function has the following signature:

```c3
fn RequestFlow middleware(
    void* self = null,
    Allocator allocator,
    Context* ctx,
    HttpRequest* request,
    HttpResponse* response
)
{
    // ...
}
```

The parameters are identical to those of route handlers:

- `self` – Optional instance pointer that enables using type methods as middleware.
- `allocator` – A request-scoped allocator that remains valid for the entire lifetime of the request. Again the same is true for `tmem` if you are not inside a nested `@pool`.
- `ctx` – The shared request context. Middleware can populate the context with data that is later consumed by other middleware or the final route handler.
- `request` – The incoming HTTP request.
- `response` – The HTTP response that middleware may modify before it is sent to the client.

Unlike route handlers, middleware returns a `RequestFlow` value:

```c3
enum RequestFlow
{
  CONTINUE,
  INTERRUPT,
}
```

Returning `RequestFlow.CONTINUE` allows request processing to continue with the next middleware or the final route handler, while `RequestFlow.INTERRUPT` immediately stops further processing.

Middleware is registered on a router using `Router.use()`:

```c3
router.use("/", &logging_middleware);
```

The URI specifies the path prefix for which the middleware should execute. For example, registering middleware on `/api` causes it to run for all routes beginning with `/api`.

Similar to route handlers this in principle also works for type methods but would require a manual cast. The recommended approach is again to use a generic macro, which infers the correct middleware type and avoid them:

```c3
AuthMiddleware auth;
router::use{AuthMiddleware}(router, "/api", &AuthMiddleware.authorize, &auth);
```

### Path parameters

Routes can define path parameters by enclosing a path segment in curly braces. The value matched for that segment is automatically extracted and made available to middleware and route handlers.

For example, the following route defines a single path parameter named name:

```c3
router.get("/{name}", &no_controller);
```

A request such as:

```
GET /Alice
```

matches the route and makes the value `"Alice"` available under the `name` parameter.

Path parameters are accessed through the request's params map:

```c3
fn void no_controller(
  void* self = null,
  Allocator allocator,
  Context* ctx,
  HttpRequest* req,
  HttpResponse* res
)
{
  String arg = req.params["name"]!!;
}
```

### Query parameters

Query parameters are parsed automatically for every request and require no additional route registration. They are exposed through the request's `query` map and can be accessed by name.

For example, given the following request:

```
GET /search?test=value
```

inside a handler the value of the `test` query parameter can be retrieved as follows:

```c3
fn void no_controller(
  void* self = null,
  Allocator allocator,
  Context* ctx,
  HttpRequest* req,
  HttpResponse* res
)
{
  String? val = req.query["test"];
}
```

### Route groups

Similar to Gin, **c3-api** provides route groups to organize related endpoints under a common path prefix. Groups allow multiple routes to share the same base URI while keeping registrations concise. Middleware can also be attached to a group, making it easy to apply behavior to an entire section of your API.

A group is created from an existing router:

```c3
Group* example = router.group(tmem, "/v1/example");
```

Once created, routes and middleware registered on the group are automatically relative to the group's base path.

For example:

```c3
@pool() {
  Group* example = router.group(tmem, "/v1/example");
  example.use("/", &group_log_middleware);
  example.use("/{name}", &endpoint_log_middleware);
  example.get("/{name}", &no_controller);
}
```

The example above registers the following middleware and route:

- Group middleware on `/v1/example/`
- Endpoint middleware on `/v1/example/{name}`
- `GET /v1/example/{name}`

All registration methods available on `Router`, including the generic routing macros for type methods, are also available on `Group`.

For explanations of additional framework features — such as the built-in logger, serving static files, and more in-depth guides - refer to the full [documentation](TO-DO).

## Documentation

### API Reference

- [C3 DocGen API Documentation](TO-DO) — Complete API reference generated with the C3 documentation generator.

### Website

- [MkDocs Documentation](TO-DO) — Guides, tutorials, configuration reference, and additional documentation built with MkDocs.

## Configuration

`c3api` is configured through a `config::Config` instance that is passed to `Server.init()`. If no configuration is passed, the server automatically loads its configuration from the default file, `c3api.conf.json`, creating it with defaults if it does not exist.

Alternatively, you can create a `config::Config` instance from the defaults yourself, modify only the settings you care about, and pass it to `Server.init()`.

```c3
config::Config config;
config.from_default(mem);
defer config.free(mem);

server.init(tmem, &config);
defer server.free();
```

Another option is to use `Config.from_file()`. This allows you to specify both the configuration file path and whether the file should be created automatically if it is missing. This is the same mechanism that `Server.init()` uses internally when no configuration is supplied.

```c3
config::Config config;
config.from_file(mem);
// with all three parameters
config.from_file(mem, config::DEFAULT_CONF_PATH, true);
defer config.free(mem);

server.init(tmem, &config);
defer server.free();
```

The snippet below shows the configuration structure and the default values. If you want a more detailed explanation of all available settings, take a look at the corresponding page in the [documentation](TO-DO).

```json
{
  "address": "127.0.0.1",
  "port": 8080,
  "tcp_backlog": 10000,
  "http": {
    "trace_enabled": false,
    "max_read_size": 5242880,
    "keep_alive": {
      "enabled": true,
      "max_requests_per_connection": 500,
      "idle_timeout_ms": 10000
    }
  },
  "cors": {
    "enabled": false,
    "allow_methods": "GET, POST, OPTIONS",
    "allow_headers": "Content-Type",
    "allow_origin": "*"
  },
  "concurrency": {
    "mode": "THREAD_POOL",
    "thread_pool": {
      "max_threads": 32,
      "queue_capacity": 10000,
      "keep_alive_ms": 30000
    }
  },
  "logging": {
    "console": {
      "enabled": true,
      "min_level": "INFO"
    },
    "file": {
      "enabled": false,
      "min_level": "INFO"
    }
  }
}
```

## Docker

c3-api can obviously be deployed in Docker containers, however when not running in `host` networking mode, configure it to listen on `0.0.0.0`, otherwise your application wont be reachable from the outside.

Simple examples for both `docker` and `docker-compose` are available in the root of this project:

- [Dockerfile](Dockerfile)
- [docker-compose.yml](docker-compose.yml)

## 🚧 Roadmap

Here are some planned features and improvements for the `c3-api` project:

- [ ] **Testing**: Robust test suite in c3 for unit tests and with python for integration tests.
- [ ] **Documentation**: Improve documentation with detailed examples and usage guides (e.g. the mkdocs site).
- [ ] **Pipeline**: Pipeline to build and test the library, including performance and memory leak tests
- [ ] **Http 2.0**: Full support for the different encoding, as well as features like multiplexing
- [ ] **Pluggable Template rendering backend**: Similar to the way express does it
- [ ] **Performance Optimizations**: Especially in the router (target should be 0 allocs)
- [ ] **Benchmarks**

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository.
2. Create a new branch (`git checkout -b feature-branch`).
3. Commit your changes (`git commit -am 'Add new feature'`).
4. Push to the branch (`git push origin feature-branch`).
5. Create a new Pull Request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
