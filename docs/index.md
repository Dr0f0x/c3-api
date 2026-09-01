# Welcome to MkDocs

For full documentation visit [mkdocs.org](https://www.mkdocs.org).

## C3 syntax highlighting

```c3
module app;

import c3api;

// Respond to GET /health requests.
fn void health(void* self, Allocator allocator, Context* ctx,
               HttpRequest* req, HttpResponse* res)
{
    res.status = HttpStatus.OK;
    res.body = "c3-api is running!";
}
```

## Commands

* `mkdocs new [dir-name]` - Create a new project.
* `mkdocs serve` - Start the live-reloading docs server.
* `mkdocs build` - Build the documentation site.
* `mkdocs -h` - Print help message and exit.

## Project layout

    mkdocs.yml    # The configuration file.
    docs/
        index.md  # The documentation homepage.
        ...       # Other markdown pages, images and other files.