module c3api::routing;

import c3api::http;

alias NextFunc = fn void();

alias MiddlewareFunc = fn void(HttpRequest*, HttpResponse*, NextFunc);