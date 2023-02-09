# The "as golang" portion of the line specifies a build-time alias for the image, 
# which can be used later in the Dockerfile for purposes such as copying files from the image.
FROM golang:1.20 as golang

# Задаем переменную
ARG VERSION=0.23.0

WORKDIR /go/src/github.com/blackbox_exporter

# The "make build" command is executing the build target specified in the "Makefile" for the Blackbox Exporter project. 
# This target will compile the application and produce the necessary binaries, libraries and other files required to run the Blackbox Exporter.
RUN git clone https://github.com/prometheus/blackbox_exporter.git . && \
    git checkout tags/v"${VERSION}" && \
    make build

# Финальный образ будет состоять из комбинации двух образов golang:1.11 + quay.io/prometheus/busybox:latest
FROM quay.io/prometheus/busybox:latest

COPY --from=golang /go/src/github.com/blackbox_exporter/blackbox_exporter  /bin/blackbox_exporter
COPY blackbox.yml       /etc/blackbox_exporter/config.yml

# Весь трафик который послан на порт 9115 хостовой машины будет перенаправлен в docker container
# To allow incoming traffic from outside the host, it is necessary to use the -p or --publish flag when running the Docker container, 
# which maps the exposed port to a port on the host.
EXPOSE      9115
# Инструкция ENTRYPOINT задает команду, которая (почти обязательно) выполняется при старте контейнера
ENTRYPOINT  [ "/bin/blackbox_exporter" ]
# Запускает команду при запуске контейнера 
CMD         [ "--config.file=/etc/blackbox_exporter/config.yml" ]
