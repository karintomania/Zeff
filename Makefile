.PHONY: build-watch run-watch test-watch format

build-watch:
	zig build -fincremental --watch --debounce 1000

run-watch:
	zig build -fincremental --watch --debounce 1000 run

test-watch:
	zig build -fincremental --watch --debounce 1000 test

format:
	zig fmt .

install:
	zig build &&  cp zig-out/bin/zeff ~/.local/bin;
