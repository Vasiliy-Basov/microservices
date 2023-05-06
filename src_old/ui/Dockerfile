FROM alpine:3.9.4

ENV APP_HOME /app
RUN mkdir $APP_HOME
WORKDIR $APP_HOME
COPY . $APP_HOME

# -qq - quite mode with no output
# build-essential это пакет обычно используется для сборки и компиляции другого программного обеспечения
# содержит gcc, make, and g++
RUN apk update && apk add --no-cache build-base ruby ruby-json ruby-dev ruby-bundler \
	&& gem install bundler -v '1.17.2' --no-ri --no-rdoc \
	&& bundle install \
	&& apk del build-base ruby-dev

# Инструкция ENV задает переменные окружения при сборке
# The variables POST_SERVICE_HOST and POST_SERVICE_PORT are being set to post and 5000 respectively. 
# В переменных указывается к каким хостам и по каким портам мы будем подключаться в созданной нами сети reddit т.е. post:5000 comment:9292 
# Эти имена задаются ключем --network-alias=post при docker build, можем переопределять эти переменные при запуске контейнера docker run ключем -e
ENV POST_SERVICE_HOST post
ENV POST_SERVICE_PORT 5000
ENV COMMENT_SERVICE_HOST comment
ENV COMMENT_SERVICE_PORT 9292

# Запускает команду при запуске контейнера (старт puma web server)
CMD ["puma"]
