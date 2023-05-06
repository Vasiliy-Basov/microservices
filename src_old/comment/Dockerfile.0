# Инструкция FROM указывает базовый образ
FROM ruby:2.3
# -qq - quite mode with no output
# build-essential это пакет обычно используется для сборки и компиляции другого программного обеспечения
# содержит gcc, make, and g++
RUN apt-get update -qq && apt-get install --no-install-recommends -y build-essential=12.3 \
    # Delete the apt-get lists after installing something рекомендация hadolint
    && apt-get clean \ 
    && rm -rf /var/lib/apt/lists/*

ENV APP_HOME /app
RUN mkdir $APP_HOME
WORKDIR $APP_HOME

COPY Gemfile* $APP_HOME/
# bundle install: Эта команда устанавливает зависимости прописаные в Gemfile и Gemfile.lock для Ruby
RUN bundle install
COPY . $APP_HOME

# The variables COMMENT_DATABASE_HOST and COMMENT_DATABASE are being set to comment_db and comments respectively. 
# В переменных указывается к каким хостам и по каким портам мы будем подключаться в созданной нами сети reddit т.е. comment_db
# Эти имена задаются ключем --network-alias=comment_db при docker build, можем переопределять эти переменные при запуске контейнера docker run ключем -e
ENV COMMENT_DATABASE_HOST comment_db
ENV COMMENT_DATABASE comments

# Запускает команду при запуске контейнера (старт puma web server)
CMD ["puma"]
