FROM alpine:3.8

RUN apk --no-cache add dovecot dovecot-pigeonhole-plugin dovecot-fts-lucene

EXPOSE 143
EXPOSE 993
ENTRYPOINT ["dovecot", "-F"]
