module c3api::routing;

import std::collections::map;
import std::io;
import std::collections::object;

import c3api::http;

alias RouteFunction = fn HttpResponse(ControllerParadise*, HttpRequest, HashMap{String, String});
alias RouteMap = HashMap{String, RouteNode*};
alias TagsMap = HashMap{String, Object*};

struct RouteNode
{
	String name;
	RouteMap subnodes;
	bool has_apply;
	RouteFunction apply;
}

fn HttpResponse e404(ControllerParadise* controller = null, HttpRequest req, HashMap{String, String} args)
{
	HttpResponse res;
	res.init(tmem);

	res.status = HttpStatus.NOT_FOUND;
	res.body = string::format(mem, `{"type":"error","status":404}`);

	res.headers.set_header_value("Content-Type", "application/json");

	return res;
}

fn HttpResponse file(ControllerParadise* controller = null, HttpRequest req, HashMap{String, String} args)
{
	HttpResponse res;
	res.init(tmem);

	String filename = args["filename"]!!;
	// io::printfn("%s:%d %s", $$MODULE, $$LINE, filename);

	File? file;

	if (file::is_file(filename))
	{
		file = file::open(filename, "rb");
	}
	else
	{
		Path path = path::cwd(mem)!!;
		path = path.append(mem, filename)!!;

		file = file::open_path(path, "rb");
		filename = path;
	}

	defer
	{
		(void)file.flush();
		(void)file.close();
	}

	if (catch err = file)
	{
		res.status = HttpStatus.NOT_FOUND;
		io::eprintfn("Failed to get file: %s", err);
		res.body = string::format(mem, `{"type":"error","status":404}`);

		res.headers.set_header_value("Content-Type", "application/json");
	}
	else if (file::get_size(filename)!! > 5 * 1024 * 1024)
	{
		// TODO CONFIG (right now 5Mb is the limit for the file)
		res.status = HttpStatus.PAYLOAD_TOO_LARGE;

		res.body = string::format(mem, `{"type":"error","status":413}`);

		res.headers.set_header_value("Content-Type", "application/json");
	}
	else
	{
		DString text;
		if (catch err1 = text.read_from_stream(&file))
		{
			io::eprintfn("Failed to read: %s", err1);
			res.status = HttpStatus.BAD_REQUEST;
			res.body = string::format(mem, `{"type":"error","status":400}`);
		}
		else
		{
			res.status = HttpStatus.OK;
			res.body = text.str_view();
			res.headers.set_header_value("Content-Type", "text/plain");
		}
	}

	return res;
}

fn HttpResponse folder(ControllerParadise* controller = null, HttpRequest req, HashMap{String, String} args)
{
	HttpResponse res;
	res.init(tmem);
	String filename = args["foldername"]!!;

	PathList? list;

	if (os::native_is_dir(filename))
	{
		list = path::ls(mem, path::tnew(filename));
	}
	else
	{
		Path path = path::cwd(mem)!!;
		path = path.append(mem, filename)!!;
		filename = path;
		if (path::is_dir(path))
		{
			list = path::ls(mem, path);
		}
	}

	if (catch err = list)
	{
		res.status = HttpStatus.NOT_FOUND;
		res.body = string::format(mem, `{"type":"error","status":404}`);

		res.headers.set_header_value("Content-Type", "application/json");
	}
	else
	{
		DString body = dstring::new(mem);
		body.appendfn(
			`
<style>
table, th, td {
  border: 1px solid black;
  border-collapse: collapse;
  table-layout: auto;
  vertical-align: bottom;
  padding: 5px;
}
</style>
<h1>Contents of %s</h1><hr>
<table>
<tr>
    <th>Name</th>
    <th>Size</th>
</tr>
        `,
			filename
		);

		foreach (Path file : list)
		{
			body.appendfn(
				`<tr>
    <td>%s %s</td>
    <td>%d</td>
</tr>`,
				(path::is_dir(file) ? "📁 " : "🔗 "),
				file,
				file::get_size(file)!!
			);
		}

		body.append("</table>");

		res.status = HttpStatus.OK;

		res.body = body.str_view();
		res.headers.set_header_value("Content-Type", "text/html; charset=utf-8");
	}

	return res;
}

fn RouteFunction get_route(String uri, HashMap{String, String}* args)
{
	if (uri == "" || uri == "/")
	{
		io::printn("[ROUTER] Root request");
		if (_rootNodes.has_key(uri))
		{
			io::printn("[ROUTER] Root route exists");

			return (_rootNodes[uri].has_apply ?? false) ? _rootNodes[uri].apply!! : &e404;
		}

		io::printn("[ROUTER] Root route missing");
		return &e404;
	}

	DString reverse_path = dstring::new(mem, uri);

	if (uri[0] != '/')
	{
		reverse_path.insert_at(0, "/");
	}
	io::printfn("[ROUTER] Initial reverse path: '%s'", reverse_path.str_view());
	args.set("reverse_path", reverse_path.str_view());

	String old_uri;
	if (uri[0] == '/' && uri.len > 1)
	{
		io::printfn("[ROUTER] Removing leading slash from '%s'", uri);
		old_uri = uri;
		uri = uri[1..];
	}

	io::printfn("[ROUTER] Normalized URI: '%s'", uri);

	if (!(uri.contains("{") && uri.contains("}")) && _rootNodes.has_key(uri))
	{
		io::printfn("[ROUTER] Direct route match: '%s'", uri);

		RouteNode* node = _rootNodes[uri]!!;

		io::printfn("[ROUTER] Node '%s' has handler: %s", node.name, node.has_apply ? "yes" : "no");

		return node.has_apply ? node.apply : &e404;
	}

	String[] nodes = uri.tsplit("/");

	RouteNode*? temp = _rootNodes[nodes[0]];
	if (catch err = temp)
	{
		io::printfn("Catch err: %s", err);
		return &e404;
	}

	io::printfn("[ROUTER] Starting node: '%s'", temp.name);
	reverse_path.clear();
	reverse_path.appendf("/%s", temp.name);

	int i = 1;
	while (temp != null && i < nodes.len)
	{
		if (nodes[i] == "") break;
		io::printfn("[ROUTER] Looking for child '%s' under '%s'", nodes[i], temp.name);

		temp = get_next_node(temp, nodes[i]) ?? null;

		if (temp == null)
		{
			io::printfn("[ROUTER] No child found, continuing");
			continue;
		}

		io::printfn("[ROUTER] Matched node '%s'", temp.name);

		if (temp.name[0] == '{' && temp.name[^1] == '}')
		{
			String key = temp.name[1:^2];
			io::printfn("[ROUTER] Dynamic parameter: %s=%s", key, nodes[i]);
			(*args)[key] = nodes[i];
		}

		reverse_path.appendf("/%s", temp.name);
		io::printfn("[ROUTER] Reverse path now: '%s'", reverse_path.str_view());
		i++;
	}

	if (temp == null)
	{
		io::printn("[ROUTER] No matching route found");
		args.set("reverse_path", "/e404");
		return &e404;
	}


	args.set("reverse_path", reverse_path.str_view());

	io::printfn("[ROUTER] Final route: '%s'", reverse_path.str_view());
	io::printfn("[ROUTER] Has handler: %s", temp.has_apply ? "yes" : "no");


	if (!temp.has_apply)
	{
		io::printn("[ROUTER] Missing handler, returning 404");
		return &e404;
	}
	RouteFunction res = temp.apply;
	return res;
}

fn void add_route(String uri, RouteFunction apply)
{
	io::printfn("[ROUTER ADD] Adding route '%s'", uri);
	if (uri[0] == '/' && uri.len > 1) uri = uri[1..];

	io::printfn("[ROUTER ADD] Normalized route '%s'", uri);

	String[] nodes = uri.split(mem, "/");
	RouteNode* temp;

	io::printfn("[ROUTER ADD] route has %d nodes", nodes.len);
	foreach (String n : nodes)
	{
		io::printfn("[ROUTER ADD] node part '%s'", n);
	}

	if (!_rootNodes.has_key(nodes[0]))
	{
		io::printfn("[ROUTER ADD] Creating root node '%s'", nodes[0]);
		temp = new_route(nodes[0]);
		_rootNodes[nodes[0]] = temp;
	}
	else
	{
		io::printfn("[ROUTER ADD] Using existing root node '%s'", nodes[0]);
		temp = _rootNodes[nodes[0]]!!;
	}

	foreach (i, node : nodes[..^2])
	{
		io::printfn("[ROUTER ADD] Processing child '%s' under '%s'", node, temp.name);
		if (try _temp = get_next_node(temp, node))
		{
			io::printfn("[ROUTER ADD] Existing child '%s'", _temp.name);
			temp = _temp;
			continue;
		}
		String key = nodes[i + 1].is_braced() ? "{}" : nodes[i + 1];

		io::printfn("[ROUTER ADD] Creating child key '%s'", key);

		RouteNode* child = new_route(nodes[i + 1]);
		temp.subnodes[key] = child;
		temp = child;
	}

	io::printfn("[ROUTER ADD] Assigning handler to '%s'", temp.name);
	temp.apply = apply;
	temp.has_apply = true;
}

fn void init_route_map(Allocator allocator)
{
	_rootNodes.init(allocator);
	tagsMap.init(allocator);
}
fn void destroy_route_map()
{
	_rootNodes.free();
	tagsMap.free();
}

TagsMap tagsMap;

fn void add_tag(Allocator allocator, String func, String key, String value)
{
	if (!tagsMap.has_key(func))
	{
		tagsMap[func] = object::new_obj(allocator);
	}
	tagsMap[func]!!.set(key, value);
}

module c3api::routing @private;
import std::collections::map;
import std::io;

RouteMap _rootNodes;

fn RouteNode*? get_next_node(RouteNode* from, String to)
{
	return from.subnodes[to] ?? from.subnodes["{}"];
}

macro RouteNode* new_route(String name, HashMap{String, RouteNode*} subnodes = { }, RouteFunction apply = null)
{
	io::printfn("[ROUTER ADD] Creating node '%s' handler=%s", name, apply != null ? "yes" : "no");
	return @clone((RouteNode) { name, subnodes, apply != null, apply, });
}

fn bool String.is_braced(self)
{
	return self[0] == '{' && self[^1] == '}';
}
