FROM golang:1.11-alpine3.8

RUN apk add --no-cache git && \
    go get -d -v github.com/kumina/dovecot_exporter && \
	cd /go/src/github.com/kumina/dovecot_exporter && \
    go build 

FROM alpine:3.8
EXPOSE 9166
WORKDIR /
COPY --from=0 /go/src/github.com/kumina/dovecot_exporter/dovecot_exporter .
ENTRYPOINT ["/dovecot_exporter"]
