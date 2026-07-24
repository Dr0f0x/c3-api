module c3api::routing;

import std::io::path;
import std::collections::list;
import std::collections::map;
import std::io::file;

import c3api::http;
import c3api::log;

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

fn void? serve_static(
	String uri,
	Path path,
	bool indexing,
	bool clean_urls,
	HandlerCollection* handlers,
	List{MiddlewareFunc}* middlewares,
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

struct StaticWalkData
{
	Path base;
	String uri;
	bool indexing;
	bool clean_urls;

	HandlerCollection* handlers;
	List{MiddlewareFunc}* middlewares;
	HashMap{String, RouteNode}* nodes;
	log::Logger log;
}

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

fn void register_static_file(
	String uri,
	Path path,
	HandlerCollection* handlers,
	List{MiddlewareFunc}* middlewares,
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

	add_handler(
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

struct StaticFile
{
	Path path;
}

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
	File? file = file::open_path(self.path, "r");
	if (catch error = file)
	{
		res.status = HttpStatus.INTERNAL_SERVER_ERROR;
		return;
	}
	defer file.close();

	sz size     = file::get_size(self.path)!!;
	char[] body = alloc::new_array(allocator, char, size + 1);

	sz read = file.read(body)!!;
	body[read] = 0;

	res.status = HttpStatus.OK;
	res.body = body;
	res.headers.set_header_value("Content-Type", mime_type(self.path));
}

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
