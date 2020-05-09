FROM alpine:3.11

ENV REVIEWDOG_VERSION=v0.10.0

# hadolint ignore=DL3018
RUN apk --no-cache --update add bash git \
    && rm -rf /var/cache/apk/*

SHELL ["/bin/bash", "-eo", "pipefail", "-c"]

RUN wget -O - -q https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh | sh -s -- -b /usr/local/bin/

RUN wget -O - -q "$(wget -q https://api.github.com/repos/liamg/tfsec/releases/latest -O - | grep -o -E "https://.+?-linux-amd64")" > tfsec \
    && install tfsec /usr/local/bin/

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
