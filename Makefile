# CRIMSON RAILS — единый раннер
# make test [SEASON=01] [SERIES=s01e01] | test-visual | links | check | progress

SHELL := /bin/bash

.PHONY: test test-visual links check progress docs help

help:
	@echo "make test                 все серии"
	@echo "make test SEASON=01       один сезон"
	@echo "make test SERIES=s01e01   одна серия"
	@echo "make test-visual          серии, которым нужен headless-браузер"
	@echo "make links                битые ссылки между документами"
	@echo "make check                links + test, как в CI"
	@echo "make progress             где я остановился"

test:
	@tools/run_tests.sh

test-visual:
	@VISUAL=1 tools/run_tests.sh

links:
	@tools/check_links.sh

check: links test

progress:
	@tools/progress.sh

docs:
	@tools/gen_curriculum.sh
	@echo "docs/CURRICULUM.md собран"
