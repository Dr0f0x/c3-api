# Logger Example

This example demonstrates how to configure logging in c3-api and implement a custom log sink.

- Initializes the c3-api logger with configurable console and file log levels.
- Adds the built-in console sink for terminal output.
- Implements a custom `RotatingFileSink` and adds it to the logger.
- Starts the server with the configured logger attached.

## Files

- `main.c3` - Server setup, logger configuration, sink registration, and route registration.
- `rotating_file_sink.c3` - Custom rotating file sink implementation.

## Run

From the project root:

```bash
c3c run logger-demo
```

Then open: `http://127.0.0.1:8080/` and acess `/test`

The request and server logs will be written to the console and to the rotating log files under:

```
log/
```

For example:

```
log/c3api-2026-08-11_22-40-18.log
log/c3api-2026-08-11_22-45-03.log
```

Try triggering the endpoint repeatedly to see the file rotation in action.
