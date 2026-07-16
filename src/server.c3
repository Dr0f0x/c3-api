module c3api;

import std::io::path;
import std::net::tcp;
import std::thread;

import c3api::config;
import c3api::routing;

const uint BACKLOG = 10000;

struct Server
{
	config::Config* config;

	Router router;
	TcpServerSocket server_socket;
	bool should_close;

	log::Logger log;

	struct default_logging
	{
		C3ApiLogger* logger;
		ConsoleSink* console_sink;
		FileSink* file_sink;
	}

	Allocator allocator;
}

<*
 Initialize the Server instance.

 If no logger is supplied, this method sets up a default logger with console and
 file sinks according to the provided configuration.

 @param [&inout] allocator : "Allocator to use for internal allocations"
 @param [&in] config : "Server Configuration to use"
 @param [&in] logger : "Logger to use"

 @return "Initialized Server instance"
*>
fn Server* Server.init(&self, Allocator allocator, Config* config, log::Logger logger = null)
{
	@pool()
	{
		if (!logger)
		{
			self.default_logging.logger = alloc::new(allocator, C3ApiLogger);
			self.default_logging.logger.init(mem);

			if (config.logging.console.enabled)
			{
				self.default_logging.console_sink = alloc::new(allocator, ConsoleSink);
				self.default_logging.console_sink.init();
				self.default_logging.logger.add_sink(
					self.default_logging.console_sink,
					log::min_level_enabler(config.logging.console.min_level)
				);
			}

			if (config.logging.file.enabled)
			{
				self.default_logging.file_sink = alloc::new(allocator, FileSink);
				if (try error = self.default_logging.file_sink.init(path::tnew("c3api.log")!!))
				{
					self.default_logging.logger.add_sink(
						self.default_logging.file_sink,
						log::min_level_enabler(config.logging.file.min_level)
					);
				}
			}

			self.log = self.default_logging.logger;
		}

		self.router.init(allocator, self.log);
		self.config = config;
		return self;
	};
}

<*
 Get the router this Server uses.

 @return "The Router instance"
*>
fn Router* Server.get_router(&self)
{
	return &self.router;
}

<*
 Run the server accept loop.

 Binds a listening socket, accepts incoming client connections, and dispatches
 each connection to a detached worker thread using the shared router and logger.
*>
fn void? Server.run(&self)
{
	TcpServerSocket? server = tcp::listen(
		self.config.address,
		(int)self.config.port,
		self.config.tcp_backlog,
		net::SocketOption.REUSEADDR,
		ip_protocol: net::IpProtocol.IPV4
	);
	if (catch err = server)
	{
		self.log.errorf(
			"failed to bind <%s:%d> with failure: %s",
			"failed to bind adress",
			log::_string("adress", &self.config.address),
			log::_uint("port", &self.config.port),
			log::_error(&err)
		);
		return;
	}
	defer
	{
		self.log.info("Closing server...");
		server.close()!!;
	}
	self.server_socket = server;

	self.log.infof(
		"listening on <%s:%d>",
		"server started listening",
		log::_string("address", &self.config.address),
		log::_uint("port", &self.config.port),
	);

	ProcessContext context;
	context.logger = self.log;
	context.router = &self.router;

	while (!self.should_close)
	{
		TcpSocket? socket = tcp::accept(&server);
		if (catch err = socket)
		{
			self.should_close = true;
			self.log.errorf("accepting connection threw error %s", "could not accept connection", log::_error(&err));
			continue;
		}
		context.socket = socket;

		thread::Thread thread;
		thread.create(&process, @clone(context))!!;
		thread.detach()!!;
	}
}

<*
 Free any resources owned by the Server.

 This cleans up the allocated logger and any configured if no custom one was provided in init
*>
fn void Server.free(&self)
{
	if (self.default_logging.logger != null) self.default_logging.logger.free();
	if (self.default_logging.file_sink != null) self.default_logging.file_sink.free();
	if (self.default_logging.console_sink != null) self.default_logging.console_sink.free();
}
