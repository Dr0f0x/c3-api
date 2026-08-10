# Todo Web App Example

This example is a simple Todo web app built with c3-api.

- Backend API routes are implemented in [examples/todo/main.c3](examples/todo/main.c3).
- Frontend pages and assets are served from [examples/todo/public](examples/todo/public).


pwsh commands ot test differenct encodings with curl

**json**
```pwsh
'{ "title": "test", "description": "test", "completed": false }' | curl.exe -v --http1.1 -X POST "http://127.0.0.1:8080/todo" -H "Content-Type: application/json" -H "Transfer-Encoding: chunked" --data-binary "@-"
```

**xml**
```pwsh
'<request><title>test</title><description>test</description><completed>false</completed></request>' | curl.exe -v --http1.1 -X POST "http://127.0.0.1:8080/todo" -H "Content-Type: application/xml" -H "Transfer-Encoding: chunked" --data-binary "@-"
```

**form**
```pwsh
'title=test&description=test&completed=false' | curl.exe -v --http1.1 -X POST "http://127.0.0.1:8080/todo" -H "Content-Type: application/x-www-form-urlencoded" --data-binary "@-"
```