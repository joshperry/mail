FROM alpine:edge

RUN apk --no-cache add postfix

EXPOSE 25
EXPOSE 587
ENTRYPOINT ["postfix", "start-fg"]
