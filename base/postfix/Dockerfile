FROM alpine:3.10

RUN apk --no-cache add postfix spamassassin-client

EXPOSE 25
EXPOSE 587
ENTRYPOINT ["postfix", "start-fg"]
