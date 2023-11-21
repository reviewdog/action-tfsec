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
    Linux*)     os=Linux;;
    Darwin*)    os=macOS;;
    CYGWIN*)    os=Windows;;
    MINGW*)     os=Windows;;
    MSYS_NT*)   os=Windows;;
    *)          echo "Unknown system: ${unameOS}" && exit 1
  esac

  unameArch="$(uname -m)"
  case "${unameArch}" in
    x86*)      arch=64bit;;
    arm64)     arch=ARM64;;
    *)         echo "Unsupported architecture: ${unameArch}. Only AMD64 and ARM64 are supported by the action" && exit 1
    esac

  case "${os}" in 
    Windows)   archive_extension="zip";;
    *)         archive_extension="tar.gz";;
  esac

  TEMP_PATH="$(mktemp -d)"
  echo "Detected ${os} running on ${arch}, will install tools in ${TEMP_PATH}"
  REVIEWDOG_PATH="${TEMP_PATH}/reviewdog"
  TRIVY_PATH="${TEMP_PATH}/trivy"
echo '::endgroup::'

echo "::group::🐶 Installing reviewdog (${REVIEWDOG_VERSION}) ... https://github.com/reviewdog/reviewdog"
  curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh | sh -s -- -b "${REVIEWDOG_PATH}" "${REVIEWDOG_VERSION}" 2>&1
echo '::endgroup::'

echo "::group:: Installing trivy (${INPUT_TRIVY_VERSION}) ... https://github.com/aquasecurity/trivy"
  test ! -d "${TRIVY_PATH}" && install -d "${TRIVY_PATH}"

  archive="trivy.${archive_extension}"
  if [[ "${INPUT_TRIVY_VERSION}" = "latest" ]]; then
    # latest release is available on this url.
    # document: https://docs.github.com/en/repositories/releasing-projects-on-github/linking-to-releases
    latest_url="https://github.com/aquasecurity/trivy/releases/latest/"
    release=$(curl $latest_url -s -L -I -o /dev/null -w '%{url_effective}' | awk -F'/' '{print $NF}')
  else
    release="${INPUT_TRIVY_VERSION}"
  fi
  release_num=${release/#v/}
  url="https://github.com/aquasecurity/trivy/releases/download/${release}/trivy_${release_num}_${os}-${arch}.${archive_extension}"
  # Echo url for testing
  echo "Downloading ${url}"

  curl --silent --show-error --fail \
    --location "${url}" \
    --output "${archive}"
  if [[ "${os}" = "Windows" ]]; then
    unzip "${archive}"
  else
    tar -xzf "${archive}"
  fi
  install trivy "${TRIVY_PATH}"
echo '::endgroup::'

echo "::group:: Print trivy details ..."
  "${TRIVY_PATH}/trivy" --version
echo '::endgroup::'

echo '::group:: Running trivy with reviewdog 🐶 ...'
  export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"

  # Allow failures now, as reviewdog handles them
  set +Eeuo pipefail

  # shellcheck disable=SC2086
  "${TRIVY_PATH}/trivy" --format json ${INPUT_TRIVY_FLAGS:-} --exit-code 1 config . 2> /dev/null \
    | jq -r -f "${GITHUB_ACTION_PATH}/to-rdjson.jq" \
    |  "${REVIEWDOG_PATH}/reviewdog" -f=rdjson \
        -name="${INPUT_TOOL_NAME}" \
        -reporter="${INPUT_REPORTER}" \
        -level="${INPUT_LEVEL}" \
        -fail-on-error="${INPUT_FAIL_ON_ERROR}" \
        -filter-mode="${INPUT_FILTER_MODE}" \
        ${INPUT_FLAGS}

  trivy_return="${PIPESTATUS[0]}" reviewdog_return="${PIPESTATUS[2]}" exit_code=$?
  echo "trivy-return-code=${trivy_return}" >> "$GITHUB_OUTPUT"
  echo "reviewdog-return-code=${reviewdog_return}" >> "$GITHUB_OUTPUT"
echo '::endgroup::'

exit "${exit_code}"
