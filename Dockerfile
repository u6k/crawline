FROM ruby:2.5
LABEL maintainer="u6k.apps@gmail.com"

RUN apt-get update && \
    apt-get install -y \
        nodejs && \
    apt-get clean

VOLUME /var/myapp
WORKDIR /var/myapp

COPY Gemfile .
COPY Gemfile.lock .

RUN bundle install

EXPOSE 3000

CMD ["bin/entrypoint.sh"]
