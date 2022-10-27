#!/bin/bash

# Print commands for debugging
if [[ "$RUNNER_DEBUG" = "1" ]]; then
  set -x
fi

# Fail fast on errors, unset variables, and failures in piped commands
set -Eeuo pipefail

cd "${GITHUB_WORKSPACE}/${INPUT_WORKING_DIRECTORY}" || exit

# echo '::group::Preparing ...'
  TEMP_PATH="$(mktemp -d)"
  REVIEWDOG_PATH="${TEMP_PATH}/reviewdog"
# echo '::endgroup::'

echo "::group::🐶 Installing reviewdog (${REVIEWDOG_VERSION}) ... https://github.com/reviewdog/reviewdog"
  curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh | sh -s -- -b "${REVIEWDOG_PATH}" "${REVIEWDOG_VERSION}" 2>&1
echo '::endgroup::'

# echo "::group:: Installing kics (${INPUT_KICS_VERSION}) ... https://github.com/Checkmarx/kics"
curl -sfL 'https://raw.githubusercontent.com/Checkmarx/kics/master/install.sh' | bash
# echo '::endgroup::'

echo "::group:: Print kics details ..."
  "kics" version
echo '::endgroup::'

echo '::group:: Running kics with reviewdog 🐶 ...'
  export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"

  # Allow failures now, as reviewdog handles them
  set +Eeuo pipefail

  # shellcheck disable=SC2086
  kics_exit=$("kics" scan --path ${INPUT_KICS_SCAN_PATH} --output-name kics --output-path . --report-formats json ${INPUT_KICS_FLAGS:-})
  jq -r -f "${GITHUB_ACTION_PATH}/to-rdjson.jq" kics.json \
    |  "${REVIEWDOG_PATH}/reviewdog" -f=rdjson \
        -name="kics" \
        -reporter="${INPUT_REPORTER}" \
        -level="${INPUT_LEVEL}" \
        -fail-on-error="${INPUT_FAIL_ON_ERROR}" \
        -filter-mode="${INPUT_FILTER_MODE}" \
        ${INPUT_FLAGS}

  kics_return="${kics_exit}" reviewdog_return="${PIPESTATUS[1]}" exit_code=$?
  echo "::set-output name=kics-return-code::${kics_return}"
  echo "::set-output name=reviewdog-return-code::${reviewdog_return}"
echo '::endgroup::'

exit "${exit_code}"
