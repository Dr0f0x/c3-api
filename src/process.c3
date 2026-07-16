module c3api @private;

import std::io;
import std::net::tcp;
import std::collections::map;
import std::collections::list;
import std::net::os;

import c3api::utils;
import c3api::http;

<*
 Context passed to each worker thread.

 Contains the accepted TCP socket, a pointer to the shared router, and the
 logger instance used to report request and socket lifecycle events.
*>
struct ProcessContext
{
	TcpSocket socket;
	Router* router;

	log::Logger logger;
}

<*
 Process a single accepted connection.

 This worker reads an HTTP request from the socket, performs error handling for
 malformed or unsupported requests, invokes the request handler path, and writes
 the final HTTP response back to the client.

 Additionally it manages a temporary allocator "tmem" with @pool that is alive during the full request handling.
 @param [&in] context_arg : "Process Context to use for handling the connection"
*>
fn int process(void* context_arg) @private
{
	@pool_init(mem, 2 * 1024, 8 * 1024)
	{
		@pool()
		{
			ProcessContext* context = context_arg;
			TcpSocket* socket       = &context.socket;
			Router* router          = context.router;
			log::Logger log         = context.logger;
			defer alloc::free(mem, context);

			defer
			{
				if (catch err = socket.shutdown(SocketShutdownHow.SEND))
				{
					log.errorf(
						"Got Error while shutting down socket %s",
						"Error while shutting down socket",
						log::_error(&err)
					);
				}
				if (catch err = socket.close())
				{
					log.errorf("Got Error while closing socket %s", "Error while closing socket", log::_error(&err));
				}
			}

			http::HttpRequest req;
			req.init(tmem);
			defer req.free();

			http::HttpResponse res;
			res.init(tmem);
			defer res.free();

			if (catch err = req.read(socket))
			{
				if (err == http::INVALID_VERB)
				{
					res.status = HttpStatus.METHOD_NOT_ALLOWED;
				}
				if (err == http::TLS_ON_HTTP_PORT)
				{
					log.errorf("TLS on HTTP Port: %s", "TLS on HTTP Port", log::_error(&err));
					return 1;
				}
				else
				{
					log.errorf("Request Read Error: %s", "Error reading request", log::_error(&err));
					return 1;
				}
			}
			else
			{
				if (catch error = handle(tmem, &req, &res, socket, router, log))
				{
					res.body = "";
					res.status = HttpStatus.INTERNAL_SERVER_ERROR;
				}
			}

			if (catch err = res.write(socket))
			{
				log.errorf("Failed to write: %s", "Failed to write response", log::_error(&err));
			}
		};
	};
	return 0;
}

<*
 Handle an HTTP request after it has been parsed from the socket.

 This method collects middleware, dispatches OPTIONS requests to route discovery,
 dispatches normal requests to the matched handler, and honors HEAD semantics by
 suppressing response bodies after routing completes.

 @param [&inout] allocator : "Allocator used during the request processing"
 @param [&inout] req : "Parsed HTTP request"
 @param [&inout] res : "HTTP response to populate"
 @param [&in] socket : "Client socket associated with the request"
 @param [&in] router : "Router used to resolve routes and middleware"
 @param [&in] logger : "Logger used for request and error logging"
*>
fn void? handle(
	Allocator allocator,
	HttpRequest* req,
	HttpResponse* res,
	TcpSocket* socket,
	Router* router,
	log::Logger logger,
) @private
{
	HandleFunc handler;
	List{MiddlewareFunc} middleware_collector;
	middleware_collector.tinit();

	if (req.method == HttpVerb.OPTIONS)
	{
		logger.trace("Received OPTIONS Request");
		HandlerCollection*? handlers = router.get_handlers(req.uri, req, &middleware_collector);
		if (!run_middlewares(allocator, req, res, &middleware_collector))
		{
			// Middleware interrupted the request, do not continue processing
			return;
		}

		if (catch err = handlers)
		{
			routing::e404(allocator, req, res);
		}
		else
		{
			// set allowed header to registered handlers
			res.headers.add_header_values("Allow", "HEAD, OPTIONS");
			res.status = HttpStatus.NO_CONTENT;
			foreach (i, &value : handlers.handler_map.values)
			{
				if (*value != null)
				{
					res.headers.add_header_value(
						"Allow",
						string::format(allocator, "%s", RouteMethod::from_ordinal(i))
					);
				}
			}
		}
	}
	else if (try method = routing::from_http_verb(req.method))
	{
		handler = router.get_route(method, req.uri, req, &middleware_collector) ?? &routing::e404;
		if (run_middlewares(allocator, req, res, &middleware_collector))
		{
			// Call the handler if middlewares did not interrupt the request
			handler(allocator, req, res);
		}
	}

	// server doesnt support keep-alive yet
	res.headers.set_header_values("Connection", "close");

	if (req.method == HttpVerb.HEAD)
	{
		logger.trace("Received HEAD Request, removing response body");
		res.body = "";
	}
}

<*
 Execute middleware in registration order.

 Middleware can inspect or mutate the request/response and can interrupt
 normal request processing by returning RequestFlow.INTERRUPT.

 @param [&inout] allocator : "Allocator used for temporary middleware allocations"
 @param [&inout] req : "HTTP request passed to each middleware"
 @param [&inout] res : "HTTP response passed to each middleware"
 @param [&in] middlewares : "Middlewares to execute"

 @return "The resulting request flow state"
*>
fn bool run_middlewares(
	Allocator allocator,
	HttpRequest* req,
	HttpResponse* res,
	List{MiddlewareFunc}* middlewares
) @private
{
	foreach (middleware : middlewares)
	{
		RequestFlow flow = middleware(allocator, req, res);
		if (flow == RequestFlow.INTERRUPT)
		{
			return false;
		}
	}
	return true;
}
