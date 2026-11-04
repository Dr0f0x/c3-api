# Server

`c3api::Server` is the central object of a c3-api application. It owns the HTTP
listener, the router, the initial request context, the configuration, the logger,
the concurrency dispatcher, and the built-in middleware. Routes, middleware, and
handlers are not attached to a global singleton; they are registered on the
router that belongs to a server instance and executed by that server's request
pipeline.

Most applications should therefore have the same shape: create a server, register
everything on it, then start it.

## Lifecycle at a glance

```c3
import c3api;
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
    res.body = "Hello from c3-api";
}

fn int main(String[] args)
{
    // Create and initialize the server.
    c3api::Server server;
    server.init(tmem)!!;
    defer server.free();

    // Register routes on the router owned by the server.
    router::Router* router = server.get_router();
    router.get("/hello", &hello);

    // Start the blocking accept loop.
    server.run()!!;

    return 0;
}
```

The server is normally allocated on the stack. `init` prepares it in place and
returns a pointer to it, `run` starts serving requests, and `free` releases
resources owned by the server after `run` returns.

Register routes, middleware, and shared context values before calling `run`.
The server dispatches requests concurrently and expects the router and initial
context to be ready once the accept loop starts.

## What the server owns

| Component | Access | Purpose |
| --- | --- | --- |
| Configuration | `server.get_config()` | Network, HTTP, CORS, concurrency, and logging settings. |
| Router | `server.get_router()` | Route table and middleware used to resolve requests. |
| Initial context | `server.get_context()` | Shared values copied into the context used for request processing. |
| Logger | `server.get_logger()` | Logger used by the server, router, and built-in middleware. |
| Listener and accept loop | `server.run()` | Binds the configured address and dispatches accepted connections. |
| Concurrency dispatcher | internal | Thread pool or per-connection threads, selected by configuration. |
| Built-in middleware | configuration and `server.use_builtin_logging_middleware()` | Request logging and CORS integration. |

## Initialization

```c3
fn Server*? Server.init(
    &self,
    Allocator allocator,
    Config* config = null,
    log::Logger logger = null
)
```

| Parameter | Description |
| --- | --- |
| `allocator` | Allocator used for server-owned internal allocations, including the router and initial context. It must remain valid for as long as the server is used. |
| `config` | Optional configuration. When `null`, the server loads `c3api.conf.json` and owns the resulting configuration. |
| `logger` | Optional logger. When `null`, the server creates a default logger according to the logging configuration. |

When no configuration is supplied, `init` loads `c3api.conf.json` from the
current working directory. If the file does not exist, it is created with the
default settings. The server owns this configuration and frees it in
`server.free()`.

When a configuration is supplied, the server stores the pointer instead of
copying it. The caller keeps ownership and must keep the configuration alive for
at least as long as the server:

```c3
import c3api::config;

config::Config config;
config.from_file(tmem);
defer config.free(tmem);

c3api::Server server;
server.init(tmem, &config)!!;
defer server.free();
```

The same ownership rule applies to a custom logger. If `logger` is `null`, the
server creates a default `C3ApiLogger` and adds a console sink and, optionally,
a file sink based on `config.logging`. The default file sink writes to
`c3api.log`. If a logger is supplied, the server uses it but does not free it.

## Working with the server

### Router

`server.get_router()` returns the `Router*` that the server uses for request
resolution. It is initialized with the server's allocator and logger. Register
routes and middleware on this router before starting the server:

```c3
router::Router* router = server.get_router();

router.use("/", &request_logger);
router.get("/users/{id}", &get_user);
```

If CORS is enabled in the configuration, the server adds its built-in CORS
middleware to the router during initialization. The rest of the route table is
yours to define. See [routing](routing/handlers.md) for handlers, middleware,
groups, and static files.

### Logger

`server.get_logger()` returns the logger the server uses. It is the same logger
that the built-in request logging middleware writes to. To use it in handlers
or middleware, register it in the server's initial context:

```c3
import c3api::log;

server.get_context().register(log::Logger, server.get_logger());
```

A handler or middleware can then resolve it by type:

```c3
log::Logger* log = ctx.resolve(log::Logger)!!;
log.info("handling request");
```

See [Context](http/context.md) and [Logger](logging/logger.md) for more
about contexts and logging.

### Configuration

`server.get_config()` returns the configuration the server was initialized with.
It exposes the network binding settings, HTTP limits, CORS settings, concurrency
mode, and logging settings:

```c3
import std::io;

config::Config* config = server.get_config();
io::printfn("listening on %s:%d", config.address, config.port);
```

Configure the server before calling `init`, or treat the returned configuration
as read-only afterwards. Initialization reads settings such as CORS and the
default logger configuration, and `run` reads the listener and concurrency
settings. See the [configuration overview](configuration/overview.md) for the
full set of options.

### Initial context

`server.get_context()` returns a `ServerContext*`, a restricted view of the
initial context. It supports the same type-keyed registration API as the
handler-facing context:

```c3
import c3api::log;

String app_name = "demo";
server.get_context().register(log::Logger, server.get_logger());
server.get_context().set("app_name", &app_name);
```

Values registered here are copied into the context used for request processing,
so handlers and middleware can resolve them without receiving the server itself:

```c3
fn void handler(
    void* self = null,
    Allocator allocator,
    HandlerContext* ctx,
    HttpRequest* req,
    HttpResponse* res,
)
{
    log::Logger* log = ctx.resolve(log::Logger)!!;
    log.info("hello from the handler");

    res.status = HttpStatus.OK;
    res.body = "ok";
}
```

Only the pointers are copied. Anything registered must stay valid for as long as
the server may serve requests. Use this mechanism for application-wide
dependencies such as a logger, database handle, or service object, not for
request-local state. Values set in an individual request context do not change
the server's initial context.

The `ServerContext` view intentionally has no `next()` method: it seeds request
contexts but never advances the middleware pipeline.

## Running the server

`server.run()` performs the following steps:

1. Registers the built-in logging middleware, unless it was disabled.
2. Initializes the configured concurrency dispatcher.
3. Binds the listener to `config.address` and `config.port` with
   `config.tcp_backlog`.
4. Logs the listening address and enters the accept loop.
5. Dispatches each accepted connection to a worker and processes requests using
   the shared router, configuration, logger, and initial context.

`run` is blocking; it does not return while the accept loop is running. If the
listener cannot bind, the error is logged and the accept loop does not start.

The concurrency mode is selected with `config.concurrency.mode`:

| Mode | Behavior |
| --- | --- |
| `THREAD_POOL` | Accepted connections are submitted to a pool sized by `max_threads`, with `queue_capacity` pending connections and worker threads that idle for `keep_alive_ms`. This is the default. |
| `THREAD_PER_REQUEST` | Each accepted connection is handled by a newly created detached thread. |

HTTP behavior is also controlled by configuration, including keep-alive,
`max_read_size`, and `trace_enabled`. See
[Server & HTTP configuration](configuration/server_http.md) and
[Concurrency mode](configuration/concurrency_mode.md).

## Shutdown and ownership

!!! note "Stopping a running server"

    `run` blocks for the lifetime of the accept loop, and there is currently no
    public `stop` or `shutdown` method on `Server`. Stop the process (for
    example with `Ctrl+C`) to end the server. A deferred `server.free()` runs
    once `run` returns or the enclosing scope is otherwise left.

Call `server.free()` after `run` returns, or schedule it with `defer` immediately
after initialization. It releases:

- the default logger and its sinks, if the server created them;
- the configuration, if the server loaded it;
- the initial context.

It does not free caller-supplied configurations or loggers, and it does not free
the objects registered in the initial context. Free those separately after the
server has stopped using them, in the reverse order of their creation:

```c3
config::Config config;
config.from_file(tmem);
defer config.free(tmem);

c3api::Server server;
server.init(tmem, &config)!!;
defer server.free();

server.run()!!;
```

Because `server.free()` is deferred after `config.free()`, it runs before the
configuration is released. The same principle applies to custom loggers and any
application objects registered in the initial context.

## See also

- [Quickstart](quickstart.md) — build and run a first server.
- [Routing](routing/handlers.md) — handler signatures and type methods.
- [Context](http/context.md) — share values across the request pipeline.
- [Logger](logging/logger.md) — configure and use logging.
- [Configuration](configuration/overview.md) — server settings.
- [Examples](examples/index.md) — browse runnable example applications.
