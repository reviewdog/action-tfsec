#!/bin/sh

cd "$GITHUB_WORKSPACE"

export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"

tfsec --format=checkstyle ${INPUT_FLAGS} \
  | reviewdog -f=checkstyle -name="tfsec" -reporter="${INPUT_REPORTER}" -level="${INPUT_LEVEL}"
