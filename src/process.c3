// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module c3api @private;

import std::io;
import std::net::tcp;
import std::net;
import std::collections::map;
import std::collections::list;
import std::net::os;

import c3api::http;
import c3api::routing;
import c3api::http::request;
import c3api::http::response;

<*
 Context passed to each worker thread.

 Contains the accepted TCP socket, a pointer to the shared router, and the
 logger instance used to report request and socket lifecycle events.
*>
struct ProcessContext
{
	TcpSocket socket;
	Router* router;
	Context* initial_ctx;
	Config* conf;

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
fn void process(ProcessContext* context_arg) @private
{
	@stack_mem(2 * 1024 ; Allocator allocator)
	{
		@pool_init(allocator, 2 * 1024, 8 * 1024)
		{
			@pool()
			{
				ProcessContext* context = context_arg;
				TcpSocket* socket       = &context.socket;
				Router* router          = context.router;
				Context* initial_ctx    = context.initial_ctx;
				Config* conf            = context.conf;
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
						log.errorf(
							"Got Error while closing socket %s",
							"Error while closing socket",
							log::_error(&err)
						);
					}
				}

				request::HttpRequest req;
				req.init(tmem);
				defer req.free();

				response::HttpResponse res;
				res.init(tmem);
				defer res.free();

				context::Context ctx;
				ctx.init(tmem);
				ctx.add_from(initial_ctx);
				defer ctx.free();

				if (conf.http.keep_alive.enabled)
				{
					process_keep_alive(tmem, conf, &ctx, &req, &res, socket, router, log);
				}
				else
				{
					process_single(tmem, conf, &ctx, &req, &res, socket, router, log);
				}
			};
		};
	};
}

enum ProcessResult
{
	CONTINUE,
	CLOSE,
	ERROR
}

fn ProcessResult process_single(
	Allocator allocator,
	Config* conf,
	Context* ctx,
	HttpRequest* req,
	HttpResponse* res,
	TcpSocket* socket,
	Router* router,
	log::Logger log
) @private
{
	// check idle timeout
	Poll[] p = { { .socket = socket.sock, .events = PollSubscribe.ANY_READ, } };

	ulong? ready = net::poll_ms(p, (long)conf.http.keep_alive.idle_timeout_ms);
	if (catch err = ready)
	{
		log.errorf("Poll failed: %s", "Poll failed", log::_error(&err));
		return ProcessResult.ERROR;
	}

	if (ready == 0)
	{
		return ProcessResult.CLOSE;
	}

	// handle errors when reading
	if (catch err = req.read(socket, conf.http.max_read_size, 1))
	{
		res.headers.set_header_values("Connection", "close");

		if (err == http::INVALID_VERB)
		{
			res.status = HttpStatus.METHOD_NOT_ALLOWED;
		}
		else if (err == http::MALFORMED_REQUEST)
		{
			res.status = HttpStatus.BAD_REQUEST;
		}
		else if (err == http::TLS_ON_HTTP_PORT)
		{
			// Cannot safely respond with HTTP because the client is speaking TLS.
			log.errorf("TLS on HTTP Port: %s", "TLS on HTTP Port", log::_error(&err));
			return ProcessResult.ERROR;
		}
		else
		{
			return ProcessResult.ERROR;
		}

		if (catch write_err = res.write(socket, 1))
		{
			log.errorf("Failed to write: %s", "Failed to write response", log::_error(&write_err));
		}

		return ProcessResult.CLOSE;
	}

	// handle trace verb and regular method
	ProcessResult result;
	if (req.method == HttpVerb.TRACE)
	{
		if (conf.http.trace_enabled)
		{
			DString out = dstring::new_with_capacity(allocator, 256);

			out.appendfn("%s %s HTTP/1.1", req.method, req.uri);

			req.headers.@each(; String key, List{String} values)
			{
				foreach (value : values)
				{
					out.appendfn("%s: %s", key, value);
				}
			};

			out.append("\r\n");

			if (req.body.len > 0)
			{
				out.append(req.body);
			}

			res.status = HttpStatus.OK;
			res.body = out.str_view();
		}
		else
		{
			res.status = HttpStatus.METHOD_NOT_ALLOWED;
			res.headers.set_header_values("Connection", "close");
			res.body = "";
			result = ProcessResult.CLOSE;
		}
	}
	else if (catch error = handle(allocator, ctx, req, res, socket, router, log))
	{
		res.body = "";
		res.status = HttpStatus.INTERNAL_SERVER_ERROR;
		result = ProcessResult.ERROR;
	}


	// check if clients wants to close
	bool close_connection = result == ProcessResult.CLOSE;

	if (try values = req.headers.get_header_values("Connection"))
	{
		foreach (value : values)
		{
			if (value.compare_to_ignore_case("close") == 0)
			{
				close_connection = true;
				break;
			}
		}
	}

	if (close_connection)
	{
		res.headers.set_header_values("Connection", "close");
	}

	// write response
	if (catch err = res.write(socket, 1))
	{
		log.errorf("Failed to write: %s", "Failed to write response", log::_error(&err));
		return ProcessResult.ERROR;
	}

	if (result != ProcessResult.CONTINUE)
	{
		return result;
	}
	return close_connection ? ProcessResult.CLOSE : ProcessResult.CONTINUE;
}

fn void process_keep_alive(
	Allocator allocator,
	Config* conf,
	Context* ctx,
	HttpRequest* req,
	HttpResponse* res,
	TcpSocket* socket,
	Router* router,
	log::Logger log
) @private
{
	sz done_requests = 0;
	bool loop        = true;

	while (done_requests < conf.http.keep_alive.max_requests_per_connection)
	{
		ProcessResult result = process_single(allocator, conf, ctx, req, res, socket, router, log);

		done_requests++;

		if (result != ProcessResult.CONTINUE)
		{
			break;
		}

		req.reset();
		res.reset();
	}
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
	Context* ctx,
	HttpRequest* req,
	HttpResponse* res,
	TcpSocket* socket,
	Router* router,
	log::Logger logger,
) @private
{
	RegisteredHandler* registered_handler;
	List{RegisteredMiddleware} middleware_collector;
	middleware_collector.tinit();

	if (req.method == HttpVerb.OPTIONS)
	{
		logger.trace("Received OPTIONS Request");
		HandlerCollection*? handlers = router.get_handlers(req.uri, req, &middleware_collector);
		if (!run_middlewares(allocator, ctx, req, res, &middleware_collector))
		{
			// Middleware interrupted the request, do not continue processing
			return;
		}

		if (catch err = handlers)
		{
			routing::handler::e404(null, allocator, ctx, req, res);
		}
		else
		{
			// set allowed header to registered handlers
			res.headers.add_header_values("Allow", "HEAD, OPTIONS");
			res.status = HttpStatus.NO_CONTENT;
			foreach (i, &value : handlers.handler_map.values)
			{
				if (value.handler != null)
				{
					res.headers.add_header_value(
						"Allow",
						string::format(allocator, "%s", RouteMethod::from_ordinal(i))
					);
				}
			}
		}
	}
	else if (try method = routing::route_method_from_http_verb(req.method))
	{
		registered_handler = router.get_route(method, req.uri, req, &middleware_collector) ?? null;
		if (registered_handler == null)
		{
			routing::handler::e404(null, allocator, ctx, req, res);
		}
		else if (run_middlewares(allocator, ctx, req, res, &middleware_collector))
		{
			// Call the handler if middlewares did not interrupt the request
			registered_handler.handler(registered_handler.self, allocator, ctx, req, res);
		}
	}

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

 @return "false if the middleware chain produced an INTERRUPT, e.g. proessing should not continue, true otherwise"
*>
fn bool run_middlewares(
	Allocator allocator,
	Context* ctx,
	HttpRequest* req,
	HttpResponse* res,
	List{RegisteredMiddleware}* middlewares
) @private
{
	RequestFlow flow;
	foreach (registered : middlewares)
	{
		flow = registered.middleware(registered.self, allocator, ctx, req, res);

		if (flow == RequestFlow.INTERRUPT)
		{
			return false;
		}
	}
	return true;
}