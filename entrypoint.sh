#!/bin/bash

if [ -n "${GITHUB_WORKSPACE}" ]; then
  cd "${GITHUB_WORKSPACE}" || exit
fi

export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"

tfsec --format=checkstyle ${INPUT_FLAGS} "${INPUT_WORKING_DIRECTORY}" \
  | reviewdog -f=checkstyle -name="tfsec" -reporter="${INPUT_REPORTER}" -level="${INPUT_LEVEL}"

tfsec_return="${PIPESTATUS[0]}" reviewdog_return="${PIPESTATUS[1]}" exit_code=$?

echo ::set-output name=tfsec-return-code::"${tfsec_return}"
echo ::set-output name=reviewdog-return-code::"${reviewdog_return}"

exit $exit_code
