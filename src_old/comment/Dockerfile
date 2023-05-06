# Инструкция FROM указывает базовый образ
FROM alpine:3.9.4

ENV APP_HOME /app
RUN mkdir $APP_HOME
WORKDIR $APP_HOME
COPY . $APP_HOME

RUN apk update && apk add --no-cache build-base ruby ruby-json ruby-bigdecimal ruby-dev ruby-bundler \
	&& gem install bundler -v '1.17.2' --no-ri --no-rdoc \
# bundle install: Эта команда устанавливает зависимости прописаные в Gemfile и Gemfile.lock для Ruby
	&& bundle install \
	&& apk del build-base ruby-dev

# The variables COMMENT_DATABASE_HOST and COMMENT_DATABASE are being set to comment_db and comments respectively. 
# В переменных указывается к каким хостам и по каким портам мы будем подключаться в созданной нами сети reddit т.е. comment_db
# Эти имена задаются ключем --network-alias=comment_db при docker build, можем переопределять эти переменные при запуске контейнера docker run ключем -e
ENV COMMENT_DATABASE_HOST comment_db
ENV COMMENT_DATABASE comments

# Запускает команду при запуске контейнера (старт puma web server)
CMD ["puma"]
