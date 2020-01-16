FROM alpine:3.11

RUN apk --no-cache --update add git curl \
    && rm -rf /var/cache/apk/*

RUN wget -O - -q https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh | sh -s -- -b /usr/local/bin/

RUN curl -L "$(curl -s https://api.github.com/repos/liamg/tfsec/releases/latest | grep -o -E "https://.+?-linux-amd64")" > tfsec \
    && install tfsec /usr/local/bin/

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
