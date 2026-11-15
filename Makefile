.PHONY: toolchain wasm native test check

toolchain:
	./tools/get-toolchain.sh

wasm:
	./build.sh

native:
	gprbuild -P tests/smoke.gpr
	./obj/native/smoke
	./obj/native/steps_smoke

test: native wasm
	npm test

check: test
