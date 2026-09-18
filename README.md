
# valk-starter-api

A small JSON API in [Valk](https://valk-lang.dev), built out of the packages rather than as a
demo of one of them: a command line, a database with migrations, sessions, a cache and ids.

| what | package |
| --- | --- |
| commands, options, help, tab completion | [valk-cli](https://github.com/ctxcode/valk-cli) |
| storage, migrations, the query builder | [valk-sql](https://github.com/ctxcode/valk-sql) + [valk-sqlite](https://github.com/ctxcode/valk-sqlite) |
| session tokens | [valk-jwt](https://github.com/ctxcode/valk-jwt) |
| account ids | [valk-uuid](https://github.com/ctxcode/valk-uuid) |
| cache and rate limit | [valk-redis](https://github.com/ctxcode/valk-redis) |
| the HTTP server and JSON | the standard library |

Requires Valk 0.7.3 or newer, and SQLite on the system. Redis is optional: without it the API
works, it just asks the database every time and does not rate limit.

## Running it

```sh
vman install                       # fetch the packages
make api                           # build ./api

./api migrate --database app.db
./api user create ada@example.com "a-good-password" --database app.db
./api serve --secret "$(head -c 32 /dev/urandom | base64)" --database app.db --redis 127.0.0.1:6379
```

```sh
curl -s localhost:8080/health
curl -s -XPOST localhost:8080/users -d '{"email":"bob@example.com","password":"a-good-password"}'
TOKEN=$(curl -s -XPOST localhost:8080/login -d '{"email":"bob@example.com","password":"a-good-password"}' | jq -r .token)
curl -s localhost:8080/me -H "Authorization: Bearer $TOKEN"
```

`./api completion bash` prints the script that completes the commands, options and their values
in your shell.

## What is where

| file | what it holds |
| --- | --- |
| `src/main.valk` | the commands: `serve`, `migrate`, `user create`, `user list` |
| `src/config.valk` | the settings, and how they reach the worker threads |
| `src/store.valk` | opening the database and running the embedded migrations |
| `src/users.valk` | making, finding and listing accounts; bcrypt passwords |
| `src/cache.valk` | redis, and what to do when there is none |
| `src/api.valk` | the request handlers |
| `migrations/` | the schema, embedded into the program with `#embed_dir` |

## Three things worth copying

**Settings reach the workers through the environment.** The HTTP server answers on several
threads, and a thread starts with its own globals — a value the main thread holds does not
travel. `Config.publish()` writes the settings into the environment and every thread reads them
back with `Config.from_environment()`.

**A connection is opened on the first request a thread answers, not in a global initializer.**
The initializer of a global runs outside any coroutine on a worker thread, and a socket cannot
be opened there; it fails with *"Cannot schedule an io_uring operation without a coroutine"*.
`database_for_this_thread()` and `cache_of_this_thread()` open theirs on first use, inside the
handler.

**A worker thread keeps the globals it started with.** That is what makes the per-thread
connection work, and it also means a server restarted inside one process is answered by threads
holding the settings of the one before it — which is why the tests start one server and keep it,
rather than one per case. A program that serves until it exits never meets this.

**Redis is optional on purpose.** `Cache.open` returns a cache that does nothing when there is
no redis to reach, so the program starts either way and `/health` says which it is. A cache that
takes the program down with it is worse than no cache.

## Tests

`make test` builds the program, starts it on a port of its own, and talks to it over HTTP:
making an account, the same email twice, a password that is too short, logging in, reading `/me`
with the token and with a forged one, `/health`, and a path that is not there. With a redis
running (`make cache`) it also checks that `/me` is cached and that six wrong passwords in a
minute are refused.
