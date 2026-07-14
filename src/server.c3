module c3api;

import c3api::http;
import c3api::log;

struct ControllerParadise
{
	bool _ignore;
}

alias Cref = ControllerParadise*;

macro @controller(uri)
{
	@tag("controller", uri);
}
macro @file(uri)
{
	@tag("file", uri);
}
macro @folder(uri)
{
	@tag("folder", uri);
}

macro bool @method_has_tag(#self, $method, $tag)
{
	return $typeof(*#self).$eval($method).has_tagof($tag);
}

/* fn void ControllerParadise.init(ControllerParadise* self) {
    $foreach($method : $typeof(*self).methodsof)
        $if @method_has_tag(self, $method, "controller"):
            var $tag = $typeof(*self).$eval($method).tagof("controller");
            routes::add_route($tag, &$typeof(*self).$eval($method));
            routes::add_tag($tag, "controller", $tag);
            $if @method_has_tag(self, $method, "file"):
                var $filetag = $typeof(*self).$eval($method).tagof("file");
                routes::add_tag($tag, "file", $filetag);
            $else
                $if @method_has_tag(self, $method, "folder"):
                    var $foldertag = $typeof(*self).$eval($method).tagof("folder");
                    routes::add_tag($tag, "folder", $foldertag);
                $endif
            $endif
        $endif
    $endforeach
} */

module c3api::server @private;

import std::io;
import std::thread;
import std::net::tcp;

import c3api::routing;

const uint BACKLOG = 10000;
bool should_close  = false;

struct ProcessContext
{
	TcpSocket socket;
	log::Logger logger;
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

			defer
			{
				if (catch err = socket.close())
				{
					logger.errorf("Socket Closing Error: %s", "Error Closing Socket", log::_error(err));
				}
			}

			http::HttpRequest req;
			req.init(tmem);
			defer req.free();

			if (catch err = req.read(socket))
			{
				logger.errorf("Request Read Error: %s", "Error reading request", log::_error(err));
				return 1;
			}

			String uri = req.uri;
			if (uri.len > 0 && uri[0] == '/') uri = uri[1..];
			logger.infof("URI: '%s'", uri);

			HashMap{String, String} args;
			args.init(mem);
			defer args.free();

			// TODO doesnt work rn
			// Object* tags = routing::tagsMap[args["reverse_path"]!!] ?? null;

			http::HttpResponse res;
			res.init(tmem);
			defer res.free();

			/* if (tags != null)
			{
				if ((tags.get_string("file") ?? "") != "")
				{
					args["filename"] = utils::format_path(
						tags.get_string("file")!!,
						&args
					) ?? tags.get_string("file")!!;
					route = &routes::file;
				}
				else if ((tags.get_string("folder") ?? "") != "")
				{
					String folder = tags.get_string("folder")!!;
					args["foldername"] = utils::format_path(folder, &args) ?? folder;
					route = &routes::folder;
				}
			} */

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
					RouteFunction route;
					route = routing::get_route(uri, &args);
					res = route(null, req, args);
				}
				res.headers.set_header_value("Access-Control-Allow-Origin", cors_config.allow_origin);
			}
			else
			{
				RouteFunction route;
				route = routing::get_route(uri, &args);
				res = route(null, req, args);
			}

			if (catch err = res.write(socket))
			{
				logger.errorf("Failed to write: %s", "Failed to write response", log::_error(err));
			}
		};
	};

	return 0;
}

import std::collections::object;

import c3api::config;
import c3api::log;
import c3api::os::win32;

config::CorsConfig cors_config;
log::Logger server_logger;

fn void? startServer(config::Config config, log::Logger logger = null) @public
{
	@pool()
	{
		cors_config = config.cors;

		if (!logger)
		{
			C3ApiLogger* default_logger = alloc::new(tmem, C3ApiLogger);
			default_logger.init(mem);

			ConsoleSink* console_sink = alloc::new(tmem, ConsoleSink);
			console_sink.init();

			default_logger.add_sink(console_sink, log::min_level_enabler(log::LogLevel.INFO));

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
				log::_string("adress", config.address),
				log::_uint("port", config.port),
				log::_error(err)
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
			log::_string("adress", config.address),
			log::_uint("port", config.port),
		);

		while (!should_close)
		{
			TcpSocket? socket = tcp::accept(&server);
			if (catch err = socket)
			{
				should_close = true;
				server_logger.errorf("accepting connection threw error %s", "could not accpet connection", log::_error(err));
				win32::lastWSAErrorOut(server_logger);
				continue;
			}

			ProcessContext context;
			context.socket = socket;
			context.logger = server_logger;

			thread::Thread thread;
			thread.create(&process, @clone(context))!!;
			thread.detach()!!;
		}
	};
}
