HW#14 (docker-1)
В данной работе мы:

установили docker, docker-compose, docker-machine;
рассмотрели жизненные цикл контейнера на примере hello-world и nginx;
рассмотрели отличия image и container.
Полезные команды:
$ docker info - информация о dockerd (включая количество containers, images и т.п.). $ docker version $ docker images - список всех images. $ docker ps - список запущенных на текущий момент контейнеров. $ docker ps -a - список всех контейнеров, в т.ч. остановленных. $ docker system df - информация о дисковом пространстве (контейнеры, образы и т.д.). $ docker inspect - подробная информация об объекте docker.

$ docker run hello-world - запуск контейнера hello-world. Может служить тестом на проверку работоспособности docker. $ docker run -it ubuntu:16.04 /bin/bash - пример того, как можно создать и запустить контейнер с последующим переходом в терминал. -i - запуск контейнера в foreground-режиме (docker attach). -d - запуск контейнера в background-режиме. -t - создание TTY. Пример:

docker run -it ubuntu:16.04 bash
docker run -dt nginx:latest Важные моменты:
если не указывать флаг --rm, то после остановки контейнер останется на диске;
docker run каждый раз запускает новый контейнер;
docker run = docker create + docker start;
$ docker start <u_container_id> - запуск остановленного контейнера. $ docker attach <u_container_id> - подключение к терминалу уже созданного контейнера.

$ docker exec <u_container_id> - запуск нового процесса внутри контейнера. Пример: docker exec -it <u_container_id> bash

$ docker commit <u_container_id> - создание image из контейнера.

$ docker kill <u_container_id> - отправка SIGKILL. $ docker stop <u_container_id> - отправка SIGTERM, затем (через 10 секунд) SIGKILL. Пример: docker kill $(docker ps -q) - уничтожение всех запущенных контейнеров.

$ docker rm <u_container_id> - удаление контейнер (должен быть остановлен). -f - позволяет удалить работающий контейнер (предварительно посылается SIGKILL). Пример: $ docker rm $(docker ps -a -q) - удаление всех незапущенных контейнеров.

$ docker rmi - удаление image, если от него не зависят запущенные контейнеры.

## HW#15 (docker-2)
В данной работе мы:
* создали docker host;
* описали Dockerfile;
* опубликовали Dockerfile на Docker Hub;
* подготовили прототип автоматизации деплоя приложения в связке Packer + Ansible Terraform.

### Docker machine
docker-machine - встроенный в докер инструмент для создания хостов и установки на них docker engine. Имеет поддержку облаков и систем виртуализации (Virtualbox, GCP и др.) 
Все докер команды, которые запускаются в той же консоли после eval $(docker-machine env <имя>) работают с удаленным докер демоном в GCP 
Latest docker release (20.10.0) doesn't work with docker-machine 
Поэтому мы должны брать конкретный образ и конкретную версию docker также нужно использовать поледнюю версию docker-machine  
Releases · docker/machine (github.com) 
Создание хоста с docker в GCP при помощи docker-machine:
```bash
$ docker-machine create --driver google --google-project docker-372311 --google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/ubuntu-1604-xenial-v20170815a --google-machine-type n1-standard-1 --google-zone europe-west1-b --engine-install-url "https://releases.rancher.com/install-docker/19.03.9.sh" docker-host
```
Проверяем, что наш Docker-хост успешно создан... 
```bash
docker-machine ls  
```
Переключение на удалённый docker (все команды docker будут выполняться на удалённом хосте):
```bash
eval $(docker-machine env <имя>)
```

Переключение на локальный докер:
```bash
eval $(docker-machine env --unset)
```

Удаление:
```bash
docker-machine rm <имя>
```

### Подготовка Dockerfile
Для полного описания контейнера нам потребуются следующие файлы:
* Dockerfile
* mongod.conf
* db_config
* start.sh

```dockerfile
# Дистрибутив ubuntu 16.04
FROM ubuntu:16.04
# Обновляем кэш репозитория и установим нужные пакеты mongo и ruby
RUN apt-get update
RUN apt-get install -y mongodb-server ruby-full ruby-dev build-essential git
# Если не указывать версию bundler то будет ошибка ERROR:  Error installing bundler:
# bundler requires Ruby version >= 2.6.0
RUN gem install bundler -v '1.16.1'
# Скачаем наше приложение в контейнер:
RUN git clone -b monolith https://github.com/express42/reddit.git
#Скопируем файлы конфигурации в контейнер:
COPY mongod.conf /etc/mongod.conf
COPY db_config /reddit/db_config
COPY start.sh /start.sh
#Теперь нам нужно установить зависимости приложения и произвести настройку:
RUN cd /reddit && bundle install
RUN chmod 0777 /start.sh
#Добавляем старт сервиса при старте контейнера:
CMD ["/start.sh"]
```

Теперь мы готовы собрать свой образ выполняем в нашем образе gcp  docker-host:
```bash
$ docker build -t reddit:latest .
```
Точка в конце обязательна, она указывает на путь до Docker-контекста 
Флаг -t задает тег для собранного образа 

 
смотрим созданные образы: 
```bash
sudo docker images -a 
```
 
Запускаем контейнер из нашего образа  
```bash
sudo docker run --name reddit -d --network=host reddit:latest 
```
Проверим результат: 
Список машин: 
```bash
docker-machine ls 
```
NAME          ACTIVE   DRIVER   STATE     URL                       SWARM   DOCKER     
docker-host   -        google   Running   tcp://34.78.65.110:2376           v19.03.9    

Так же нужно разрешить порт 9292 в файрвол 
```bash
gcloud compute firewall-rules create reddit-app --allow tcp:9292 --target-tags=docker-machine --description="Allow PUMA connections" --direction=INGRESS 
```

Проверим что приложение работает 
http://34.78.65.110:9292

### Docker hub
Аутентифицируемся на docker hub для продолжения работы: 
```bash
docker login 
```
Загрузим наш образ на docker hub для использования в будущем:
```bash
docker tag reddit:latest vasiliybasov/otus-reddit:1.0 
docker push vasiliybasov/otus-reddit:1.0 
```

### Полезные команды
Проверка, с какой командой будет запущен контейнер:
```bash
$ docker inspect weisdd/otus-reddit:1.0 -f '{{.ContainerConfig.Cmd}}'
```
Список изменений в ФС с момента запуска контейнера:
```bash
$ docker diff reddit
```

Т.к. теперь наш образ есть в докер хабе, то мы можем запустить его не только в докер хосте в GCP, 
но и в вашем локальном докере или на другом хосте. 

Выполним в другой консоли: 
```bash
docker run --name reddit -d -p 9292:9292 vasiliybasov/otus-reddit:1.0 
```
d – detached mode В таком случае можно будет спокойно закрыть терминал, а контейнер продолжит работу 
-p, --publish list          Publish a container's port(s) to the host 

проверим что приложение работает 
http://127.0.0.1:9292 

### Задание со * 
Задание:
Теперь, когда есть готовый образ с приложением, можно автоматизировать поднятие нескольких инстансов в GCP, установку на них докера и запуск там образа <your-login>/otus-reddit:1.0 Нужно реализовать в виде прототипа в директории /docker-monolith/infra/
* Поднятие инстансов с помощью Terraform, их количество задается переменной;
* Несколько плейбуков Ansible с использованием динамического инвентори для установки докера и запуска там образа приложения;
* Шаблон пакера, который делает образ с уже установленным Docker.

C помощью packer делаем образ с уже установленным docker
packer validate -var-file=packer/variables.json packer/docker_host.json
packer build -var-file=packer/variables.json packer/docker_host.json

/microservices/docker-monolith/infra/packer/docker_host.json 
/microservices/docker-monolith/infra/packer/variables.json 

Error при building в ubuntu 22.04
googlecompute: TASK [Gathering Facts] ********************************************************* 

==> googlecompute: failed to handshake 

    googlecompute: fatal: [default]: UNREACHABLE! => {"changed": false, "msg": "Failed to connect to the host via ssh: Unable to negotiate with 127.0.0.1 port 40011: no matching host key type found. Their offer: ssh-rsa", "unreachable": true} 

 

Решение: 

https://github.com/vmware-samples/packer-examples-for-vsphere/discussions/234?sort=new 
you may be required to update your /etc/ssh/ssh_config or .ssh/ssh_config to allow authentication with RSA keys if you are using VMware Photon OS 4.0 or Ubuntu 22.04. 
Update to include the following: 

PubkeyAcceptedAlgorithms ssh-rsa 
HostkeyAlgorithms ssh-rsa 

После создания образа нужно закоментировать эти строки потому что могут быть проблемы в будущем для ssh соединений. Например не работают id_ecdsa ssh ключи

Создаём instance с этим образом:
```bash
$ terraform apply
```
Деплоим контейнер:
```bash
infra/ansible$ ansible-playbook playbooks/otus_reddit.yml 
```

Теперь приложение доступно по адресу:
x.x.x.x:9292

## HW#16 (docker-3)
В данной работе мы:
* научились описывать и собирать Docker-образы для сервисного приложения;
* научились оптимизировать работу с Docker-образами;
* опробовали запуск и работу приложения на основе Docker-образов;
* оценили удобство запуска контейнеров при помощи docker run;
* переопределили ENV через docker run;
* оптимизировали размер контейнера (образ на базе Alpine).

Работа велась в каталоге src, где под каждый сервис существует отдельная директория (comment, post-py, ui). Для MongoDB использовался образ из Docker Hub.

Разбить наше приложение на несколько компонентов 
Запустить наше микросервисное приложение 

Линтер 
```
https://github.com/hadolint/hadolint 
```
 

Установка 
```bash
wget -O /bin/hadolint https://github.com/hadolint/hadolint/releases/download/v2.12.0/hadolint-Linux-x86_64 
```
 

Обновляем сертификаты если сменился ip 
```bash
docker-machine regenerate-certs docker-host 
```

Подключаемся к нашему хосту в GCP 
```bash
docker-machine ls 
eval $(docker-machine env docker-host) 
```
Теперь наше приложение состоит из трех компонентов: 
post-py - сервис отвечающий за написание постов 
comment - сервис отвечающий за написание комментариев 
ui - веб-интерфейс, работающий с другими сервисами 
Для работы нашего приложения также требуется база данных MongoDB 
Создаем в каждом каталоге три Dockerfile: 

В соответствии с рекомендациями hadolint было внесены изменения:
### ui/Dockerfile
RUN apt-get update -qq && apt-get install -y build-essential
=>
RUN apt-get update -qq && apt-get install -y build-essential --no-install-recommends \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ADD Gemfile* $APP_HOME/
=>
COPY Gemfile* $APP_HOME/

ADD . $APP_HOME
=>
COPY . $APP_HOME

### comment/Dockerfile
RUN apt-get update -qq && apt-get install -y build-essential
=>
RUN apt-get update -qq && apt-get install -y build-essential --no-install-recommends \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
	
ADD Gemfile* $APP_HOME/
=>
COPY Gemfile* $APP_HOME/

ADD . $APP_HOME
=>
COPY . $APP_HOME

### post-py/Dockerfile
ADD . /app
=>
COPY . /app

В Dockerfile со слайдов было обнаружено ряд проблем:
1. image для post-py не собирался, т.к. отсутствовал build-base. Обновлённый dockerfile выглядит следующим образом:

```dockerfile
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
```

2. образы для comment и ui не собирались из-за отсутствия одной записи в apt list:
```
W: Failed to fetch http://deb.debian.org/debian/dists/jessie-updates/InRelease  Unable to find expected entry 'main/binary-amd64/Packages' in Release file (Wrong sources.list entry or malformed file)
E: Some index files failed to download. They have been ignored, or old ones used instead.
```
Поэтому пришлось использовать другую версию контейнера:
FROM ruby:2.2
=>
FROM ruby:2.3

После этого все образы успешно собрались:

Не работает с последней версией mongodb так что нужно брать 
```bash
docker pull mongo:4.0-xenial 
```
Соберем образы с нашими сервисами: 
В файл requirments нужно добавить markupsafe==1.1.1 
```bash
docker build -t vasiliybasov/post:1.0 ./post-py 
docker build -t vasiliybasov/comment:1.0 ./comment 
docker build -t vasiliybasov/ui:1.0 ./ui 
```
Создадим специальную сеть для приложения: 

Эта сеть нужна чтобы соединять несколько docker контейнеров для коммуникации друг с другом. Без этой сети контейнеры не смогли бы общаться и должны были бы быть подключены через различные порты на хост-машине. Для удобства, в наших контейнерах использовались сетевые алиасы (отсылка к ним есть в ENV). Поскольку в сети по умолчанию алиасы недоступны, потребовалось создать отдельную bridge-сеть. 

```bash
docker network create reddit 
```
Запустим наши контейнеры: 

--network-alias в команде docker build используется для назначения container's hostname внутри пользовательской сети. Например, если вы запускаете команду docker build --network-alias myalias . в папке, где находится ваш Dockerfile, это создаст образ и запустит контейнер с хостнеймом "myalias" в указанной вами сети. 

Когда вы запускаете контейнер с этой опцией, он будет доступен для других контейнеров в той же сети с использованием указанного псевдонима. 

Опция --network-alias полезна, когда вы хотите подключить несколько контейнеров вместе и хотите, чтобы они могли общаться между собой с использованием хостнейма, а не IP-адресов. 

Важно понимать, что опция --network-alias относится только к хостнейму внутри пользовательской сети (reddit в нашем случае) 
```bash
docker run -d --network=reddit --network-alias=post_db --network-alias=comment_db mongo:4.0-xenial 
docker run -d --network=reddit --network-alias=post vasiliybasov/post:1.0 
docker run -d --network=reddit --network-alias=comment vasiliybasov/comment:1.0 
docker run -d --network=reddit -p 9292:9292 vasiliybasov/ui:1.0 
```

Чтобы зайти внурь контейнера alpine
```bash
docker exec -it <container_name_or_id> sh 
```

Ошибки (Errors) 

Смотрим ошибки в контейнерах 
```bash
docker logs <id container> 
```
Не работает с последней версией mongodb нужно брать  
```bash
docker pull mongo:4.0-xenial 
```
В файл requirments.txt post нужно добавить markupsafe==1.1.1 


Задание со * (стр. 15) 

Задание: Остановите контейнеры: docker kill $(docker ps -q) Запустите контейнеры с другими сетевыми алиасами. Адреса для взаимодействия контейнеров задаются через ENV-переменные внутри Dockerfile'ов. При запуске контейнеров (docker run) задайте им переменные окружения соответствующие новым сетевым алиасам, не пересоздавая образ. Проверьте работоспособность сервиса 

Решение: Переопределить ENV мы можем при помощи флага -e: 
```bash
docker run -d --network=reddit --network-alias=post_db2 --network-alias=comment_db2 mongo:4.0-xenial 
docker run -d --network=reddit --network-alias=post2 -e POST_DATABASE_HOST=post_db2 vasiliybasov/post 
docker run -d --network=reddit --network-alias=comment2 -e COMMENT_DATABASE_HOST=comment_db2 vasiliybasov/comment:1.0 
docker run -d --network=reddit -p 9292:9292 -e POST_SERVICE_HOST=post2 -e COMMENT_SERVICE_HOST=comment2 vasiliybasov/ui:1.0 
```
### Работа с образами
Уменьшаем размер образа с помощью пересборки и установки из ubuntu16 и самостоятельно устанавливаем ruby  
После внесения изменений в Dockerfile и пересборки образа:
```dockerfile
FROM ubuntu:16.04
# -qq - quite mode with no output
# build-essential это пакет обычно используется для сборки и компиляции другого программного обеспечения
# содержит gcc, make, and g++
RUN apt-get update -qq \
    && apt-get install --no-install-recommends -y ruby-full ruby-dev build-essential \
    && gem install bundler -v '1.17.2' --no-ri --no-rdoc \
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
```

Еше более существенное уменьшение образа:
ui/Dockerfile 

После перехода на Alpine образ уменьшился вдвое: 
```dockerfile
FROM alpine:3.9.4 
# -qq - quite mode with no output 
# build-essential это пакет обычно используется для сборки и компиляции другого программного обеспечения 
# содержит gcc, make, and g++ 
RUN RUN apk update && apk add --no-cache build-base ruby-full ruby-dev ruby-bundler \ 
&& gem install bundler -v '1.17.2' --no-ri --no-rdoc 
```

Более полная оптимизация:
- ruby вместо ruby-full (соответственно, нужно ставить отдельные компоненты вроде ruby-json);
- комбинирование всех команд, связанных с установкой приложения, в одну инструкцию RUN, что позволяет удалить build-base и ruby-dev после сборки приложения.
```dockerfile
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
```

В целом, миграция с ruby-full на ruby+отдельные компоненты не даёт большого выйгрыша в дисковом пространстве. При этом поддержка образа усложняется, поскольку при включении в приложение дополнительного компонента (в процессе разработки) придётся выполнять пересборку. Но для эксперимента сгодится.

Comment уменьшаем соответствующим образом. См Dockerfile.1 Dockerfile

Volume 

Если перезапустить контейнеры то все данные базы данных пропадут. Что бы данные сохранялись нужно использовать volume  
Создаем volume 
```bash
docker volume create reddit_db 
```
 

И подключим его к контейнеру с MongoDB... 
Команда -v reddit_db:/data/db 
Выключим старые копии контейнеров: 
```bash
docker kill $(docker ps -q) 
```
 
Запускаем 
```bash
docker run -d --network=reddit --network-alias=post_db --network-alias=comment_db -v reddit_db:/data/db mongo:4.0-xenial 
docker run -d --network=reddit --network-alias=post vasiliybasov/post:1.0 
docker run -d --network=reddit --network-alias=comment vasiliybasov/comment:2.1 
docker run -d --network=reddit -p 9292:9292 vasiliybasov/ui:2.2 
```
 
Делаем рестарт и проверяем что база не пропала 
```bash
docker restart $(docker ps -q) 
```




