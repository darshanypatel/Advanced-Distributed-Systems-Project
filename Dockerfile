FROM ubuntu:16.04

COPY checkbox.io/ /home/checkboxio/

WORKDIR /home/checkboxio/server-side/site

RUN apt -y update && apt install -y python-minimal
RUN apt-get install -y git nodejs-legacy nginx npm python-pip
RUN pip install pymongo

RUN mv /home/checkboxio/local-conf/default /etc/nginx/sites-available/default
RUN sed -i "s|.*gameweld.*|  root /home/checkboxio/public_html;|g" /etc/nginx/sites-available/default
RUN mv /home/checkboxio/local-conf/nginx.conf /etc/nginx/nginx.conf
ENV MONGO_PORT 3002
ENV MONGO_IP 127.0.0.1
ENV MONGO_USER myUserAdmin
ENV MONGO_PASSWORD abc123

RUN \
  apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10 && \
  echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' > /etc/apt/sources.list.d/mongodb.list && \
  apt-get update && \
  apt-get install -y mongodb-org && \
  rm -rf /var/lib/apt/lists/*

# ADD A MONGODB ADMIN USER
ADD create_user.js /tmp/

RUN mkdir -p /data/db

EXPOSE 27017

RUN npm install

EXPOSE 80

CMD service nginx restart && mongod -f /etc/mongod.conf --fork --logpath /var/log/mongodb.log \
    && mongo admin /tmp/create_user.js && node server.js
