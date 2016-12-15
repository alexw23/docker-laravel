FROM nginx:1.10-alpine

RUN \
    apk add --update --no-cache \
        curl

COPY ./default.conf /etc/nginx/conf.d/