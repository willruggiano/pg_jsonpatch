#!/usr/bin/env bash
until pg_isready &>/dev/null; do
  sleep 1
done
