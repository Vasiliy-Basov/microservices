# Инструкция FROM указывает базовый образ, на основе которого мы строим свою сборку
FROM python:3.6.0-alpine

# Инструкция WORKDIR задает рабочую директорию при сборке все команды будут выполняться в этой рабочей директории
WORKDIR /app
# Копирует файлы из контекста в образ:
COPY . /app

# apk Менеджер пакетов для дистрибутива Alpine Linux.
# add установить новый пакет 
# build-base это пакет который содержит gcc, musl-dev, and libc-dev обычно используется для сборки и компиляции другого программного обеспечения
RUN apk update && apk add --no-cache build-base=0.4-r1 \
    && pip install -r /app/requirements.txt --no-cache-dir \
    && apk del build-base

# Инструкция ENV задает переменные окружения при сборке
ENV POST_DATABASE_HOST post_db
ENV POST_DATABASE posts

# Инструкция ENTRYPOINT задает команду, которая (почти обязательно) выполняется при старте контейнера
ENTRYPOINT ["python3", "post_app.py"]
