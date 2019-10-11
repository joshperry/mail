FROM alpine:3.10

RUN apk --no-cache add postgrey

EXPOSE 10030
ENTRYPOINT ["postgrey", "--inet=0.0.0.0:10030"]
