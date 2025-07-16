.PHONY: build-watch run-watch test-watch format build copy install

build-watch:
	zig build -fincremental --watch --debounce 1000

run-watch:
	zig build -fincremental --watch --debounce 1000 run

test-watch:
	zig build -fincremental --watch --debounce 1000 test

format:
	zig fmt .

build:
	zig build -Doptimize=ReleaseSmall

copy:
	cp zig-out/bin/zeff ~/.local/bin;

install: build copy
