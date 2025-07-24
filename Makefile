.PHONY: build-watch run-watch test-watch format build copy install release-build docker-shell

build-watch:
	zig build -fincremental --watch --debounce 1000

format:
	zig fmt .

build:
	zig build -Doptimize=ReleaseSmall

copy:
	cp zig-out/bin/zeff ~/.local/bin;

release-build:
	zig build  -Doptimize=ReleaseSmall -Dname=zeff-Darwin-arm64
	docker compose up

install: build copy

docker-shell:
	docker compose exec zeff -it /bin/bash
