# Static Files

Static routes serve files from disk. The router supports a whole directory or a
single file, and both can be mounted under a URL prefix.

## Serve a directory

Create a `StaticFiles` store, point it at a directory, and register it on the
router:

```c3
import std::io::path;

import c3api;
import c3api::routing;
import c3api::routing::router;

fn int main(String[] args)
{
    c3api::Server server;
    server.init(tmem)!!;

    router::Router* router = server.get_router();

    Path dir = path::tcwd()!!.tappend("public")!!;

    routing::StaticFiles files;
    files.init(tmem, dir);
    defer files.free();

    router.serve_static("/static", &files)!!;

    routing::print_routes(router);
    server.run()!!;

    return 0;
}
```

With this mount, a file at `public/css/app.css` is served at
`/static/css/app.css`.

The path can also be a single file. In that case `serve_static` registers that
file at the mount URI.

## Serve one file

Use `StaticFile` when you only need one route:

```c3
Path favicon_path = path::tnew("public/favicon.ico")!!;

routing::StaticFile favicon;
favicon.init(tmem, favicon_path);
defer favicon.free();

router.serve_static_file("/favicon.ico", &favicon)!!;
```

Single files can also be registered on a group. The route stays relative to the
group:

```c3
group::Group* assets = router.group(tmem, "/assets");

Path logo_path = path::tnew("public/logo.svg")!!;

routing::StaticFile logo;
logo.init(tmem, logo_path);
defer logo.free();

assets.serve_static_file("/logo.svg", &logo)!!;
```

This serves the file at `/assets/logo.svg`.

## Directory options

`StaticFiles.init` accepts two options:

| Option | Default | Behavior |
| --- | --- | --- |
| `indexing` | `true` | Maps the directory's `index.html` to the mount prefix. |
| `clean_urls` | `true` | Also registers extensionless routes for `.html` files. |

Disable either option when initializing the store:

```c3
files.init(tmem, dir, indexing: false, clean_urls: false);
```

With `clean_urls` enabled, `public/about.html` is available at both
`/static/about.html` and `/static/about`. The `index.html` file is excluded
from clean URLs; `indexing` controls whether it is served at the mount prefix.

## Ownership and lifetime

The router borrows static file routes; it does not free them:

- `StaticFiles` owns every `StaticFile` it creates. Call `StaticFiles.free()`
  after the server stops serving requests.
- A standalone `StaticFile` is owned by the caller. Call `StaticFile.free()`
  when the route is no longer needed.
- Keep the store or file alive for as long as its routes may receive requests.

```c3
routing::StaticFiles files;
files.init(tmem, dir);
defer files.free();

router.serve_static("/static", &files)!!;
```

Do not free `files` before `server.run()` returns.

## Response behavior

Static routes are registered as `GET` routes. `HEAD` requests use the same
route and have the response body removed, so clients can inspect file metadata
without downloading the file.

The handler sets `Content-Type` from the file extension. Common types include
HTML, CSS, JavaScript, JSON, XML, plain text, PNG, JPEG, GIF, SVG, WebP, ICO,
PDF, and WebAssembly. Unknown extensions use `application/octet-stream`.

If a registered file disappears from disk, the route returns the standard JSON
404 response:

```json
{"type":"error","status":404}
```

!!! note "Current limitations"

    Static files are read into memory for each request. Range requests,
    conditional requests (`ETag`, `Last-Modified`), compression, and directory
    listings are not implemented.

## See also

- [HTTP methods](http_methods.md) — route matching and HEAD handling.
- [Groups](groups.md) — organize routes under shared prefixes.
- [Configuration overview](../configuration/overview.md) — server settings.
