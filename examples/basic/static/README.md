# Static Files Example

This example serves a fully static site with c3-api.

- Maps `/` to `examples/static/public` with `router.serve_static("/", dir)`.
- Serves `index.html`, `style.css`, and `favicon.svg` directly.

## Files

- `main.c3` - Server setup and static directory registration.
- `public/index.html` - Static page markup.
- `public/style.css` - Styling for the page.
- `public/favicon.svg` - Site icon/logo.

## Run

From the project root:

```bash
c3c run static-demo
```

Then open `http://127.0.0.1:8080/`.

