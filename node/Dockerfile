FROM node:7.2.1

RUN npm install -g bower gulp yarn

RUN echo '{ "allow_root": true }' > /root/.bowerrc

WORKDIR /data/app

CMD ["bash"]