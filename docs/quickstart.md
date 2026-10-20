# Quickstart

This guide takes you from an empty C3 project to a running c3-api server. It should take a few minutes.

## Prerequisites

- A C3 compiler (`c3c`) available on your `PATH`. See [c3-lang.org](https://c3-lang.org) for installation instructions.
- Basic familiarity with C3 modules and functions.

## Create a project

If you do not already have a C3 project, create one with the C3 compiler:

```bash
c3c init hello-c3-api
cd hello-c3-api
```

This creates a project with `src/main.c3` and a `lib/` directory for dependencies.

## Add c3-api

=== "Packaged library"

    Download `c3api.c3l` from the [Releases page](https://github.com/Dr0f0x/c3-api/releases) and place it in your project's `lib/` directory.

    Add `c3api` to the dependencies in `project.json`:

    ```json
    {
      "dependency-search-paths": ["lib"],
      "dependencies": ["c3api"]
    }
    ```

    The `dependency-search-paths` field is already present in projects created with `c3c init`; only add the dependency entry if it is missing.

    !!! note "No packaged build available?"

        The Releases page is the intended installation path. If there is no `c3api.c3l` asset yet, you can still explore the framework by building the bundled examples from a source checkout.

=== "Source checkout (contributors)"

    To work on c3-api itself or try the bundled examples, clone the repository and build the library:

    ```bash
    git clone https://github.com/Dr0f0x/c3-api.git
    cd c3-api
    c3c build c3api
    ```

    Then run the minimal example:

    ```bash
    c3c run minimal-demo
    ```

## Write your first server

Replace the contents of `src/main.c3` with the following:

```c3
module hello_c3_api;

import c3api;
import c3api::routing;
import c3api::routing::router;

<*
 Returns a greeting for the requested name.
 Handles requests to: GET /hello/{name}
*>
fn void hello(
    void* self = null,
    Allocator allocator,
    HandlerContext* ctx,
    HttpRequest* req,
    HttpResponse* res,
)
{
    // Set the HTTP status code.
    res.status = HttpStatus.OK;

    // Read the `{name}` path parameter and write the response body.
    res.body = string::format(allocator, "Hello %s!", req.params["name"]!!);
}

fn int main(String[] args)
{
    // Create and initialize the server.
    c3api::Server server;
    server.init(tmem)!!;

    // Get the router instance from the server.
    router::Router* router = server.get_router();

    // Register the route. `{name}` is a path parameter.
    router.get("/hello/{name}", &hello);

    // Print the registered routes to the console.
    routing::print_routes(router);

    // Start the HTTP server.
    server.run()!!;

    return 0;
}
```

### What the example does

1. `server.init(tmem)` initializes the server and loads `c3api.conf.json`, creating it with defaults if needed.
2. `server.get_router()` returns the router owned by the server.
3. `router.get(...)` registers a handler for `GET /hello/{name}`.
4. `{name}` is captured from the URL and exposed through `req.params`.
5. `server.run()` starts accepting requests on `127.0.0.1:8080`.

### Handler signature

Every route handler receives the same parameters:

| Parameter | Purpose |
| --- | --- |
| `self` | Optional instance pointer for type-method handlers. `null` for regular functions. |
| `allocator` | Request-scoped allocator, valid until request processing completes. |
| `ctx` | Shared request context for passing data between middleware and handlers. |
| `req` | The parsed request: method, URI, headers, query parameters, path parameters, and body. |
| `res` | The response to populate with a status code, headers, and body. |

## Run the server

```bash
c3c run hello-c3-api
```

You should see the registered route and the listening address:

```text
hello
  {name} - GET
[Tue Oct 20 11:00:03 GMT 2026] [INFO] listening on <127.0.0.1:8080>
```

Open `http://127.0.0.1:8080/hello/ada` in your browser, or use `curl`:

```bash
curl http://127.0.0.1:8080/hello/ada
```

The response is:

```text
Hello ada!
```

## Configuration

If no configuration is supplied, `server.init()` loads `c3api.conf.json` from the current working directory and creates it with defaults if it does not exist. On the first run you will see the file appear in your project root.

To change the listening address or port, edit the file:

```json
{
  "address": "0.0.0.0",
  "port": 8080
}
```

Alternatively, load a configuration explicitly in code:

```c3
import c3api::config;

config::Config config;
config.from_file(tmem);
defer config.free(tmem);

server.init(tmem, &config)!!;
```

See the [configuration overview](configuration/overview.md) for all available settings.

!!! tip "Running in Docker?"

    Set `address` to `0.0.0.0` so the server is reachable from outside the container, then publish the port (for example, `-p 8080:8080`).

## Next steps

- [HTTP methods](routing/http_methods.md) — Register handlers for every supported method.
- [Path & query parameters](routing/parameters.md) — Read values from the URL.
- [Middleware](routing/middleware.md) — Add logging, authentication, and other cross-cutting behavior.
- [Route groups](routing/groups.md) — Organize endpoints under shared prefixes.
- [Request binding](http/encoding/binding.md) — Decode JSON, XML, and form bodies into C3 types.
- [Examples](examples/index.md) — Browse runnable projects, including a complete todo application.

## Troubleshooting

**The server does not start.** Check whether another process is already using port `8080`. Change `port` in `c3api.conf.json` or free the port.

**The app is unreachable from a container or another machine.** Set `"address": "0.0.0.0"` in `c3api.conf.json` and make sure the port is published.

**A route returns a 404.** Compare the request path with the output of `routing::print_routes(router)`. Path parameters use braces, for example `/hello/{name}`.
