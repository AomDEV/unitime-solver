FROM alpine

WORKDIR /app

RUN apk add openjdk11 --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community \
    && apk update \
    && apk add --no-cache bash \
    && apk add jq curl

COPY .env config*.cfg solver.sh ./
COPY cpsolver.zip ./

RUN chmod 777 solver.sh

CMD ["/app/solver.sh"]