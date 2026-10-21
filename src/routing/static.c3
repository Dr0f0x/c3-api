// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module c3api::routing;

import std::io::path;
import std::collections::list;
import std::collections::map;
import std::io::file;
import std::core::mem::allocators;

import c3api::http;
import c3api::log;
import c3api::context;
import c3api::routing::internal;

<*
 Register static files below a router path.

 The path and directory options are stored in `files` by `StaticFiles.init`.
 The router borrows the static file instances stored in `files`; it does
 not free them. Keep `files` alive while the routes may be served and
 release it with `StaticFiles.free`.

 @param [&inout] self : "Router receiving static file routes"
 @param uri : "URI prefix for the files"
 @param [&inout] files : "User-owned static file storage configured with a path and options"
 @return "Success or a file error"
*>
fn void? Router.serve_static(&self, String uri, StaticFiles* files)
{
	return routing::serve_static(
		files,
		uri,
		&self.root_handlers,
		&self.root_middlewares,
		&self.root_nodes,
		self.log
	);
}

<*
 Register one static file below a router path.

 The file path is stored in `file` by `StaticFile.init`. The router borrows
 `file`; it does not free it. Keep `file` alive while the route may be
 served and release it with `StaticFile.free`.

 @param [&inout] self : "Router receiving the static file route"
 @param uri : "Route URI"
 @param [&inout] file : "User-owned static file storage configured with a file path"
 @return "Success or a file error"
*>
fn void? Router.serve_static_file(&self, String uri, StaticFile* file)
{
	return routing::serve_static_file(
		uri,
		file,
		&self.root_handlers,
		&self.root_middlewares,
		&self.root_nodes,
		self.log
	);
}

<*
 Register static files below a group path.

 The path and directory options are stored in `files` by `StaticFiles.init`.
 The router borrows the static file instances stored in `files`; it does
 not free them. Keep `files` alive while the routes may be served and
 release it with `StaticFiles.free`.

 @param [&inout] self : "Group receiving static file routes"
 @param uri : "URI prefix for the files"
 @param router : "Router owning the route storage"
 @param [&inout] files : "User-owned static file storage configured with a path and options"
 @return "Success or a file error"
*>
fn void? Group.serve_static(&self, String uri, Router* router, StaticFiles* files)
{
	return routing::serve_static(
		files,
		uri,
		&router.root_handlers,
		&router.root_middlewares,
		&router.root_nodes,
		self.log
	);
}

<*
 Register one static file below a group path.

 The file path is stored in `file` by `StaticFile.init`. The router borrows
 `file`; it does not free it. Keep `file` alive while the route may be
 served and release it with `StaticFile.free`.

 @param [&inout] self : "Group receiving the static file route"
 @param uri : "Route URI relative to the group"
 @param [&inout] file : "User-owned static file storage configured with a file path"
 @return "Success or a file error"
*>
fn void? Group.serve_static_file(&self, String uri, StaticFile* file)
{
	return routing::serve_static_file(
		uri,
		file,
		&self.node.handlers,
		&self.node.middlewares,
		&self.node.sub_nodes,
		self.log
	);
}

<*
 Register static files in route storage.

 @param [&inout] files : "User-owned storage configured with a path and options"
 @param uri : "URI prefix for the files"
 @param handlers : "Handler collection receiving file handlers"
 @param middlewares : "Middleware collection for the routes"
 @param nodes : "Route node map"
 @param log : "Logger"
 @return "Success or a file error"
*>
fn void? serve_static(
	StaticFiles* files,
	String uri,
	HandlerCollection* handlers,
	List{RegisteredMiddleware}* middlewares,
	HashMap{String, RouteNode}* nodes,
	log::Logger log
) @private
{
	if (path::is_file(files.path))
	{
		register_static_file(files, uri, files.path, handlers, middlewares, nodes, log);
		return;
	}

	if (!path::is_dir(files.path))
	{
		log.errorf(
			"Path %s for static serving not found",
			"path for static not found",
			log::_string("path", &files.path)
		);
		return io::FILE_NOT_FOUND~;
	}

	StaticWalkData data = {
		.files = files,
		.base = files.path,
		.uri = uri,
		.indexing = files.indexing,
		.clean_urls = files.clean_urls,
		.handlers = handlers,
		.middlewares = middlewares,
		.nodes = nodes,
		.log = log
	};

	files.path.walk(&register_static_entry, &data)!;

	if (files.indexing)
	{
		Path index = files.path.append(tmem, "index.html")!;
		if (path::is_file(index))
		{
			register_static_file(files, uri, index, handlers, middlewares, nodes, log);
		}
	}
}

<*
 Register one static file in route storage.

 @param uri : "Route URI"
 @param [&inout] file : "User-owned static file storage configured with a file path"
 @param handlers : "Handler collection receiving the file handler"
 @param middlewares : "Middleware collection for the route"
 @param nodes : "Route node map"
 @param log : "Logger"
 @return "Success or a file error"
*>
fn void? serve_static_file(
	String uri,
	StaticFile* file,
	HandlerCollection* handlers,
	List{RegisteredMiddleware}* middlewares,
	HashMap{String, RouteNode}* nodes,
	log::Logger log
) @private
{
	if (!path::is_file(file.path))
	{
		log.errorf(
			"Path %s for static file serving not found",
			"path for static file not found",
			log::_string("path", &file.path)
		);
		return io::FILE_NOT_FOUND~;
	}

	if (file.uri.len > 0) file.uri.free(file.allocator);
	file.uri = uri.copy(file.allocator);

	log.tracef(
		"adding file handler for uri: %s path %s",
		"adding file handler",
		log::_string("uri", &file.uri),
		log::_string("path", &file.path)
	);

	internal::_add_handler(
		file.uri,
		RouteMethod.GET,
		(HandleFunc)&serve_file,
		file,
		{ },
		handlers,
		middlewares,
		nodes,
		log
	);
}

<* State shared while walking a static file directory. *>
struct StaticWalkData @private
{
	StaticFiles* files;
	Path base;
	String uri;
	bool indexing;
	bool clean_urls;

	HandlerCollection* handlers;
	List{RegisteredMiddleware}* middlewares;
	HashMap{String, RouteNode}* nodes;
	log::Logger log;
}

<*
 Register one static file encountered during a directory walk.

 @param file : "File path encountered"
 @param is_dir : "Whether the path is a directory"
 @param data_ptr : "Static walk state"
 @return "Whether directory walking should stop"
*>
fn bool? register_static_entry(Path file, bool is_dir, void* data_ptr) @private
{
	if (is_dir) return false;

	StaticWalkData* data = data_ptr;

	String relative = file[data.base.len + 1..].replace(tmem, "\\", "/");

	DString route = dstring::temp();
	route.append(data.uri);
	if (data.uri != "/") route.append("/");

	route.append(relative);

	String file_uri = route.str_view();

	register_static_file(
		data.files,
		file_uri,
		file,
		data.handlers,
		data.middlewares,
		data.nodes,
		data.log
	);

	if (data.clean_urls && file.has_extension("html") && file.basename() != "index.html")
	{
		// /files/main.html -> /files/main
		String clean = file_uri[0..file_uri.len - 6];

		register_static_file(
			data.files,
			clean,
			file,
			data.handlers,
			data.middlewares,
			data.nodes,
			data.log
		);
	}

	return false;
}

<*
 Register one file-backed GET route.

 @param [&inout] files : "User-owned store receiving the static file instance"
 @param uri : "Route URI"
 @param path : "File path"
 @param handlers : "Handler collection receiving the file handler"
 @param middlewares : "Middleware collection for the route"
 @param nodes : "Route node map"
 @param log : "Logger"
*>
fn void register_static_file(
	StaticFiles* files,
	String uri,
	Path path,
	HandlerCollection* handlers,
	List{RegisteredMiddleware}* middlewares,
	HashMap{String, RouteNode}* nodes,
	log::Logger log
) @private
{
	StaticFile* static_file = add_static_file(files, uri, path);

	log.tracef(
		"adding file handler for uri: %s path %s",
		"adding file handler",
		log::_string("uri", &uri),
		log::_string("path", &path)
	);

	internal::_add_handler(
		static_file.uri,
		RouteMethod.GET,
		(HandleFunc)&serve_file,
		static_file,
		{ },
		handlers,
		middlewares,
		nodes,
		log
	);
}

<*
 File-backed handler state for a registered static route.

 Initialize it with `StaticFile.init`, register it with
 `Router.serve_static_file` or `Group.serve_static_file`, and release it with
 `StaticFile.free`. Registration copies the route URI into the instance so the
 router's route key stays valid for the lifetime of the instance. A
 `StaticFile` does not reference its router, so the router and the static file
 storage can be released independently after the server stops serving requests.
*>
struct StaticFile
{
	Allocator allocator;
	String uri;
	Path path;
}

<*
 Initialize a single static file handler instance.

 The file path is copied with `allocator`. The route URI is copied when the
 instance is registered with `Router.serve_static_file` or
 `Group.serve_static_file`. The caller owns the storage for `self`; use
 `StaticFiles.add_file` for a store-owned heap instance.

 @param [&inout] self : "Static file handler state to initialize"
 @param [&inout] allocator : "Allocator used for the copied path and route URI"
 @param path : "File path to copy"
 @return "Initialized static file handler state"
*>
fn StaticFile* StaticFile.init(&self, Allocator allocator, Path path)
{
	self.allocator = allocator;
	self.uri = "";
	self.path = path.copy(allocator);
	return self;
}

<*
 Free the route URI and file path owned by this instance.

 The URI is copied when the instance is registered. This function does not
 free the `StaticFile` instance itself. Store-owned instances are released by
 `StaticFiles.free`.

 @param [&inout] self : "Static file handler state to free"
*>
fn void StaticFile.free(&self)
{
	if (self.uri.len > 0) self.uri.free(self.allocator);
	self.path.free(self.allocator);
	self.uri = "";
	self.path = (Path)"";
}

<*
 Storage for a static file tree.

 Create and initialize this store with a path and directory options, pass it
 to `Router.serve_static` or `Group.serve_static`, and release it with
 `StaticFiles.free`. The router only borrows the stored instances, so
 `Router.free` and `StaticFiles.free` do not depend on each other. Keep the
 store alive while its routes may be served.
*>
struct StaticFiles
{
	Allocator allocator;
	Path path;
	bool indexing;
	bool clean_urls;
	List{StaticFile*} files;
}

<*
 Initialize a static file store with its path and directory options.

 The path is copied with `allocator`.

 @param [&inout] self : "Static file store to initialize"
 @param [&inout] allocator : "Allocator used for the store, its instances, and copied paths"
 @param path : "Directory or file to serve"
 @param indexing : "Whether to register directory index files"
 @param clean_urls : "Whether to register extensionless HTML routes"
 @return "Initialized static file store"
*>
fn StaticFiles* StaticFiles.init(
	&self,
	Allocator allocator,
	Path path,
	bool indexing = true,
	bool clean_urls = true
)
{
	self.allocator = allocator;
	self.path = path.copy(allocator);
	self.indexing = indexing;
	self.clean_urls = clean_urls;
	self.files.init(allocator);
	return self;
}

<*
 Create and store one static file handler instance.

 The returned instance is owned by this store. Do not free it separately;
 release the store with `StaticFiles.free`.

 @param [&inout] static_files : "Static file store receiving the instance"
 @param uri : "Route URI to copy into the instance"
 @param path : "File path to copy into the instance"
 @return "Store-owned static file handler instance"
*>
fn StaticFile* add_static_file(StaticFiles* static_files, String uri, Path path) @private
{
	StaticFile* file = alloc::new(static_files.allocator, StaticFile);
	file.init(static_files.allocator, path);
	file.uri = uri.copy(static_files.allocator);
	static_files.files.push(file);
	return file;
}

<*
 Free the configured path and all static file handler instances owned by this
 store.

 This function does not access the router. The router and the store may be
 freed in either order after the server stops serving requests.

 @param [&inout] self : "Static file store to free"
*>
fn void StaticFiles.free(&self)
{
	foreach (file : self.files)
	{
		Allocator allocator = file.allocator;
		file.free();
		alloc::free(allocator, file);
	}
	self.files.free();
	self.path.free(self.allocator);
	self.path = (Path)"";
}

<*
 Serve the file represented by this handler.

 @param [&in] static_file : "Static file handler state"
 @param [&inout] allocator : "Allocator for the response body"
 @param [&inout] ctx : "Request context"
 @param [&inout] req : "Incoming request"
 @param [&inout] res : "Response to populate"
*>
fn void serve_file(
	StaticFile* static_file,
	Allocator allocator,
	HandlerContext* ctx,
	HttpRequest* req,
	HttpResponse* res,
) @private
{
	if (!path::exists(static_file.path) || !path::is_file(static_file.path))
	{
		res.status = HttpStatus.NOT_FOUND;
		res.headers.set_header_value("Content-Type", "application/json");
		res.body = string::format(allocator, `{"type":"error","status":404}`);
		return;
	}

	// Read entire file into response body.
	File? file = file::open_path(static_file.path, "rb");
	if (catch error = file)
	{
		res.status = HttpStatus.INTERNAL_SERVER_ERROR;
		return;
	}
	defer file.close();

	sz size     = file::get_size(static_file.path)!!;
	char[] body = alloc::new_array(allocator, char, size);

	sz read_total = 0;
	while (read_total < size)
	{
		sz read = file.read(body[read_total..])!!;
		if (read == 0) break;
		read_total += read;
	}

	res.status = HttpStatus.OK;
	res.body = body[:read_total];
	res.headers.set_header_value("Content-Type", mime_type(static_file.path));
}

<*
 Return the MIME type for a file path.

 @param [in] path : "File path whose extension is inspected"
 @return "MIME type string"
*>
fn String mime_type(Path path)
{
	String ext = path.extension() ?? "";

	switch (ext)
	{
		case "html":
			return "text/html; charset=utf-8";
		case "css":
			return "text/css; charset=utf-8";
		case "js":
			return "application/javascript; charset=utf-8";
		case "json":
			return "application/json; charset=utf-8";
		case "xml":
			return "application/xml; charset=utf-8";
		case "txt":
			return "text/plain; charset=utf-8";

		case "png":
			return "image/png";
		case "jpg":
		case "jpeg":
			return "image/jpeg";
		case "gif":
			return "image/gif";
		case "svg":
			return "image/svg+xml";
		case "webp":
			return "image/webp";
		case "ico":
			return "image/x-icon";

		case "pdf":
			return "application/pdf";

		case "wasm":
			return "application/wasm";

		default:
			return "application/octet-stream";
	}
}