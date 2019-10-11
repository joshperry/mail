FROM golang:1.11-alpine3.8

RUN apk add git	&& \
	go get -d -v github.com/kumina/postfix_exporter && \
	cd /go/src/github.com/kumina/postfix_exporter && \
    go build -tags nosystemd

FROM alpine:3.8
EXPOSE 9166
WORKDIR /
COPY --from=0 /go/src/github.com/kumina/postfix_exporter/postfix_exporter .
ENTRYPOINT ["/postfix_exporter"]
