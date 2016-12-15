FROM node:7.2.1-alpine

RUN apk --no-cache --no-cache add bash git openssh python gcc g++ make

RUN npm install -g bower gulp yarn node-sass

RUN echo '{ "allow_root": true }' > /root/.bowerrc

# hack for the issue: https://github.com/yarnpkg/yarn/issues/918
# create a fake user to handle yarn cache process
RUN adduser -D foo && chown -R foo /home/foo && mkdir -p /data/app && chown -R foo /data/app
USER foo
# end hack https://github.com/yarnpkg/yarn/issues/918

WORKDIR /data/app

CMD ["bash"]