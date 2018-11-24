FROM golang:1.11-alpine3.8
ADD . /go/src/github.com/kumina/dovecot_exporter
WORKDIR /go/src/github.com/kumina/dovecot_exporter
RUN apk add --no-cache git && \
    go get -v github.com/kumina/dovecot_exporter && \
    go build

FROM alpine:3.8
EXPOSE 9166
WORKDIR /
COPY --from=0 /go/src/github.com/kumina/dovecot_exporter/dovecot_exporter .
ENTRYPOINT ["/dovecot_exporter"]
