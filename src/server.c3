module c3api;

import std::io::path;
import std::net::tcp;
import std::thread;

import c3api::config;
import c3api::routing;

const uint BACKLOG = 10000;

alias DispatchFunc = fn void?(void* dispatcher, RequestProcessFunc process_fn, ProcessContext* context);

struct Server
{
	config::Config* config;

	Context ctx;

	Router router;
	TcpServerSocket server_socket;
	bool should_close;

	union dispatch_opts
	{
		concurrency::PoolDispatcher pool;
		concurrency::PerRequestDispatcher per_request;
	}
	void* dispatcher;
	DispatchFunc dispatch_fn;

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
	self.allocator = allocator;
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
		self.ctx.init(allocator);
		self.config = config;

		self.ctx.register(log::Logger, &self.log);

		if (self.config.cors.enabled)
		{
			self.ctx.register(Config, self.config);
			self.router.use_middleware(&cors);
		}
		if (logger == null)
		{
			self.router.use_middleware(&logging);
		}
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

fn Context* Server.get_context(&self)
{
	return &self.ctx;
}

<*
 Run the server accept loop.

 Binds a listening socket, accepts incoming client connections, and dispatches
 each connection to a detached worker thread using the shared router and logger.
*>
fn void? Server.run(&self)
{
	self.log.debugf(
		"Using concurrency mode %s",
		"Set concurrency mode",
		log::_enum("mode", &self.config.concurrency.mode)
	);
	switch (self.config.concurrency.mode)
	{
		case ConcurrencyMode.THREAD_POOL:
			ConcurrencyConfig* conf = &self.config.concurrency;
			self.dispatch_opts.pool.init(
				self.allocator,
				(int)conf.thread_pool.max_threads,
				conf.thread_pool.queue_capacity,
				conf.thread_pool.keep_alive_ms,
				self.log
			)!;

			self.dispatch_fn = (DispatchFunc)&PoolDispatcher.dispatch;
			self.dispatcher = &self.dispatch_opts.pool;
		case ConcurrencyMode.THREAD_PER_REQUEST:
			self.dispatch_opts.per_request.init(self.allocator, self.log,)!;
			self.dispatch_fn = (DispatchFunc)&PerRequestDispatcher.dispatch;
			self.dispatcher = &self.dispatch_opts.per_request;
	}
	defer
	{
		switch (self.config.concurrency.mode)
		{
			case ConcurrencyMode.THREAD_POOL:
				ConcurrencyConfig* conf = &self.config.concurrency;
				self.dispatch_opts.pool.destroy();
			case ConcurrencyMode.THREAD_PER_REQUEST:
				self.dispatch_opts.per_request.destroy();
		}
	}

	TcpServerSocket? server_socket = tcp::listen(
		self.config.address,
		(int)self.config.port,
		self.config.tcp_backlog,
		net::SocketOption.REUSEADDR,
		ip_protocol: net::IpProtocol.IPV4
	);
	if (catch err = server_socket)
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
		if (catch err = server_socket.close())
		{
			self.log.errorf(
				"Got Error while closing server socket %s",
				"Error while closing server socket",
				log::_error(&err)
			);
		}
	}
	self.server_socket = server_socket;

	self.log.infof(
		"listening on <%s:%d>",
		"server started listening",
		log::_string("address", &self.config.address),
		log::_uint("port", &self.config.port),
	);

	ProcessContext context;
	context.logger = self.log;
	context.ctx = &self.ctx;
	context.router = &self.router;

	while (!self.should_close)
	{
		TcpSocket? socket = tcp::accept(&self.server_socket);
		if (catch err = socket)
		{
			self.log.errorf("accepting connection threw error %s", "could not accept connection", log::_error(&err));
			continue;
		}
		context.socket = socket;

		if (catch err = self.dispatch_fn(self.dispatcher, &process, @clone(context)))
		{
			self.log.errorf("Thread creation failed: %s", "thread creation failed", log::_error(&err));
			close_socket(&socket, self.log);
			continue;
		}
	}
}

fn void close_socket(TcpSocket* socket, log::Logger log) @private
{
	if (catch err = socket.shutdown(SocketShutdownHow.SEND))
	{
		log.errorf("Got Error while shutting down socket %s", "Error while shutting down socket", log::_error(&err));
	}
	if (catch err = socket.close())
	{
		log.errorf("Got Error while closing socket %s", "Error while closing socket", log::_error(&err));
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
