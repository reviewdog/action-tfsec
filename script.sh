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
    *)         echo "Unsupported architecture: ${unameArch}. Only AMD64 is supported by tfsec" && exit 1
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

  binary="tfsec"
  if [[ "${INPUT_TFSEC_VERSION}" = "latest" ]]; then
    # latest release is available on this url.
    # document: https://docs.github.com/en/repositories/releasing-projects-on-github/linking-to-releases
    url="https://github.com/aquasecurity/tfsec/releases/latest/download/tfsec-${os}-${arch}"
  else
    url="https://github.com/aquasecurity/tfsec/releases/download/${INPUT_TFSEC_VERSION}/tfsec-${os}-${arch}"
  fi
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
    | {
      # workaround for #95
      # remove "tfsec is joining the Trivy family" banner
      perl -E 'undef $/; my $txt = <>; $txt =~ s/^[^{]*//m; print $txt'
    } \
    | jq -r -f "${GITHUB_ACTION_PATH}/to-rdjson.jq" \
    |  "${REVIEWDOG_PATH}/reviewdog" -f=rdjson \
        -name="${INPUT_TOOL_NAME}" \
        -reporter="${INPUT_REPORTER}" \
        -level="${INPUT_LEVEL}" \
        -fail-on-error="${INPUT_FAIL_ON_ERROR}" \
        -filter-mode="${INPUT_FILTER_MODE}" \
        ${INPUT_FLAGS}

  tfsec_return="${PIPESTATUS[0]}" reviewdog_return="${PIPESTATUS[3]}" exit_code=$?
  echo "tfsec-return-code=${tfsec_return}" >> "$GITHUB_OUTPUT"
  echo "reviewdog-return-code=${reviewdog_return}" >> "$GITHUB_OUTPUT"
echo '::endgroup::'

exit "${exit_code}"
