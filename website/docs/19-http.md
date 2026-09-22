# HTTP servers and clients

`Std.Http.Server` answers HTTP requests and `Std.Http.Client` makes them. A server is built from values — routes, a router, handlers — so most of it can be written and tested without opening a socket.

## Handlers and routes

A handler is a function from a request to a response. A route pairs a method and a path pattern with a handler, and a router holds the routes:

```pudu
module Greeter

import Std.Http as Http
import Std.Http.Server.Reply as Reply
import Std.Http.Server.Route as Route
import Std.Option as Option

fn hello(request: Route.Request) -> Http.Response {
  let name = Option.unwrapOr(Route.queryParam(&request, "name"), "world")
  Reply.text(200, "Hello, {name}!")
}

fn user(request: Route.Request) -> Http.Response {
  match Route.param(&request, "id") {
    case Some(id) => Reply.text(200, "user {id}")
    case None => Reply.text(400, "no user")
  }
}

fn routes() -> Route.Router {
  Route.routing(&[
      Route.get("/hello", hello),
      Route.get("/users/:id", user)
    ])
}

fn ask(router: &Route.Router, target: Str) -> Http.Response {
  let request = Route.Request{
    message: Http.Request{method: Http.Get, target: target, headers: [], body: "", binaryBody: None},
    path: Route.pathOf(target),
    params: mapOf([]),
    query: Route.queryOf(target),
    peer: "example"
  }
  Route.dispatch(router, request)
}

fn main() -> Int {
  let router = routes()
  let greeted = ask(&router, "/hello?name=Ada")
  let found = ask(&router, "/users/7")
  let missing = ask(&router, "/nowhere")
  let ok = greeted.body == "Hello, Ada!" && found.body == "user 7"
  if ok && missing.status.code == 404 { 0 } else { 1 }
}
```

`:id` in a pattern captures one piece of the path, read with `Route.param`. `Route.queryParam` reads the query string. A request nothing matches is answered `404`.

Because a router is a value and `Route.dispatch` is a function, the `ask` helper above is all a test needs: no port, no network, and no waiting.

## Replies

`Std.Http.Server.Reply` builds the common responses:

| Reply | Answers |
| --- | --- |
| `Reply.text(status, text)` | plain text |
| `Reply.html(status, html)` | an HTML page from text |
| `Reply.page(status, document)` | a page built with `Std.Html`, escaped by construction |
| `Reply.json(status, encoded)` | JSON that is already text |
| `Reply.jsonValue(status, value)` | a `Std.Json` value, encoded |
| `Reply.empty(status)` | a status and nothing else |
| `Reply.unprocessable(reason)` | `422`, for a body that could not be acted on |

## A JSON API

A handler reads the body with `Route.body`, decodes it, and answers:

```pudu
module Api

import Std.Http as Http
import Std.Http.Server.Reply as Reply
import Std.Http.Server.Route as Route
import Std.Json as Json
import Std.Option as Option

fn create(request: Route.Request) -> Http.Response {
  let decoded = Json.decode(Route.body(&request))
  let value = match decoded {
    case Ok(held) => held
    case Err(_) => { return Reply.text(400, "the body is not JSON") }
  }
  let title = Option.andThen(Json.field(&value, "title"), fn(held: Json.Json) -> Option[Str] { Json.asText(&held) })
  match title {
    case Some(text) if !text.trim().isEmpty() =>
      Reply.jsonValue(201, Json.object(&[("title", Json.Text(text)), ("done", Json.Boolean(false))]))
    case _ => Reply.unprocessable("title must be non-empty text")
  }
}

fn post(router: &Route.Router, body: Str) -> Http.Response {
  let request = Route.Request{
    message: Http.Request{method: Http.Post, target: "/tasks", headers: [], body: body, binaryBody: None},
    path: "/tasks",
    params: mapOf([]),
    query: mapOf([]),
    peer: "example"
  }
  Route.dispatch(router, request)
}

fn main() -> Int {
  let router = Route.routing(&[Route.post("/tasks", create)])
  let made = post(&router, "\{\"title\": \"write the docs\"\}")
  let refused = post(&router, "\{\"title\": \"\"\}")
  let broken = post(&router, "not json")
  let ok = made.status.code == 201 && made.body.contains("write the docs")
  if ok && refused.status.code == 422 && broken.status.code == 400 { 0 } else { 1 }
}
```

## Serving

`Std.Http.Server` turns a router into a server and listens. `listenAndServe` takes the host, the port, and how many connections to serve before stopping, where `0` means no limit:

```pudu
module Serve

import Std.Env as Env
import Std.Http as Http
import Std.Http.Server as Server
import Std.Http.Server.Reply as Reply
import Std.Http.Server.Route as Route
import Std.Io as Io

fn home(_request: Route.Request) -> Http.Response {
  Reply.text(200, "Served by Pudu")
}

export fn main() -> Int {
  let router = Route.routing(&[Route.get("/", home)])
  let server = Server.server(&router)
  if !Env.hasFlag("--serve") {
    let _written = Io.writeLine("run with --serve to listen on http://127.0.0.1:8080")
    return 0
  }
  match Server.listenAndServe(&server, "127.0.0.1", 8080, 0) {
    case Ok(_) => 0
    case Err(_) => 1
  }
}
```

The server reads requests with limits on their size and on how long they may take, runs a fixed pool of workers, and stops cleanly when the program is asked to stop. [Std.App](/module/Std.App) builds on it with configuration, health checks, and graceful shutdown for a complete service.

## Making requests

`Std.Http.Client` fetches a URL within limits on size, time, and redirects. Verified TLS is used for `https`:

```pudu
module Fetch

import Std.Env as Env
import Std.Http.Client as Client
import Std.Io as Io

export fn main() -> Int {
  if !Env.hasFlag("--fetch") {
    let _written = Io.writeLine("run with --fetch to request https://example.com")
    return 0
  }
  match Client.fetch("https://example.com", &Client.limits()) {
    case Ok(response) => {
      let _written = Io.writeLine("status {response.status.code}, {response.body.length()} characters")
      0
    }
    case Err(problem) => {
      let _written = Io.writeErrorLine(Client.explain(&problem))
      1
    }
  }
}
```

A failed request is a value: the network being down, a timeout, and a response larger than the limit each arrive as a `ClientError` the program decides what to do with.
