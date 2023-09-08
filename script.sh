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
    arm64)     arch=arm64;;
    *)         echo "Unsupported architecture: ${unameArch}. Only AMD64 and ARM64 are supported by the action" && exit 1
    esac

  TEMP_PATH="$(mktemp -d)"
  echo "Detected ${os} running on ${arch}, will install tools in ${TEMP_PATH}"
  REVIEWDOG_PATH="${TEMP_PATH}/reviewdog"
  TFSEC_PATH="${TEMP_PATH}/tfsec"
echo '::endgroup::'

echo "::group::🐶 Installing reviewdog (${REVIEWDOG_VERSION}) ... https://github.com/reviewdog/reviewdog"
  curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh | sh -s -- -b "${REVIEWDOG_PATH}" "${REVIEWDOG_VERSION}" 2>&1
echo '::endgroup::'

echo "::group:: Installing tfsec (${INPUT_TFSEC_VERSION}) ... https://github.com/aquasecurity/tfsec"
  test ! -d "${TFSEC_PATH}" && install -d "${TFSEC_PATH}"

  if [[ "${INPUT_TFSEC_VERSION}" = "latest" ]]; then
    tfsec_version=$(curl --silent -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${INPUT_GITHUB_TOKEN}" https://api.github.com/repos/aquasecurity/tfsec/releases/latest | jq -r .tag_name)
  else
    tfsec_version=${INPUT_TFSEC_VERSION}
  fi
  binary="tfsec"
  url="https://github.com/aquasecurity/tfsec/releases/download/${tfsec_version}/tfsec-${os}-${arch}"
  if [[ "${os}" = "windows" ]]; then
    url+=".exe"
    binary+=".exe"
  fi

  curl --silent --show-error --fail \
    --location "${url}" \
    --output "${binary}"
  install tfsec "${TFSEC_PATH}"
echo '::endgroup::'

echo "::group:: Print tfsec details ..."
  "${TFSEC_PATH}/tfsec" --version
echo '::endgroup::'

echo '::group:: Running tfsec with reviewdog 🐶 ...'
  export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"

  # Allow failures now, as reviewdog handles them
  set +Eeuo pipefail

  # shellcheck disable=SC2086
  "${TFSEC_PATH}/tfsec" --format=json ${INPUT_TFSEC_FLAGS:-} . \
    | jq -r -f "${GITHUB_ACTION_PATH}/to-rdjson.jq" \
    |  "${REVIEWDOG_PATH}/reviewdog" -f=rdjson \
        -name="tfsec" \
        -reporter="${INPUT_REPORTER}" \
        -level="${INPUT_LEVEL}" \
        -fail-on-error="${INPUT_FAIL_ON_ERROR}" \
        -filter-mode="${INPUT_FILTER_MODE}" \
        ${INPUT_FLAGS}

  tfsec_return="${PIPESTATUS[0]}" reviewdog_return="${PIPESTATUS[2]}" exit_code=$?
  echo "tfsec-return-code=${tfsec_return}" >> "$GITHUB_OUTPUT"
  echo "reviewdog-return-code=${reviewdog_return}" >> "$GITHUB_OUTPUT"
echo '::endgroup::'

exit "${exit_code}"
