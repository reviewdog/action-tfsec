#!/bin/bash

# Print commands for debugging
if [[ "$RUNNER_DEBUG" = "1" ]]; then
  set -x
fi

# Fail fast on errors, unset variables, and failures in piped commands
set -Eeuo pipefail

cd "${GITHUB_WORKSPACE}/${INPUT_WORKING_DIRECTORY}" || exit

echo '::group::Preparing ...'
  TEMP_PATH="$(mktemp -d)"
  echo "will install tools in ${TEMP_PATH}"
  REVIEWDOG_PATH="${TEMP_PATH}/reviewdog"
  KICS_PATH="${TEMP_PATH}/kics"
echo '::endgroup::'

echo "::group::🐶 Installing reviewdog (${REVIEWDOG_VERSION}) ... https://github.com/reviewdog/reviewdog"
  curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh | sh -s -- -b "${REVIEWDOG_PATH}" "${REVIEWDOG_VERSION}" 2>&1
echo '::endgroup::'

  pip3 install lastversion
  lastversion Checkmarx/kics --assets -d --verbose
  tar -xvf kics*.tar.gz
  ver=$(lastversion Checkmarx/kics)
  mv kics-${ver} kics
  chmod +x kics
echo '::endgroup::'

echo "::group:: Print kics details ..."
  ls
  "kics" --version
echo '::endgroup::'

echo '::group:: Running kics with reviewdog 🐶 ...'
  export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"

  # Allow failures now, as reviewdog handles them
  set +Eeuo pipefail

  # shellcheck disable=SC2086
  "./kics" --format=json ${INPUT_KICS_FLAGS:-} . \
    | jq -r -f "${GITHUB_ACTION_PATH}/to-rdjson.jq" \
    |  "${REVIEWDOG_PATH}/reviewdog" -f=rdjson \
        -name="kics" \
        -reporter="${INPUT_REPORTER}" \
        -level="${INPUT_LEVEL}" \
        -fail-on-error="${INPUT_FAIL_ON_ERROR}" \
        -filter-mode="${INPUT_FILTER_MODE}" \
        ${INPUT_FLAGS}

  kics_return="${PIPESTATUS[0]}" reviewdog_return="${PIPESTATUS[2]}" exit_code=$?
  echo "::set-output name=kics-return-code::${kics_return}"
  echo "::set-output name=reviewdog-return-code::${reviewdog_return}"
echo '::endgroup::'

exit "${exit_code}"
