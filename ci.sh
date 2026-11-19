#!/usr/bin/env bash
set -e

mvn -B verify
test -f target/hello.jar
java -jar target/hello.jar
