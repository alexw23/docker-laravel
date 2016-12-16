FROM node:7.2.1-alpine

RUN apk --no-cache --no-cache add bash git openssh python gcc g++ make

RUN npm install -g bower gulp yarn node-sass

RUN echo '{ "allow_root": true }' > /root/.bowerrc

WORKDIR /data/app

CMD ["bash"]