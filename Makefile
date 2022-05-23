.PHONY: help clean clean-build clean-pyc clean-test lint test test-all test-junit coverage coverage-open dist install
.DEFAULT_GOAL := help
define BROWSER_PYSCRIPT
import os, webbrowser, sys
try:
	from urllib import pathname2url
except:
	from urllib.request import pathname2url

webbrowser.open("file://" + pathname2url(os.path.abspath(sys.argv[1])))
endef
export BROWSER_PYSCRIPT

define PRINT_HELP_PYSCRIPT
import re, sys

for line in sys.stdin:
	match = re.match(r'^([a-zA-Z_-]+):.*?## (.*)$$', line)
	if match:
		target, help = match.groups()
		print("%-20s %s" % (target, help))
endef
export PRINT_HELP_PYSCRIPT
BROWSER := python -c "$$BROWSER_PYSCRIPT"
MODULE_NAME := src/utils
FLAKE_FOLDER := src

help:
	@python -c "$$PRINT_HELP_PYSCRIPT" < $(MAKEFILE_LIST)

clean: clean-build clean-pyc clean-test ## remove all Python artifacts

clean-build: ## remove build artifacts
	@rm -fr build/
	@rm -fr dist/
	@rm -fr .eggs/
	@find . -name '*.egg-info' -exec rm -fr {} +
	@find . -name '*.egg' -exec rm -fr {} +

clean-pyc: ## remove Python file artifacts
	@find . -name '*.pyc' -exec rm -f {} +
	@find . -name '*.pyo' -exec rm -f {} +
	@find . -name '*~' -exec rm -f {} +
	@find . -name '__pycache__' -exec rm -fr {} +

clean-test: ## remove test and coverage artifacts
	@rm -fr .tox/
	@rm -f .coverage
	@rm -fr reports/

lint: install ## check style with flake8
	python -m pylint src/
	mkdir -p reports/flake-report
	python -m flake8 --exit-zero --format=html --htmldir=reports/flake-report $(FLAKE_FOLDER)
	python -m flake8 --exit-zero --format=qmaJson --output-file=reports/flake.json $(FLAKE_FOLDER)

test: setpath install dist test-junit coverage lint

setpath:
    export PYTHONPATH=src/
    export IF_UTILS_ENV=dev

test-all: test-junit coverage lint## run tests on every Python version with tox
	python -m tox

test-junit:
	python -m pytest test/ --junitxml=reports/report.xml --ignore=lib --html=reports/report.html --self-contained-html --continue-on-collection-errors || true

coverage: ## check code coverage quickly with the default Python
	python -m coverage run --branch --source $(MODULE_NAME) -m pytest test/ --ignore=lib --continue-on-collection-errors || true
	python -m coverage xml -o reports/coverage.xml
	python -m coverage html -d reports/html
	python -m coverage report -m

coverage-open: coverage
	$(BROWSER) htmlcov/index.html

dist: clean ## builds source and wheel package
	python setup.py sdist
	python setup.py bdist_egg
	python setup.py bdist_wheel
	ls -l dist

install: clean ## install the package to the active Python's site-packages
	pip install -r requirements.txt
	pip install -r requirements-dev.txt
	#python setup.py install

publish: dist ## build source and wheels and publish to artifactory
	python -m pip install twine
	python -m twine upload --repository-url https://artifactory.nike.com/artifactory/api/pypi/python-local --username ${ARTIFACTORY_USER} --password ${ARTIFACTORY_PASSWORD} --verbose dist/*.whl dist/*.egg

update-docs:
	sphinx-apidoc -o ./docs/source ./src
	sphinx-build ./docs/source ./docs
