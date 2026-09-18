vc ?= valk

api:
	$(vc) build ./src -o ./api

deps:
	vman install
test:
	$(vc) build ./tests --test --run
lint:
	$(vc) build ./src --lint
cache:
	docker run -d --name valk-redis-test -p 6399:6379 redis:7-alpine >/dev/null 2>&1 || docker start valk-redis-test >/dev/null
	@echo "redis listening on 127.0.0.1:6399"
cache-down:
	docker rm -f valk-redis-test >/dev/null 2>&1 || true

.PHONY: api deps test lint cache cache-down
