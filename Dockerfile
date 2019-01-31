FROM ruby:2.6
LABEL maintainer="u6k.apps@gmail.com"

RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get clean

VOLUME /var/myapp
WORKDIR /var/myapp

ENV CRAWLINE_LOGGER_LEVEL INFO

CMD ["bash"]
