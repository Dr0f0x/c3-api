# Cookies Example

This example demonstrates how to read and set HTTP cookies in c3-api using a Unix timestamp to track the user's last visit.

- Reads the `lastVisit` cookie from the incoming request.
- Parses the stored Unix timestamp into a `DateTime`.
- Displays the time of the user's previous visit.
- Sets or updates the `lastVisit` cookie on the response.
- Configures cookie attributes such as expiration, `Max-Age`, `Path`, and `Secure`.
- Handles missing or invalid cookie values.

## Files

- `main.c3` - Server setup, cookie handling and route registration.
- `timeutil.c3` - Timestamp parsing

## Run

From the project root:

```bash
c3c run cookie-demo
```

Then open `http://127.0.0.1:8080/` and access:

- `/test`
