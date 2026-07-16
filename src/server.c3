module c3api;

import c3api::http;
import c3api::log;

module c3api::server @private;

import std::io;
import std::thread;
import std::net::tcp;
import std::collections::list;

import c3api::routing;

const uint BACKLOG = 10000;
bool should_close  = false;

struct ProcessContext
{
	TcpSocket socket;
	log::Logger logger;
	Router router;
}

import c3api::utils;
import c3api::http;
import std::collections::map;

fn int process(void* context_arg)
{
	@pool_init(mem, 2 * 1024, 8 * 1024)
	{
		@pool()
		{
			ProcessContext* context = context_arg;
			TcpSocket* socket       = &context.socket;
			log::Logger* logger     = &context.logger;
			Router* router          = &context.router;

			defer
			{
				if (catch err = socket.close())
				{
					logger.errorf("Socket Closing Error: %s", "Error Closing Socket", log::_error(&err));
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
					logger.errorf("TLS on HTTP Port: %s", "TLS on HTTP Port", log::_error(&err));
					return 1;
				}
				else
				{
					logger.errorf("Request Read Error: %s", "Error reading request", log::_error(&err));
					return 1;
				}
			}
			else
			{
				if (catch error = handle(tmem, &req, &res, socket, router, logger))
				{
					res.body = "";
					res.status = HttpStatus.INTERNAL_SERVER_ERROR;
				}
			}

			io::printfn("%s", res);
			if (catch err = res.write(socket))
			{
				logger.errorf("Failed to write: %s", "Failed to write response", log::_error(&err));
			}
		};
	};

	return 0;
}

fn void? handle(
	Allocator allocator,
	HttpRequest* req,
	HttpResponse* res,
	TcpSocket* socket,
	Router* router,
	log::Logger* logger,
) @private
{
	if (cors_config.enabled)
	{
		if (req.method == HttpVerb.OPTIONS)
		{
			res.status = HttpStatus.OK;
			res.body = `{"status":200}`;

			res.headers.set_header_value("Access-Control-Allow-Methods", cors_config.allow_methods);
			res.headers.set_header_value("Access-Control-Allow-Headers", cors_config.allow_headers);

			res.headers.set_header_value("Content-Type", "application/json");
		}
		else
		{
			HandleFunc handler;
			List{MiddlewareFunc} middleware_collector;
			middleware_collector.tinit();

			if (try method = routing::from_http_verb(req.method))
			{
				handler = router.get_route(method, req.uri, req, &middleware_collector) ?? &routing::e404;
				handler(tmem, req, res);
			}
		}
		res.headers.set_header_value("Access-Control-Allow-Origin", cors_config.allow_origin);
	}
	else
	{
		HandleFunc handler;
		List{MiddlewareFunc} middleware_collector;
		middleware_collector.tinit();

		io::printfn("%s", req);
		if (req.method == HttpVerb.OPTIONS)
		{
			io::printn("in options");
			HandlerCollection*? handlers = router.get_handlers(req.uri, req, &middleware_collector);
			if (!run_middlewares(tmem, req, res, middleware_collector))
			{
				// Middleware interrupted the request, do not continue processing
				return;
			}

			if (catch err = handlers)
			{
				routing::e404(tmem, req, res);
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
						res.headers.add_header_value("Allow", string::format(tmem, "%s", RouteMethod::from_ordinal(i)));
					}
				}
			}
		}
		else if (try method = routing::from_http_verb(req.method))
		{
			handler = router.get_route(method, req.uri, req, &middleware_collector) ?? &routing::e404;
			if (run_middlewares(tmem, req, res, middleware_collector))
			{
				// Call the handler if middlewares did not interrupt the request
				handler(tmem, req, res);
			}
		}
	}

	if (req.method == HttpVerb.HEAD)
	{
		res.body = "";
	}
}

fn bool run_middlewares(
	Allocator allocator,
	HttpRequest* req,
	HttpResponse* res,
	List{MiddlewareFunc} middleware_collector
) @private
{
	foreach (middleware : middleware_collector)
	{
		RequestFlow flow = middleware(allocator, req, res);
		if (flow == RequestFlow.INTERRUPT)
		{
			return false;
		}
	}
	return true;
}

import std::collections::object;

import c3api::config;
import c3api::log;
import c3api::os::win32;

config::CorsConfig cors_config;
log::Logger server_logger;

fn void? startServer(config::Config config, Router router, log::Logger logger = null) @public
{
	@pool()
	{
		cors_config = config.cors;

		ConsoleSink* console_sink;
		FileSink* file_sink;
		C3ApiLogger* default_logger;
		defer if (console_sink) console_sink.free();
		defer if (file_sink) file_sink.free();
		defer if (default_logger) default_logger.free();

		if (!logger)
		{
			default_logger = alloc::new(tmem, C3ApiLogger);
			default_logger.init(mem);


			if (config.logging.console.enabled)
			{
				console_sink = alloc::new(tmem, ConsoleSink);
				console_sink.init();
				default_logger.add_sink(console_sink, log::min_level_enabler(config.logging.console.min_level));
			}

			if (config.logging.file.enabled)
			{
				file_sink = alloc::new(tmem, FileSink);
				if (try error = file_sink.init(path::tnew("c3api.log")!!))
				{
					default_logger.add_sink(file_sink, log::min_level_enabler(config.logging.file.min_level));
				}
			}

			server_logger = default_logger;
		}
		else
		{
			server_logger = logger;
		}

		win32::startWSA(server_logger);

		TcpServerSocket? server = tcp::listen(
			config.address,
			(int)config.port,
			BACKLOG,
			net::SocketOption.REUSEADDR,
			ip_protocol: net::IpProtocol.IPV4
		);
		if (catch err = server)
		{
			server_logger.errorf(
				"failed to bind <%s:%d> with failure: %s",
				"failed to bind adress",
				log::_string("adress", &config.address),
				log::_uint("port", &config.port),
				log::_error(&err)
			);
			return;
		}
		defer
		{
			server_logger.info("Closing server...");
			server.close()!!;
			win32::stopWSA(server_logger);
		}

		server_logger.infof(
			"listening on <%s:%d>",
			"server started listening",
			log::_string("address", &config.address),
			log::_uint("port", &config.port),
		);

		while (!should_close)
		{
			TcpSocket? socket = tcp::accept(&server);
			if (catch err = socket)
			{
				should_close = true;
				server_logger.errorf(
					"accepting connection threw error %s",
					"could not accpet connection",
					log::_error(&err)
				);
				win32::lastWSAErrorOut(server_logger);
				continue;
			}

			ProcessContext context;
			context.socket = socket;
			context.logger = server_logger;
			context.router = router;

			thread::Thread thread;
			thread.create(&process, @clone(context))!!;
			thread.detach()!!;
		}
	};
}
