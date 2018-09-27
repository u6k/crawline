#!/bin/sh

rm -f tmp/pids/server.pid

rails db:migrate
rails server -b 0.0.0.0
