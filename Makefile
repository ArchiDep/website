.PHONY: all check

all: check

check:
	pushd app && \
	mix check && \
	popd && \
	npm run format
