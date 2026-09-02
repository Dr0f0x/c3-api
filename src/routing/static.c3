// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Dr0f0x

module c3api::routing;

import std::io::path;
import std::collections::list;
import std::collections::map;
import std::io::file;

import c3api::http;
import c3api::log;
import c3api::context;
import c3api::routing::internal;

<*
 Register static files below a router path.

 @param [&inout] self : "Router receiving static file routes"
 @param uri : "URI prefix for the files"
 @param path : "Directory or file to serve"
 @param indexing : "Whether to register directory index files"
 @param clean_urls : "Whether to register extensionless HTML routes"
 @return "Success or a file error"
*>
fn void? Router.serve_static(&self, String uri, Path path, bool indexing = true, bool clean_urls = true)
{
	return routing::serve_static(
		uri,
		path,
		indexing,
		clean_urls,
		&self.root_handlers,
		&self.root_middlewares,
		&self.root_nodes,
		self.log
	);
}

<*
 Register static files below a group path.

 @param [&inout] self : "Group receiving static file routes"
 @param uri : "URI prefix for the files"
 @param router : "Router owning the route storage"
 @param path : "Directory or file to serve"
 @param indexing : "Whether to register directory index files"
 @param clean_urls : "Whether to register extensionless HTML routes"
 @return "Success or a file error"
*>
fn void? Group.serve_static(&self, String uri, Router* router, Path path, bool indexing = true, bool clean_urls = true)
{
	return routing::serve_static(
		uri,
		path,
		indexing,
		clean_urls,
		&router.root_handlers,
		&router.root_middlewares,
		&router.root_nodes,
		self.log
	);
}

<*
 Register static files in route storage.

 @param uri : "URI prefix for the files"
 @param path : "Directory or file to serve"
 @param indexing : "Whether to register directory index files"
 @param clean_urls : "Whether to register extensionless HTML routes"
 @param handlers : "Handler collection receiving file handlers"
 @param middlewares : "Middleware collection for the routes"
 @param nodes : "Route node map"
 @param log : "Logger"
 @return "Success or a file error"
*>
fn void? serve_static(
	String uri,
	Path path,
	bool indexing,
	bool clean_urls,
	HandlerCollection* handlers,
	List{RegisteredMiddleware}* middlewares,
	HashMap{String, RouteNode}* nodes,
	log::Logger log
) @private
{
	if (path::is_file(path))
	{
		register_static_file(uri, path, handlers, middlewares, nodes, log);
		return;
	}

	if (!path::is_dir(path))
	{
		log.errorf("Path %s for static serving not found", "path for static not found", log::_string("path", &path));
		return io::FILE_NOT_FOUND~;
	}

	StaticWalkData data = {
		.base = path,
		.uri = uri,
		.indexing = indexing,
		.clean_urls = clean_urls,
		.handlers = handlers,
		.middlewares = middlewares,
		.nodes = nodes,
		.log = log
	};

	path.walk(&register_static_entry, &data)!;

	if (indexing)
	{
		Path index = path.append(tmem, "index.html")!;
		if (path::is_file(index))
		{
			register_static_file(uri, index, handlers, middlewares, nodes, log);
		}
	}
}

<* State shared while walking a static file directory. *>
struct StaticWalkData
{
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
fn bool? register_static_entry(Path file, bool is_dir, void* data_ptr)
{
	if (is_dir) return false;

	StaticWalkData* data = data_ptr;

	String relative = file[data.base.len + 1..].replace(tmem, "\\", "/");

	DString route = dstring::temp();
	route.append(data.uri);
	if (data.uri != "/") route.append("/");

	route.append(relative);

	String file_uri = route.str_view();

	register_static_file(file_uri.copy(mem), file, data.handlers, data.middlewares, data.nodes, data.log);

	if (data.clean_urls && file.has_extension("html") && file.basename() != "index.html")
	{
		// /files/main.html -> /files/main
		String clean = file_uri[0..file_uri.len - 6];

		register_static_file(clean.copy(mem), file, data.handlers, data.middlewares, data.nodes, data.log);
	}

	return false;
}

<*
 Register one file-backed GET route.

 @param uri : "Route URI"
 @param path : "File path"
 @param handlers : "Handler collection receiving the file handler"
 @param middlewares : "Middleware collection for the route"
 @param nodes : "Route node map"
 @param log : "Logger"
*>
fn void register_static_file(
	String uri,
	Path path,
	HandlerCollection* handlers,
	List{RegisteredMiddleware}* middlewares,
	HashMap{String, RouteNode}* nodes,
	log::Logger log
)
{
	StaticFile* static_file = mem::new(StaticFile);
	static_file.path = path.copy(mem);

	log.tracef(
		"adding file handler for uri: %s path %s",
		"adding file handler",
		log::_string("uri", &uri),
		log::_string("path", &path)
	);

	internal::_add_handler(
		uri,
		RouteMethod.GET,
		(HandleFunc)&StaticFile.serve_file,
		static_file,
		{ },
		handlers,
		middlewares,
		nodes,
		log
	);
}

<* File-backed handler state for a registered static route. *>
struct StaticFile
{
	Path path;
}

<*
 Serve the file represented by this handler.

 @param [&in] self : "Static file handler state"
 @param [&inout] allocator : "Allocator for the response body"
 @param [&inout] ctx : "Request context"
 @param [&inout] req : "Incoming request"
 @param [&inout] res : "Response to populate"
*>
fn void StaticFile.serve_file(&self, Allocator allocator, Context* ctx, HttpRequest* req, HttpResponse* res)
{
	if (!path::exists(self.path) || !path::is_file(self.path))
	{
		res.status = HttpStatus.NOT_FOUND;
		res.headers.set_header_value("Content-Type", "application/json");
		res.body = string::format(allocator, `{"type":"error","status":404}`);
		return;
	}

	// Read entire file into response body.
	File? file = file::open_path(self.path, "rb");
	if (catch error = file)
	{
		res.status = HttpStatus.INTERNAL_SERVER_ERROR;
		return;
	}
	defer file.close();

	sz size     = file::get_size(self.path)!!;
	char[] body = alloc::new_array(allocator, char, size);

	sz read_total = 0;
	while (read_total < size)
	{
		sz read = file.read(body[read_total..])!!;
		if (read == 0) break;
		read_total += read;
	}

	res.status = HttpStatus.OK;
	res.body = body[0..read_total - 1];
	res.headers.set_header_value("Content-Type", mime_type(self.path));
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