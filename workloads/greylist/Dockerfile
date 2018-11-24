FROM alpine:3.8

RUN apk --no-cache add postgrey

EXPOSE 10030
ENTRYPOINT ["postgrey", "--inet=0.0.0.0:10030"]
