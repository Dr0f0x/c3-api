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

 Contains the accepted TCP socket, pointers to the shared router, initial
 request context and server configuration, and the logger instance used to
 report request and socket lifecycle events.
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

<*
 Outcome of processing a single request.

 `CONTINUE` keeps the connection open for another request, `CLOSE` closes it
 after the response has been written, and `ERROR` aborts the connection.
*>
enum ProcessResult
{
	CONTINUE,
	CLOSE,
	ERROR
}

<*
 Poll, read, and process a single request on a connection.

 Applies the keep-alive idle timeout and read-error handling, answers TRACE
 requests directly, and otherwise runs the routing pipeline through `handle`.
 Writes the response and reports how the connection should proceed.

 @param [&inout] allocator : "Allocator used during the request processing"
 @param [&in] conf : "Server configuration"
 @param [&inout] ctx : "Request pipeline context"
 @param [&inout] req : "Request buffer to read into"
 @param [&inout] res : "Response buffer to populate"
 @param [&inout] socket : "Client socket"
 @param [&in] router : "Router used to resolve routes and middleware"
 @param [&in] log : "Logger used for request and error logging"
 @return "Outcome for the connection after the request"
*>
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
	Poll[] p = {
		{
			.socket = socket.sock,
			.events = PollSubscribe.ANY_READ,
		}
	};

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

<*
 Process requests on a keep-alive connection.

 Reuses the same request, response, and context buffers until the configured
 request limit is reached or a request asks to close the connection.

 @param [&inout] allocator : "Allocator used during the request processing"
 @param [&in] conf : "Server configuration"
 @param [&inout] ctx : "Request pipeline context"
 @param [&inout] req : "Request buffer to reuse"
 @param [&inout] res : "Response buffer to reuse"
 @param [&inout] socket : "Client socket"
 @param [&in] router : "Router used to resolve routes and middleware"
 @param [&in] log : "Logger used for request and error logging"
*>
fn void process_keep_alive(
	Allocator allocator,
	Config* conf,
	Context* ctx,
	HttpRequest* req,
	HttpResponse* res,
	TcpSocket* socket,
	Router* router,
	log::Logger log,
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

 Collects the middleware chain for the matched route and runs it through the
 context pipeline (`setup_handling` / `next`). OPTIONS requests are answered
 from route discovery, unmatched routes fall back to the built-in 404 handler,
 and HEAD requests have their response body suppressed after routing.

 @param [&inout] allocator : "Allocator used during the request processing"
 @param [&inout] ctx : "Request pipeline context"
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

	HandlerContext handler_ctx = { .context = ctx };

	if (req.method == HttpVerb.OPTIONS)
	{
		logger.trace("Received OPTIONS Request");
		HandlerCollection*? handlers = router.get_handlers(req.uri, req, &middleware_collector);

		ctx.setup_handling(middleware_collector.array_view(), null);
		ctx.next(allocator, req, res);

		if (catch err = handlers)
		{
			routing::handler::e404(null, allocator, &handler_ctx, req, res);
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
			routing::handler::e404(null, allocator, &handler_ctx, req, res);
		}
		else
		{
			ctx.setup_handling(middleware_collector.array_view(), registered_handler);
			ctx.next(allocator, req, res);
		}
	}

	if (req.method == HttpVerb.HEAD)
	{
		logger.trace("Received HEAD Request, removing response body");
		res.body = "";
	}
}