FROM fluent/fluentd:v1.12.0-debian-1.0
USER root
RUN gem uninstall -I elasticsearch && gem install elasticsearch -v 7.17.0
RUN ["gem", "install", "fluent-plugin-elasticsearch", "--no-document", "--version", "5.0.3"]
RUN gem install fluent-plugin-grok-parser -v 2.6.2
COPY fluent.conf /fluentd/etc
USER fluent