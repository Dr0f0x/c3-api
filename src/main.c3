module app;

import c3api;
import c3api::config;
import c3api::routes;
import c3api::server;
import std::collections::map;

fn HttpResponse no_controller(c3api::Cref self = null, HttpRequest req, HashMap{String,String} args) {
    @pool() { // Using pool because of dstring::temp_new();
        HttpResponse res;
        res.status = HttpStatus.OK;
        DString greetings = dstring::temp();
        greetings.appendf("Look, %s, no controllers!\n", args["name"]!!);
        res.body = string::format(mem, greetings.tcopy_str(), req.method, req.uri);
        return res;
    };
}

fn HttpResponse static_no_controller(c3api::Cref self = null, HttpRequest req, HashMap{String,String} args) {
    @pool() { // Using pool because of dstring::temp_new();
        HttpResponse res;
        res.status = HttpStatus.OK;
        DString greetings = dstring::temp();
        greetings.appendf("Look, static!\n");
        res.body = string::format(mem, greetings.tcopy_str(), req.method, req.uri);
        return res;
    };
}
fn int main(String[] args)
{
    config::Config config = config::readFromFile();

    routes::init_route_map();
    defer routes::destroy_route_map();

    routes::add_route("/example/{name}", &no_controller);

    routes::add_route("/exampler/static", &static_no_controller);

    server::startServer(config)!!;
    return 0;
}