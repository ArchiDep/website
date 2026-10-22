.PHONY: all check

all: check

check:
	cd app && mix check
	npm run check
