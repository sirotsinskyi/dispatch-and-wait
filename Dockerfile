FROM alpine:latest

RUN apk update
RUN apk --no-cache add curl
RUN apk add jq
RUN apk add --update coreutils && rm -rf /var/cache/apk/*

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["sh", "/entrypoint.sh"]