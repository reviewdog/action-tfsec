#!/bin/bash

# Print commands for debugging
if [[ "$RUNNER_DEBUG" = "1" ]]; then
  set -x
fi

# Fail fast on errors, unset variables, and failures in piped commands
set -Eeuo pipefail

cd "${GITHUB_WORKSPACE}/${INPUT_WORKING_DIRECTORY}" || exit

echo '::group::Preparing ...'
  unameOS="$(uname -s)"
  case "${unameOS}" in
    Linux*)     os=linux;;
    Darwin*)    os=darwin;;
    CYGWIN*)    os=windows;;
    MINGW*)     os=windows;;
    MSYS_NT*)   os=windows;;
    *)          echo "Unknown system: ${unameOS}" && exit 1
  esac

  unameArch="$(uname -m)"
  case "${unameArch}" in
    x86*)      arch=amd64;;
    *)         echo "Unsupported architecture: ${unameArch}. Only AMD64 is supported by kics" && exit 1
    esac

  TEMP_PATH="$(mktemp -d)"
  echo "Detected ${os} running on ${arch}, will install tools in ${TEMP_PATH}"
  REVIEWDOG_PATH="${TEMP_PATH}/reviewdog"
  KICS_PATH="${TEMP_PATH}/kics"
echo '::endgroup::'

echo "::group::🐶 Installing reviewdog (${REVIEWDOG_VERSION}) ... https://github.com/reviewdog/reviewdog"
  curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh | sh -s -- -b "${REVIEWDOG_PATH}" "${REVIEWDOG_VERSION}" 2>&1
echo '::endgroup::'

echo "::group:: Installing kics (${INPUT_KICS_VERSION}) ... https://github.com/Checkmarx/kics"
  test ! -d "${KICS_PATH}" && install -d "${KICS_PATH}"

  if [[ "${INPUT_KICS_VERSION}" = "latest" ]]; then
    kics_version=$(curl --silent -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${INPUT_GITHUB_TOKEN}" https://api.github.com/repos/aquasecurity/kics/releases/latest | jq -r .tag_name)
  else
    kics_version=${INPUT_KICS_VERSION}
  fi
  binary="kics"
  url="https://github.com/Checkmarx/kics/releases/download/${kics_version}/kics_${kics_version}_${os}_${arch}.tar.gz"

  curl --silent --show-error --fail \
    --location "${url}" \
    --output "${binary}"
  tar -xvzf kics_${kics_version}_${os}_${arch}.tar.gz
  install kics "${KICS_PATH}"
echo '::endgroup::'

echo "::group:: Print kics details ..."
  "${KICS_PATH}/kics" --version
echo '::endgroup::'

echo '::group:: Running kics with reviewdog 🐶 ...'
  export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"

  # Allow failures now, as reviewdog handles them
  set +Eeuo pipefail

  # shellcheck disable=SC2086
  "${KICS_PATH}/kics" --format=json ${INPUT_KICS_FLAGS:-} . \
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
