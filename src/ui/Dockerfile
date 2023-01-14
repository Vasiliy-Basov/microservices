FROM ruby:2.3
# -qq - quite mode with no output
# build-essential это пакет обычно используется для сборки и компиляции другого программного обеспечения
# содержит gcc, make, and g++
RUN apt-get update -qq && apt-get install --no-install-recommends -y build-essential=12.3 \
    # Delete the apt-get lists after installing something рекомендация hadolint
    && apt-get clean \ 
    && rm -rf /var/lib/apt/lists/*

# создаем рабочий каталог /app
ENV APP_HOME /app
RUN mkdir $APP_HOME

# Задаем рабочий каталог
WORKDIR $APP_HOME

# Копируем в рабочий каталог файлы которые начинаются с Gemfile
# bundle install: Эта команда устанавливает зависимости прописаные в Gemfile и Gemfile.lock для Ruby 
COPY Gemfile* $APP_HOME/
RUN bundle install
COPY . $APP_HOME

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
