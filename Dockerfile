FROM alpine:3.17.0

RUN apk add --no-cache --update bash curl coreutils

COPY ./basher.sh ./basher.sh

ENTRYPOINT ["./basher.sh"]
