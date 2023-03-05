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


Docker-4 

•Работа с сетями в Docker 

•Использование docker-compose 

 

Разобраться с работой сети в Docker 

•none 

•host 

•bridge 

 

None 

Запустим контейнер с использованием none-драйвера. 

docker run -ti --rm --network none joffotron/docker-net-tools -c ifconfig – запускается контейнер выполняется команда ifconfig и удаляется 

В результате, видим: 

•что внутри контейнера из сетевых интерфейсов 

существует только loopback. 

•сетевой стек самого контейнера работает (ping localhost), 

но без возможности контактировать с внешним миром. 

•Значит, можно даже запускать сетевые сервисы внутри 

такого контейнера, но лишь для локальных 

экспериментов (тестирование, контейнеры для 

выполнения разовых задач и т.д.) 

 

Host network driver 

docker run -ti --rm --network host joffotron/docker-net-tools -c ifconfig 

docker-machine ssh docker-host ifconfig 

выводы этих команд одинаковые и В данном случае будет использоваться namespace хоста. 

 

Если выполнить команду  

docker run --network host -d nginx 

Несколько раз в итогк запущенным окажется только первый контейнер поскольку каждый последующий пытался использовать уже занятый порт: 

docker  ps –a смотрим контейнеры 

Смотрим лог незапущеных контейнеров и видим что порт уже занят: 

docker logs bb955418d4b9 

 

network namespaces 

Именованные пространства сети (network namespaces) - это механизм в Linux, который позволяет создавать и использовать несколько изолированных окружений сети на одной машине. Каждое именованное пространство сети имеет собственные сетевые интерфейсы, таблицы маршрутизации и другие сетевые настройки, независимые от других именованных пространств сети на той же машине. 

Именованные пространства сети могут использоваться для разделения сетевой инфраструктуры между различными приложениями или службами на одной машине, или для создания виртуальных сетей на одной физической инфраструктуре. Они также могут использоваться для соз дания виртуальных окружений для тестирования или для изоляции служб для безопасности. 

Именованные пространства сети также используются в контейнерной технологии, такой как Docker. Каждый контейнер в Docker работает в своем собственном именованном пространстве сети, изолированном от других контейнеров и от хост-системы. 

 

sudo ip netns - это команда из пакета iproute2, которая используется для работы с именованными пространствами сети (network namespaces). 

Команда ip netns без дополнительных параметров выводит список именованных пространств сети, созданных на системе. 

На docker-host машине выполните команду: 

> sudo ln -s /var/run/docker/netns /var/run/netns 

Эта команда может использоваться для получения доступа к сетевым интерфейсам или таблицам маршрутизации, или именованным пространствам созданным для контейнеров  

 

Просмотрим наши именованные пространства до создания контейнеров  

sudo ip netns 

 

Повторите запуски контейнеров с использованием драйверов none и host и посмотрите, как меняется список namespace-ов. 

В случае none создается новое именованое пространство в случае host остается старое default 

 

ip netns exec <namespace> <command> - позволит выполнять команды в выбранном namespace 

 

Bridge network driver 

Создадим bridge-сеть в docker (флаг --driver указывать не обязательно, т.к. по-умолчанию используется bridge 

 

Что бы контейнеры знали о существовании друг друга нужно запускать их с командой --network-alias <alias-name> для присвоения контейнерам имен или сетевых алиасов при старте. Соответствующие ссылки на эти алиасы мы прописываем в dockerfile в ENV пересменных или можем их переназначить с помощью флага -e. 

docker run -d --network=reddit -p 9292:9292 -e POST_SERVICE_HOST=post2 -e COMMENT_SERVICE_HOST=comment2 vasiliybasov/ui:1.0 

--name <name> (можно задать только 1 имя) 

--network-alias <alias-name> (можно задать множество алиасов) 

Запускаеим 

docker run -d --network=reddit --network-alias=post_db --name mongo_db --network-alias=comment_db -v reddit_db:/data/db mongo:4.0-xenial 

docker run -d --network=reddit --name post --network-alias=post vasiliybasov/post:1.0 

docker run -d --network=reddit --name comment --network-alias=comment vasiliybasov/comment:2.1 

docker run -d --network=reddit --name ui -p 9292:9292 vasiliybasov/ui:2.2 

 

Чтобы изменить имя у запущенного Docker контейнера, вы можете использовать команду docker rename. Эта команда принимает два аргумента: текущее имя контейнера и новое имя. 

docker rename old_container_name new_container_name 

 

 

Давайте запустим наш проект в 2-х bridge сетях. Так , чтобы сервис ui не имел 

доступа к базе данных в соответствии со схемой ниже. 

 

 

 

Остановим старые копии контейнеров 

> docker kill $(docker ps -q) 

Создадим docker-сети 

docker network create back_net --subnet=10.0.2.0/24 

docker network create front_net --subnet=10.0.1.0/24 

docker network ls -  посмотреть текущие сети 

 

Запускаем контейнеры 

docker run -d --network=back_net --network-alias=post_db –name mongo_db --network-alias=comment_db -v reddit_db:/data/db mongo:4.0-xenial 

docker run -d --network=back_net –name post --network-alias=post vasiliybasov/post:1.0 

docker run -d --network=back_net –name comment --network-alias=comment vasiliybasov/comment:2.1 

docker run -d --network=front_net –name ui -p 9292:9292 vasiliybasov/ui:2.2 

 

Docker при инициализации контейнера может подключить к нему только 1 

Сеть. При этом контейнеры из соседних сетей не будут доступны как в DNS, так 

и для взаимодействия по сети. 

Поэтому нужно поместить контейнеры post и comment в обе сети. 

 

Дополнительные сети подключаются командой: 

docker network connect <network> <container> 

 

Подключим контейнеры ко второй сети 

> docker network connect front_net post 

> docker network connect front_net comment 

 

 

Зайдем на docker-host c помощью docker-machine и установим bridge-utils 

docker-machine ssh docker-host 

sudo apt-get update && sudo apt-get install bridge-utils 

Посмотрим какие у нас есть сети созданные в рамках проекта 

sudo docker network ls 

Посмотрим какие у нас есть bridge сети 

ifconfig | grep br : 

br-01c10fd97202 Link encap:Ethernet  HWaddr 02:42:e0:06:b6:be   

br-43062ace22e0 Link encap:Ethernet  HWaddr 02:42:fd:e3:1d:56   

br-861d17ca1b77 Link encap:Ethernet  HWaddr 02:42:7b:b9:5f:91 

 

Посмотри информайию о кокретной bridge сети 

brctl show br-01c10fd97202 : 

bridge name	bridge id		STP enabled	interfaces 

br-01c10fd97202		8000.0242e006b6be	no		veth5276184 

veth67d2329 

vethe580368 

 

 

 

Отображаемые veth-интерфейсы - это те части виртуальных пар 

интерфейсов (2 на схеме), которые лежат в сетевом пространстве хоста и 

также отображаются в ifconfig. Вторые их части лежат внутри контейнеров 

 

Про Iptables см. В Linux.docx  

Давайте посмотрим как выглядит iptables. Выполним: 

sudo iptables -nL -t nat  - то команда для просмотра таблицы NAT в iptables. 

-nL - опция, которая показывает правила без перевода IP адресов и имен хостов в их читаемые формы. 

-t nat - опция, которая указывает iptables просмотреть таблицу NAT. 

В результате эта команда будет выводить список правил в таблице NAT в iptables, без перевода IP-адресов и имен хостов в читаемые формы. 

 

Обратите внимание на цепочку POSTROUTING. В ней вы увидите нечто подобное 

 

Chain POSTROUTING (policy ACCEPT) 

target              prot opt source               destination          

MASQUERADE  all  --  10.0.1.0/24          0.0.0.0/0            

MASQUERADE  all  --  10.0.2.0/24          0.0.0.0/0            

MASQUERADE  all  --  172.17.0.0/16        0.0.0.0/0            

MASQUERADE  all  --  172.18.0.0/16        0.0.0.0/0            

MASQUERADE  tcp  --  10.0.1.2             10.0.1.2             tcp dpt:9292 

 

Выделенные правила отвечают за выпуск трафика во внешнюю сеть контейнеров из bridge-сетей 

 

POSTROUTING — применяется преобразование сетевых адресов NAT для изменения  

сетевых пакетов до того, как они выйдут из сервера Linux. 

Она используется для маскирования или изменения исходящих IP-адресов пакетов. 

 

policy ACCEPT означает, что по умолчанию все пакеты, которые проходят через эту цепочку, будут приняты. 

 

Target MASQUERADE используется для маскировки исходящего IP-адреса для всех пакетов из подсети 10.0.1.0/24 к адресу сети 0.0.0.0/0 (все ip адреса) 

 

В ходе работы у нас была необходимость публикации порта контейнера UI (9292) для доступа к нему снаружи. Давайте посмотрим, что Docker при этом сделал. Снова взгляните в iptables 

на таблицу nat. 

Обратите внимание на цепочку DOCKER и правила DNAT в ней. 

Chain DOCKER (2 references) 

target     prot opt source               destination 

DNAT       tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:9292 to:10.0.1.2:9292 

 

Они отвечают за перенаправление трафика на адреса уже конкретных контейнеров. 

 

Chain DOCKER это одна из цепочек (Chain) в iptables, которая используется для манипуляции пакетами, связанными с Docker. Эта цепочка создается динамически при запуске Docker и используется для настройки маршрутизации пакетов между контейнером и хостом. 

(2 references) означает, что эта цепочка используется 2 раза. 

 

target DNAT - это целевое действие, которое используется для изменения назначения IP-адреса пакета при передаче его в другую сеть. 

 

tcp dpt:9292 to:10.0.1.2:9292 - правило которое пробрасывает соединения из порта 9292 на хосте на порт 9292 на IP адрес 10.0.1.2 внутри контейнера. Это означает, что любые соединения, которые поступают на порт 9292 на хосте, будут перенаправлены на порт 9292 на IP-адрес 10.0.1.2 внутри контейнера. Это позволяет вам подключаться к службе, запущенной внутри контейнера, используя адрес хоста и порт. 

 

Выполним еще  

ps ax | grep docker-proxy 

 

ps ax - эта команда выводит список всех процессов, которые сейчас запущены на системе, включая их состояния, идентификаторы и команды. 

 

Docker-proxy - это демон, который используется для проксирования соединений на контейнер из внешнего мира. Он создает сокеты, которые прослушивают нужные порты и перен 

 

Вывод : 

  936 pts/1    S+     0:00 grep --color=auto docker-proxy 

15566 ?        Sl     0:00 /usr/bin/docker-proxy -proto tcp -host-ip 0.0.0.0 -host-port 9292 -container-ip 10.0.1.2 -container-port 9292 

 

Вы должны увидеть хотя бы 1 запущенный процесс docker-proxy. 

Этот процесс в данный момент слушает сетевой tcp-порт 9292. 

 

Docker-compose 

•Одно приложение состоит из множества контейнеров/сервисов 

•Один контейнер зависит от другого 

•Порядок запуска имеет значение 

•docker build/run/create … (долго и много) 

 

 

•Отдельная утилита 

•Декларативное описание docker-инфраструктуры в YAML-формате 

•Управление многоконтейнерными приложениями 

 

 

План 

Установить docker-compose на локальную машину 

•Собрать образы приложения reddit с помощью docker-compose 

•Запустить приложение reddit с помощью docker-compose 

 

Наш docker-compose.yml: 

/home/baggurd/microservices/src/docker-compose.yml 

 

Отметим, что docker-compose поддерживает подстановку переменных окружения 

В данном случае это переменная USERNAME. Поэтому перед запуском необходимо экспортировать значения данных переменных окружения. 

 

Остановим контейнеры, запущенные на предыдущих шагах 

> docker kill $(docker ps -q) 

 

Добавляем переменную окружения 

export USERNAME=vasiliybasov 

 

Также переменные окружения можно помещать в файл .env который находится в том же каталоге что и docker-compose.yml 

 

Задание: 

1) Изменить docker-compose под кейс с множеством сетей, сетевых алиасов (стр 18). 

2) Параметризуйте с помощью переменных окружений: 

•порт публикации сервиса ui 

•версии сервисов 

•возможно что-либо еще на ваше усмотрение 

3) Параметризованные параметры запишите в отдельный файл c расширением .env 

4) Без использования команд source и export 

docker-compose должен подхватить переменные из этого файла. Проверьте 

 

Создаем файл с нужными нам переменными .env 

USERNAME=vasiliybasov 

UI_PORT=9292 

UI_VERSION=2.2 

POST_VERSION=1.0 

COMMENT_VERSION=2.0 

MONGODB_VERSION=4.0-xenial 

COMPOSE_PROJECT_NAME=test # этот параметр задает имя проекта вместо имени по умолчанию все создаваемые сущности будут иметь этот префикс 

 

Наш основной файл 
/home/baggurd/microservices/src/docker-compose.yml 

Docker Compose файл содержит конфигурацию для создания и управления несколькими контейнерами Docker. В файле используется синтаксис версии 3.3. 

В секции services описаны четыре сервиса: post_db, post, comment и ui. Каждый сервис описывается с помощью конфигурационных параметров, таких как image, build, ports и networks. 

post_db: сервис использует образ MongoDB с версией, определенной в переменной окружения MONGODB_VERSION. Сервис также использует существующий том reddit_db для хранения данных и подключается к сети back_net с псевдонимами post_db и comment_db. 

post: сервис построен из Dockerfile в каталоге post-py. Имя образа определяется с помощью переменных окружения USERNAME и POST_VERSION. Сервис подключается к сетям back_net и front_net с псевдонимом post. 

comment: сервис построен из Dockerfile в каталоге comment. Имя образа определяется с помощью переменных окружен ия USERNAME и COMMENT_VERSION. Сервис подключается к сетям back_net и front_net с псевдонимом comment. 

ui: сервис построен из Dockerfile в каталоге ui. Имя образа определяется с помощью переменной окружения USERNAME и POST_VERSION. Сервис подключается к сети front_net и использует порт ${UI_PORT} для доступа к нему. 

В секции volumes описан том reddit_db, который объявлен как внешний том и используется сервисом post_db. 

В секции networks описаны две сети: back_net и front_net. Каждая сеть использует драйвер bridge и имеет конфигурацию IPAM с драйвером default и подсетью 10.0.2.0/24 и 10.0.1.0/24 соответственно. Эти сети используются различными сервисами для обеспечения взаимодействия между ними. 

 

Задание со * 

Создайте docker-compose.override.yml для reddit проекта, который позволит 

•Изменять код каждого из приложений, не выполняя сборку образа 

•Запускать puma для руби приложений в дебаг режиме с двумя воркерами (флаги --debug и -w 2) 

https://docs.docker.com/compose/extends/ 

 

Docker Compose файл docker-compose.override.yml содержит конфигурацию для дополнения и управления существующими контейнерами, которые были описаны в основном файле docker-compose.yml 

 

puma --debug -w 2 запускает сервер в режиме отладки с двумя воркерами. 

Воркеры - это процессы, которые обрабатывают запросы к веб-серверу. Если вы используете веб-сервер, который поддерживает многопоточность, такой как Puma, вы можете запустить несколько воркеров для обработки запросов одновременно. Это позволяет увеличить производительность и обрабатывать больше запросов одновременно. Например, если вы запустите 2 воркера, они будут обрабатывать запросы в одновременно, тем самым дважды увеличив производительность. 

 

Команда puma --debug запускает Puma, веб-сервер на Ruby, в режиме отладки. В этом режиме Puma будет выводить дополнительную информацию в консоль, например о запросах клиентов и ответах сервера, которая может быть полезна при отладке или исследовании проблем с производительностью. Отла дочный режим также может показать дополнительную информацию о внутренней работе Puma, например о состоянии воркеров и пула потоков, которая может помочь в диагностике и решении проблем. Режим отладки не рекомендуется использовать в продакшн среде, так как он может привести к дополнительному нагружению и более медленной работе сервера. 

 

Если вы прописали команду puma --debug -w 2 в файле docker-compose.override.yml и запустили контейнер с помощью docker-compose up, дополнительная информация отладки будет выводиться в консоль, в которой запущен контейнер. Вы можете использовать команду docker-compose logs -f <service_name> чтобы просматривать журналы сервиса, чтобы видеть дополнительную информацию, выводимую Puma в режиме отладки. Если вы запустите эту команду в той же консоли, где запускали docker-compose up, вы увидите все выводимые в консоль данные, в том числе и дополнительную информацию отладки. 

 

Так же Дополнительная информация, выводимая в режиме отладки Puma, отображается в консоли, в которой была запущена команда puma --debug. Если вы запустили Puma в контейнере Docker, вам необходимо подключиться к контейнеру и запустить команду в консоли внутри контейнера. Вы можете использовать команду docker exec -it <container_name> /bin/bash для подключения к контейнеру и запуска команды в консоли. 

Вы также можете использовать различные инструменты для мониторинга и анализа журналов, чтобы просматривать дополнительную информацию, выводимую Puma в режиме отладки. Например, вы можете использовать инструменты типа Elastic Stack (Elasticsearch, Logstash, Kibana) или Graylog для сбора, анализа и просмотра журналов в реальном времени. 

 

 

Чтобы посмотреть debug после запуска для comment пишем 

docker compose logs -f comment 

 

/home/baggurd/microservices/src/docker-compose.override.yml 

 

Чтобы применить новый файл нужно пересоздать контейнеры 

docker compose up -d --force-recreate 

принудительно пересоздаст контейнеры с учетом новых конфигураций из файла 

 

docker volume ls 

Или 

docker volume ls | grep test* 

 Смотрим на вновь созданные volume 

 

Смотрим где находится volume 

docker volume inspect test_app_comment 

 

Далее можем подключиться к удаленному хосту и зайти на volume и таким образом, мы можем изменять код каждого приложения на нашем локальном компьютере и немедленно видеть эти изменения внутри контейнера, без необходимости пересобирать образ. 

cd /var/lib/docker/volumes/test_app_comment/_data 

 

Но следует иметь в виду, что такой подход не рекомендуется, поскольку он может привести к несогласованности между кодом в контейнере и кодом на машине хоста, и может привести к проблемам при об овлении или деплое приложения. Лучшим подходом будет создание отдельного образа с новой версией кода и использование его для запуска контейнера, чтобы гарантировать согласованность кода между контейнером и исходным кодом. 

 

 

 

Так же мы можем подключать кокретные локальные каталоги для изменения кода если запускаем docker compose локально. 

version: '3.3' 

  

services: 

  ui: 

    command: puma --debug -w 2 

    volumes: 

      - ./ui:/app 

  

  post: 

    volumes: 

      - ./post-py:/app 

  

  comment: 

    command: puma --debug -w 2 

    volumes: 

      - ./comment:/app 

 

В этом коде для каждого сервиса мы используем опцию volumes для связывания каталога на вашем локальном компьютере с каталогом внутри контейнера. Каталоги на вашем локальном компьютере соответствуют каталогам, в которых находятся ваши приложения: ui, post-py, comment. 

 

Если вы используете docker-machine для подключения к демону Docker на удаленной машине, то каталоги с приложениями на вашем локальном компьютере не будут доступны для контейнера на удаленной машине. Вам нужно будет использовать различные способы, такие как использование файловой системы сети (NFS) или использование удаленного доступа (например, sshfs) для подключения каталога на вашем локальном компьютере к удаленной машине. 

В любом случае, Вам нужно будет проследить чтобы путь к каталогам был доступен для контейнера на удаленной машине и исполь зовать этот путь в конфигурации опции volumes в docker-compose.yml файле. Например, если вы используете sshfs для подключения каталога на вашем локальном компьютере к удаленной машине, то вам нужно будет использовать путь к каталогу на удаленной машине в опции volumes. 

services: 

  ui: 

    command: puma --debug -w 2 

    volumes: 

      - sshfs_path_to_ui:/app 

  post: 

    volumes: 

      - sshfs_path_to_post-py:/app 

  comment: 

    command: puma --debug -w 2 

    volumes: 

      - sshfs_path_to_comment:/app 

 

В данном случае sshfs_path_to_ui, sshfs_path_to_post-py, sshfs_path_to_comment это пути на удаленной машине 

## HomeWork 19 - Устройство Gitlab CI. Построение процесса непрерывной поставки
Ставим сервер с помощью terraform и ansible 
/home/baggurd/microservices/terraform/Gitlab

Для запуска Gitlab CI мы будем использовать omnibus-установку, у
этого подхода есть как свои плюсы, так и минусы.
Основной плюс для нас в том, что мы можем быстро запустить сервис
и сконцентрироваться на процессе непрерывной поставки.
Минусом такого типа установки является то, что такую инсталляцию
тяжелее эксплуатировать и дорабатывать, но долговременная
эксплуатация этого сервиса не входит в наши цели.
Более подробно об этом опять же в документации
https://docs.gitlab.com/omnibus/README.html
https://docs.gitlab.com/omnibus/docker/README.html

В ansible уже прописаны эти настройки для gitlab:
# mkdir -p /srv/gitlab/config /srv/gitlab/data /srv/gitlab/logs
# cd /srv/gitlab/
# touch docker-compose.yml

Заполняем docker-compose.yml:
```
version: "3"

services:
  web:
    image: 'gitlab/gitlab-ce:latest'
    restart: always
    hostname: 'gitlab.example.com'
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'http://34.77.7.178'
    ports:
      - '80:80'
      - '443:443'
      - '2222:22'
    volumes:
      - '/srv/gitlab/config:/etc/gitlab'
      - '/srv/gitlab/logs:/var/log/gitlab'
      - '/srv/gitlab/data:/var/opt/gitlab'

```
Для установки начального пароля нужно прописать переменные

```
GITLAB_ROOT_EMAIL="root@local"
GITLAB_ROOT_PASSWORD="gitlab_root_password" 
EXTERNAL_URL= 'http://34.77.7.178'
```

Запускаем gitlab
```
docker-compose up -d
```

Для первого запуска Gitlab CI необходимо подождать
несколько минут, пока он стартует можно почитать,
откуда мы взяли содержимое файла docker-compose.yml
https://docs.gitlab.com/omnibus/docker/README.html#install-gitlab-using-docker-compose


Или после запуска контейнера заходим внутрь 
```
docker exec -it 522e6ca5a5c2 bash
```
И устанавливаем пароль на root:
```
sudo gitlab-rake "gitlab:password:reset"
```
или можем посмотреть назначенный пароль 
```
cat etc/gitlab/initial_root_password
```
Заходим
http://<your-vm-ip>

Создаем новую группу 
Создаем проект

На клентской машине с кодом создаем папку с проектом
В папке выполняем
```
git clone http://34.77.7.178/homework/example.git
git checkout -b gitlab-ci-1
git remote add gitlab http://34.77.7.178/homework/example.git
git push gitlab gitlab-ci-1
```
Создаем файл .gitlab-ci.yml
Вписываем в него Pipeline
Пушим файл в репо

```
git add .gitlab-ci.yml
git commit -m 'add pipeline definition'
git push gitlab gitlab-ci-1
```
Теперь если перейти в раздел CI/CD мы увидим, что пайплайн готов к запуску
Но находится в статусе pending / stuck так как у нас нет runner
Запустим Runner и зарегистрируем его в интерактивном режиме

Runner

Перед тем, как запускать и регистрировать runner нужно получить токен
Settings - CI/CD - Runners - Expand - 
Нужно скопировать, токен пригодится нам при регистрации


Запускаем Runner, если запускать на том же сервере где Gitlab то все жутко тормозит я запускал на другом сервере
```
docker run -d --name gitlab-runner --restart always \
-v /srv/gitlab-runner/config:/etc/gitlab-runner \
-v /var/run/docker.sock:/var/run/docker.sock \
gitlab/gitlab-runner:latest
```
После запуска Runner нужно зарегистрировать, это можно сделать командой:
```
root@gitlab-ci:~# docker exec -it gitlab-runner gitlab-runner register --run-untagged --locked=false
```
Please enter the gitlab-ci coordinator URL (e.g. https://gitlab.com/):
```
http://<YOUR-VM-IP>/
```
Please enter the gitlab-ci token for this runner:
```
<TOKEN>
```
Please enter the gitlab-ci description for this runner:
```
[38689f5588fe]: my-runner
```
Please enter the gitlab-ci tags for this runner (comma separated):
```
linux,xenial,ubuntu,docker
```
Please enter the executor:
```
docker
```
Please enter the default Docker image (e.g. ruby:2.1):
```
alpine:latest
```
Runner registered successfully.

Как вариант, можно регистрировать Runner в неинтерактивном режиме:
```
sudo docker exec gitlab-runner gitlab-runner register --run-untagged --locked=false --non-interactive --executor "docker" --docker-image alpine:latest --url "http://34.77.7.178/"   --registration-token "*********" --description "docker-runner" --tag-list "docker,linux" --run-untagged="true"
```

Runner может быть назначен на проект или на все проекты
Чтобы назначить раннер на проект когда мы его добавляем мы берем token:
Заходим в проект — Settings — CI/CD — Specific Runners. Копируем токен.
Если хоти завести раннер для испольщования в любых проектах то идем 
Admin — Runners — Register an instance runner — и копируем токен.
Этот раннер можем включить или выключить в проекте.

Runner будет запускаться всегда если в нем стоит галка run untagged jobs.
Если галка не стоит то раннер будет запускаться только по совпадению тега, который прописан в раннере и того который указываем в шагах файла .gitlab-ci.yml

Например
```
deploy_dev_job:
	stage: review
	tags:
		- external
```

Добавим тестирование приложения reddit в pipeline
```
> git clone https://github.com/express42/reddit.git && rm -rf ./reddit/.git
> git add reddit/
> git commit -m “Add reddit app”
> git push gitlab gitlab-ci-1
```

Изменим описание пайплайна в .gitlab-ci.yml
```
test_unit_job:
  stage: test
  tags:
    - external
  # List of services to be started before the job runs    
  services:
    - mongo:latest
  script:
    # Install the necessary dependencies
    - bundle install
    # Run the unit tests
    - ruby simpletest.rb 
```
В описании pipeline мы добавили вызов теста в файле simpletest.rb, нужно создать его в папке reddit
/home/baggurd/gitlab/example/reddit/simpletest.rb
Последним шагом нам нужно добавить библиотеку для тестирования в reddit/Gemfile приложения.

Теперь на каждое изменение в коде приложения будет запущен тест

Изменим пайплайн таким образом, чтобы job deploy стал определением окружения dev, на которое условно будет выкатываться каждое изменение в коде проекта.

После изменения файла .gitlab-ci.yml не забывайте зафиксировать изменение в git и отправить изменения на сервер. (git commit и git push gitlab gitlab-ci-1)

Если после успешного завешения пайплайна с определением окружения перейти в CI/CD >
Environments, то там появится определение первого окружения.

Если на dev мы можем выкатывать последнюю версию кода, то к production окружению это может быть неприменимо, если, конечно, вы не стремитесь к continuous deployment.

Определим два новых этапа: stage и production, первый будет содержать job имитирующий выкатку на staging окружение, второй на production окружение.

Определим эти job таким образом, чтобы они запускались с кнопки

when: manual – говорит о том, что job должен быть запущен человеком из UI.

Обычно, на production окружение выводится приложение с явно зафиксированной версией (например, 2.4.10).

Добавим в описание pipeline директиву, которая не позволит нам выкатить на staging и production код, не помеченный с помощью тэга в git.

Директива only описывает список условий, которые должны быть истинны, чтобы job мог запуститься.

Регулярное выражение слева означает, что должен стоять semver тэг в git, например, 2.4.10
```
staging:
  stage: stage
  when: manual
  only:
    - /^\d+\.\d+\.\d+/
  script:
    - echo 'Deploy'
  environment:
    name: stage
    url: https://beta.example.com
```
Изменение без указания тэга запустят пайплайн без job staging и production
Изменение, помеченное тэгом в git запустит полный пайплайн
```
git commit -a -m '#4 add logout button to profile page'
git tag 2.4.10
git push gitlab gitlab-ci-1 --tags
```

Динамические окружения
Gitlab CI позволяет определить динамические окружения, это мощная функциональность позволяет вам иметь выделенный стенд для, например, каждой feature-ветки в git.

Определяются динамические окружения с помощью переменных, доступных в .gitlab-ci.yml
```
# Этот job определяет динамическое окружение для каждой ветки в репозитории, кроме ветки master
# Теперь, на каждую ветку в git отличную от master Gitlab CI будет определять новое окружение.
branch review:
  stage: review
  script: echo "Deploy to $CI_ENVIRONMENT_SLUG"
  environment:
    name: branch/$CI_COMMIT_REF_NAME
    url: http://$CI_ENVIRONMENT_SLUG.example.com
  only:
    - branches
  except:
    - master
```

Теперь, на каждую ветку в git отличную от master Gitlab CI будет определять новое окружение.

Если создать ветки new-feature и bugfix, то на странице окружений будет следующее:

Пригодится:
Описание переменных CI https://docs.gitlab.com/ee/ci/variables/predefined_variables.html
Некоторое раскрытие работы используемых переменных CI https://docs.gitlab.com/ee/ci/environments.html#example-configuration

Задание с *

В шаг build добавить сборку контейнера с приложением reddit
Деплойте контейнер с reddit на созданный для ветки сервер.

Так как нам нужно сделать сборку контейнера а раннер это уже контейнер то нам необходимо пользоваться образом docker:dind

!!! Если нужно собирать docker images:
    • контейнер gitlab-runner д.б. запущен с опцией --privileged
    • в файл конфигурационный файл runner вписать что он работает в привилигированном режиме
https://docs.gitlab.com/runner/executors/docker.html#use-docker-in-docker-with-privileged-mode

```
nano /srv/gitlab-runner/config/config.toml
------
[[runners]]
  name = "my-runner"
  url = "http://35.205.50.178/"
  executor = "docker"
  ...
  [runners.docker]
    ...
    privileged = true
    ...
------
```
Для успешной сборки и отправки обораза в registry необходимо в Settings - CI/CD - Variables добавить параметры
        ◦ CI_REGISTRY_USER- логин от учетной записи docker hub
        ◦ CI_REGISTRY_PASSWORD - пароль от учетной записи docker hub
        ◦ CI_REGISTRY — хаб с которого берем образы (docker.io)
Переменные $CI_REGISTRY_PASSWORD, $CI_REGISTRY_USER, $CI_REGISTRY прописываем в settings - Ci/CD Variables
Отключаем опцию Protected. (Если опция включена получаем ошибку Get https://registry-1.docker.io/v2/: unauthorized: incorrect username or password)
акая ошибка Error: Cannot perform an interactive login from a non TTY device бывает если мы вводим
docker login -u $DOCKER_REPO_USER -p $DOCKER_REPO_PASS вместо echo. 
```
- echo "$CI_REGISTRY_PASSWORD" | docker login -u "$CI_REGISTRY_USER" --password-stdin $CI_REGISTRY
```

Директива before_script: [] внутри этапа позволит переопределить before_script объявленный на уровне pipeline.


Пригодится!
Деплой через ssh https://medium.com/@codingfriend/continuous-integration-and-deployment-with-gitlab-docker-compose-and-digitalocean-6bd6196b502a
Документация на опции GitLab CI/CD Pipeline в .gitlab-ci.yml https://docs.gitlab.com/ee/ci/yaml/
Некоторые разъяснения в документации по использованию имиджей докера и инструкции services: https://docs.gitlab.com/ee/ci/docker/using_docker_images.html#what-is-a-service
Докер в докере и наличие для этого сервиса docker:dind :
    1. http://qaru.site/questions/2440757/role-of-docker-in-docker-dind-service-in-gitlab-ci
    2. https://docs.gitlab.com/ce/ci/docker/using_docker_build.html#use-docker-in-docker-executor
Докер в докере и привилегированный режим (контейнер gitlab-runner д.б. запущен с опцией --privileged) https://docs.gitlab.com/runner/executors/docker.html#use-docker-in-docker-with-privileged-mode

Создаем с помощью terraform и ansible сервер для Deploy нашего приложения
/home/baggurd/microservices/terraform/reddit-app
```
terraform init
terraform apply
```
```
Настраиваем Gitlab для выполнения деплоя через ssh
      Для этого создаем переменные в настройках проекта CI
        ◦ переменную CI_PRIVATE_KEY с приватным ключом аналогичным ~/.ssh/appuser
        ◦ переменную CI_USER с именем пользователя
        ◦ переменную HOST с IP адресом выделенного сервера

Корректируем задание deploy_dev_job в pipeline этапа review в .gitlab-ci.yml
    • Для проверки перейти по адресу http://IP_GCP:9292 (или нажать кнопку " View deployment" в Environments в разделе Operations проекта)

Конечный вариант .gitlab-ci.yml:

# Берем контейнер с установленным ruby для тестов приложения на ruby
image: ruby:2.4.2

# В кэш мы можем помещать каталоги которые будут кэшироваться первый раз и потом они не будут загружаться а использоваться из кэша
# cache:
#   key это имя кэша и CI будет обращаться к кэшу по имени. CI_BUILD_REF_NAME это имя нашего branch. путь - node_modules/ то что
#   будет кэшироваться. Если мы хотим изменить кэш то нужно поменять строку key.
#   key: "$CI_BUILD_REF_NAME node:ruby:2.4.2"
#   paths:
#   - node_modules/

stages:
  - build
  - test
  - review
  - stage
  - production

# В данном случае, в переменной DATABASE_URL указан адрес подключения 'mongodb://mongo/user_posts', 
# который указывает на то, что база данных MongoDB находится на хосте "mongo" и используется для хранения данных "user_posts"
# Сама база устанавливается как служба в блоке test_unit_job 
variables:
  DATABASE_URL: 'mongodb://mongo/user_posts'

# Переходим в каталог reddit и устанавливаем зависимости для нашего приложения 
before_script:
  - cd reddit
# Не работает с image docker:dind поэтому переносим настройку в блок test_unit_job    
#  - bundle install

# !!! Если нужно собирать docker images: runner д.б. запущен с опцией --privileged
# для этого неоюходимо в конфигурационный файл runner вписать что он работает в привилигированном режиме
# Файл находится по пути: nano /srv/gitlab-runner/config/config.toml на хосте где запущен docker контейнер с раннером
# ------
# [[runners]]
#   name = "my-runner"
#   url = "http://35.205.50.178/"
#   executor = "docker"
#   ...
#   [runners.docker]
#     ...
#     privileged = true
#     ...
# ------

build_job:
  image: docker:stable
  stage: build
  tags:
    - external
  # Импользуем образ "dind" сокращение от "Docker in Docker". 
  # Этот образ используется для запуска докер-контейнера внутри другого докер-контейнера, 
  # что позволяет использовать докер-функциональность внутри среды CI/CD  
  services:
    - docker:dind
  # Если не указываем эти переменные получаем ошибку Cannot connect to the Docker daemon at tcp://docker:2375. Is the docker daemon running?  
  variables:
    DOCKER_DRIVER: overlay2
    DOCKER_HOST: tcp://docker:2375
    DOCKER_TLS_CERTDIR: ""
  before_script:
    # Переменные $CI_REGISTRY_PASSWORD, $CI_REGISTRY_USER, $CI_REGISTRY прописываем в settings - Ci/CD Variables
    # Отключаем опцию Protected. (Если опция включена получаем ошибку Get https://registry-1.docker.io/v2/: unauthorized: incorrect username or password)
    # Такая ошибка Error: Cannot perform an interactive login from a non TTY device бывает если мы вводим
    # docker login -u $DOCKER_REPO_USER -p $DOCKER_REPO_PASS вместо echo. 
    - echo "$CI_REGISTRY_PASSWORD" | docker login -u "$CI_REGISTRY_USER" --password-stdin $CI_REGISTRY
  script:
    # Здесь вместо . нужно указать каталог где находится Dockerfile (reddit/) 
    # Иначe получаем ошибку (unable to prepare context: unable to evaluate symlinks in Dockerfile path: lstat /builds/homework/example/Dockerfile: no such file or directory)
    - docker build -t $CI_REGISTRY_USER/reddit:$CI_COMMIT_SHORT_SHA reddit/
    - docker push $CI_REGISTRY_USER/reddit:$CI_COMMIT_SHORT_SHA

# Блок services в файле .gitlab-ci.yml определяет, какие службы должны быть запущены 
# во время выполнения определенной стадии pipeline. В данном случае строчка - mongo:latest означает, 
# что во время выполнения стадии test должна быть запущена служба MongoDB в последней доступной версии (latest). 
# Это необходимо для того, чтобы можно было выполнить тесты, основанные на базе данных MongoDB, 
# которая будет доступна для подключения во время выполнения скрипта ruby simpletest.rb. GitLab берет службу MongoDB из образов Docker. 
# В данном случае, служба MongoDB скачивается из официального репозитория Docker Hub при первом запуске стадии test с тегом "latest"
test_unit_job:
  stage: test
  tags:
    - external
  # List of services to be started before the job runs    
  services:
    - mongo:latest
  script:
    # Install the necessary dependencies
    - bundle install
    # Run the unit tests
    - ruby simpletest.rb 

test_integration_job:
  stage: test
  tags:
    - external
  script:
    - echo 'Testing 2'

# Deploy stage
deploy:
  # Stage name
  stage: review
  # тег используется для запуска на раннерах с таким же тегом
  tags:
    - external
  # Script to run for this stage    
  script:
    # Start the SSH agent to manage the SSH keys
    - eval $(ssh-agent -s)
    # Add the private SSH key to the SSH agent. tr -d '\r' удаляет return (\r) из файла. (Windows окончание строки)
    # Указываем base64 --decode чтобы без ошибок подхватывался ssh ключ. В этом случае сам ключ мы должны брать таким образом: sudo cat ~/.ssh/appuser_ed25519 | base64 -w0 
    - echo "$CI_PRIVATE_KEY" | base64 --decode | tr -d '\r' | ssh-add -
    # Create the .ssh directory and set proper permissions
    - mkdir -p ~/.ssh
    - chmod 700 ~/.ssh
    # Disable strict host key checking in SSH config
    - echo -e "Host *\n\tStrictHostKeyChecking no\n\n" > ~/.ssh/config
    # SSH into the GCP VM and execute commands to pull the Docker image, stop and remove the existing container, and run a new container
    - ssh $CI_USER@$HOST "docker stop reddit || true && docker rm reddit || true && docker pull $CI_REGISTRY_USER/reddit:$CI_COMMIT_SHORT_SHA && (docker network inspect reddit > /dev/null 2>&1 || docker network create reddit) && (docker volume inspect reddit_db &>/dev/null || docker volume create reddit_db) && docker run -d --network=reddit --network-alias=mongo -v reddit_db:/data/db mongo:4.0-xenial && docker run --name reddit -d --network=reddit --restart unless-stopped -p 9292:9292 $CI_REGISTRY_USER/reddit:$CI_COMMIT_SHORT_SHA"
  # URL для доступа к среде dev задается в переменной url: http://$HOST:9292 Этот URL может использоваться для доступа к приложению и его тестирования в рамках этой среды.
  environment:
    name: dev
    url: http://$HOST:9292
  only:
    - branches
  except:
    - master        

# Этот job определяет динамическое окружение для каждой ветки в репозитории, кроме ветки master
# Теперь, на каждую ветку в git отличную от master Gitlab CI будет определять новое окружение.
branch review:
  stage: review
  tags:
    - external
  script: echo "Deploy to $CI_ENVIRONMENT_SLUG"
  environment:
    name: branch/$CI_COMMIT_REF_NAME
    url: http://$CI_ENVIRONMENT_SLUG.example.com
  only:
    - branches
  except:
    - master    


# Для того чтобы эти стейджи работали нужно добавлять соответствующие шагу review стадии в блок script.
staging:
  stage: stage
  tags:
    - external  
  when: manual
# Выражение only: /^\d+\.\d+\.\d+/ используется в конфигурации GitLab CI/CD, чтобы указать, 
# что данная работа должна выполняться только в том случае, если ветка, которую мы пушим, соответствует регулярному выражению.
# В данном случае регулярное выражение /^\d+\.\d+\.\d+/ означает, что имя ветки должно начинаться с последовательности цифр, разделенных точками. 
# Например, 1.0.0, 2.3.5, 10.2.7. (Т.е. только в случае указания соответствующего тега x.x.x при push на gitlab)
  only:
    - /^\d+\.\d+\.\d+/
  script:
    - echo 'Deploy'
  environment:
    name: stage
    url: https://beta.example.com

production:
  stage: production
  tags:
    - external 
  when: manual
  only:
    - /^\d+\.\d+\.\d+/
  script:
    - echo 'Deploy'
  environment:
    name: production
    url: https://example.com
```

## HomeWork 20 - Введение в мониторинг. Системы мониторинга
- Создано firewall-правило для prometheus `gcloud compute firewall-rules create prometheus-default --allow tcp:9090`
- Создано firewall-правило для puma `gcloud compute firewall-rules create puma-default --allow tcp:9292`
- Создан хост docker-machine

Пользуемся хостом который создавали ранее 
```bash
eval $(docker-machine env docker-host)
```
Или создаем новый:
```bash
$ docker-machine create --driver google --google-project docker-372311 --google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/ubuntu-1604-xenial-v20170815a --google-machine-type n1-standard-1 --google-zone europe-west1-b --engine-install-url "https://releases.rancher.com/install-docker/19.03.9.sh" docker-host
```

Систему мониторинга Prometheus будем запускать внутри Docker контейнера. Для начального знакомства воспользуемся готовым образом с DockerHub.
```bash
docker run --rm -p 9090:9090 -d --name prometheus prom/prometheus:v2.1.0
```

Узнать ip адрес хоста созданного docker-machine
```bash
docker-machine ip docker-host
```
- Поосмтрел метрики, которые уже сейчас собирает prometheus
- Посмотрел список таргетов, с которых prometheus забирает метрики
- Остановил контейнер с prometheus `docker stop prometheus`
- Перенес docker-monolith и файлы docker-compose и .env из src в новую директорию docker
- Создал директорию под все, что связано с мониторингом - monitoring
- Добавил monitoring/prometheus/Dockerfile для создания образа с кастомным конфигом
```dockerfile
FROM prom/prometheus:v2.1.0
ADD prometheus.yml /etc/prometheus/
```

- Создал конфиг monitoring/prometheus/prometheus.yml Вся конфигурация Prometheus, в отличие от многих других систем мониторинга, происходит через файлы конфигурации и опции командной строки.
- !!Нельзя использовать sudo в случае если мы используем docker-machine. Потому что с sudo все будет собираться локально и будем получать ошибку
- Error response from daemon: pull access denied for vasiliybasov/ui, repository does not exist or may require 'docker login': denied: requested access to the resource is denied
- Собрал образ prometheus `docker build -t vasiliybasov/prometheus .`
- Собрал образы микросервисов посредством docker_build.sh

```
# Скрипт для сборки докер контейнеров с помощью скриптов docker_build.sh
export USER_NAME=vasiliybasov
for i in ui post-py comment; do
 cd src/$i;
 bash docker_build.sh;
 cd -;
done
```

- удалил из docker/docker-compose.yml директивы build и добавил описание для prometheus
- добавил конфигурацию networks для prometheus в docker-compose
- актуализировал переменные в .env
- запустил контейнеры `docker-compose up -d`
- приложения доступно по адресу <http://x.x.x.x:9292/> и prometheus доступен на <http://x.x.x.x:9090/>

### Мониторинг состояния микросервисов

- Убедился что в prometheus определены и доступны эндпоинты ui и comment
- Получил статус метрики ui_health, так же получил ее в виде графика
- Остановил микросервис post и увидел, что метрика изменила свое значение на 0
- Посмотрел метрики доступности сервисов comment и post
- Заново запустил post-микросервис `docker-compose start post`

### Exporters Сбор метрик хоста

- Добавил определение контейнера node-exporter в docker-compose.yml
- Добавил job для node-exporter в конфиг Prometheus и пересобрал контейнер
- Остановил и повторно запустил контейнеры docker-compose
- Убедился в том, что в списке эндпоинтов пояивлся эндпоинт node
- Выполнил `yes > /dev/null` на docker-host и убедился что метрики демонстрируют увеличение нагрузки на процессор
- Загрузил образы на Docker Hub 

### HW 20: Задание со * 1
- Добавьте в Prometheus мониторинг MongoDB с использованием необходимого экспортера.
- Использовался экспортер bitnami/mongodb-exporter

- В наш docker-compose добавляем следующее содержимое docker/docker-compose.yml:
```dockerfile
  mongodb-exporter:
    user: root
    image: bitnami/mongodb-exporter:latest
    # Use the environment variables to configure the MongoDB connection
    command:
      # Опция нужна чтобы собирать все метрики mongo_db а не только mongodb_up 
      - '--collect-all'
      - '--mongodb.uri=mongodb://post_db:27017'
      # Можно собирать только часть метрик:
      # - '--collect.database'
      # - '--collect.collection'
      # - '--collect.indexusage'
      # - '--collect.topmetrics'
    # environment:
    #   - MONGODB_URI=mongodb://post_db:27017
    networks:
      back_net:
        aliases:
          - mongodb-exporter
```
prometheus.yml
```
  - job_name: 'mongodb-exporter'
    static_configs:
      - targets: 
        - 'mongodb-exporter:9216'
```
- Все метрики которые касаются мониторинга mongo начинаются на mongodb_

- Пересобрал образ prometheus и перезапустил контейнеры

### HW 20: Задание со * 2 - BlackBox Exporter

Задание:
Добавьте в Prometheus мониторинг сервисов comment, post, ui с помощью blackbox экспортера.
Blackbox exporter позволяет реализовать для Prometheus мониторинг по принципу черного ящика. Т.е. например мы можем проверить отвечает ли сервис по http, или принимает ли соединения порт.
* Версию образа экспортера нужно фиксировать на последнюю стабильную
* Если будете добавлять для него Dockerfile, он должен быть в директории monitoring, а не в корне репозитория.
Вместо blackbox_exporter можете попробовать использовать Cloudprober от Google.

- https://github.com/prometheus/blackbox_exporter
- мониторинг по принципу черного ящика. Т.е. например мы можем проверить отвечает ли сервис по http, или принимает ли соединения порт.

Собираем образ: microservices/monitoring/blackbox-exporter/Dockerfile
```Dockerfile
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
```

- Подготовил конфигурационный файл blackbox.yml с проверками по http и icmp
- https://github.com/prometheus/blackbox_exporter/blob/master/CONFIGURATION.md
- blackbox.yml:
```yml
modules:
  # проверям код ответа http с 200 по 299 successful HTTP response
  http_2xx:
    prober: http
    timeout: 5s
    http:
      valid_http_versions: ["HTTP/1.1", "HTTP/2"]
      valid_status_codes:
        - 200
        - 404
      # HTTP GET request to the target endpoint during the probe. 
      # The response from the target will be analyzed to determine 
      # the status of the endpoint and to collect metrics  
      method: GET
      preferred_ip_protocol: "ip4"
  icmp:
    prober: icmp
    timeout: 5s
    icmp:
      preferred_ip_protocol: "ip4"
```

- Подготовил образ blackbox-exporter `docker build -t $USER_NAME/blackbox-exporter .`
- Добавил тэг версии `docker tag $USER_NAME/blackbox-exporter:latest $USER_NAME/blackbox-exporter:0.8.0`
- Запушил на Docker Hub `docker push $USER_NAME/blackbox-exporter`
- Добавил в docker-compose запуск контейнера с BlackBox Exporter

```yml
  blackbox-exporter:
    image: ${USER_NAME}/blackbox-exporter:${BLACKBOX_EXPORTER_VERSION}
    ports:
      - '9115:9115'
    networks:
      back_net:
        aliases:
          - blackbox-exporter

      front_net:
        aliases:
          - blackbox-exporter
```

- Добавил job в конфиг prometheus и пересобрал контейнер

```yml
# https://github.com/prometheus/blackbox_exporter
# мониторинг по принципу черного ящика. Т.е. например мы можем проверить отвечает ли сервис по http, или принимает ли соединения порт.
  - job_name: 'blackbox'
  # Путь для получения метрик из blackbox exporter
    metrics_path: /probe
    params:
      module: 
        - http_2xx # Look for a HTTP 200 response.
        - icmp
    static_configs:
      - targets:
        - http://comment:9292/metrics
        - ui:9292
    # Relabeling configuration for the targets    
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115 # The blackbox exporter's real hostname:port.
```

- Добавил переменную BLACKBOX_EXPORTER_VERSION в .env
- Пересобрал образ prometheus и перезапустил контейнеры `docker-compose donw && docker-compose up -d`

Результаты у нас следующие:
```
probe_http_status_code{instance="http://comment:9292/metrics",job="blackbox"}	200
probe_http_status_code{instance="http://post:9292/metrics",job="blackbox"}	0
probe_http_status_code{instance="ui:9292",job="blackbox"}	200
```
т.к. у post нет /metrics, да и вообще не прослушивается порт 9292, статус 0.
Если для comment не указывать /metrics, то получим 404 (Not Found).

### HW 20 задание со * 3 - Make

- Подготовил Makefile, перед запуском нужно выполнить `export USER_NAME=your-docker-hub-login` и `export APP_TAG=latest`
- Сборка всех контейнеров - `make build-all`
- Пуш всех контейнеров - `make push-all`

## HomeWork 21 - Мониторинг приложения и инфраструктуры

### Мониторинг Docker-контейнеров

- Перенес описание приложений для мониторинга в отдельный docker-compose-файл microservices/docker `docker-compose-monitoring.yml`
- Добавил в docker-compose-monitoring.yml описание для контейнера cAdvisor
- Добавил в конфиг prometheus job для cadvisor, пересобрал image prometheus
- Создал в gcloud правило для доступа на 8080 порт `gcloud compute firewall-rules create cadvisor-default --allow tcp:8080`
- Запустил контейнеры `docker-compose up -d && docker-compose -f docker-compose-monitoring.yml up -d`
- Изучил информацию, которую предоставляет web-интерфейс cAdvisor

### Визуализация метрик

- Добавил описание Grafana в `docker-compose-monitoring.yml`
- Запустил контейнер Grafana `docker-compose -f docker-compose-monitoring.yml up -d grafana`
- Добавил firewall rule для Grafana `gcloud compute firewall-rules create grafana--default --allow tcp:3000`
- Через web-интерфейс добавил datasource prometheus server
- Нашел на официальном сайте и загрузил дашборд `Docker and system monitoring` в monitoring/grafana/dashboards/DockerMonitoring.json
- Импортировал дашборд в Grafana
- Убедился что появился дашборд, показывающий метрики контейнеров

### Сбор метрик приложения

- В конфиг prometheus.yml добавлен job для сбора метрик с сервиса post
- Пересобран образ prometheus
- Пересозданы контейнеры инфраструктуры мониторинга `docker-compose -f docker-compose-monitoring.yml down && docker-compose -f docker-compose-monitoring.yml up -d`
- В приложении reddit добавлены посты и комментарии к ним
- В Grafana добавлен новый дашборд
- В Grafana добавлен график ui_request_count
- Добавлен график http_requests with error codes.
- rate() - это функция в формате Prometheus, которая вычисляет скорость изменения метрики за заданный временной интервал. Она позволяет получить информацию о динамике изменения метрики во времени. Обычно rate() используется с счетчиками, так как они представляют собой неотрицательные значения, которые увеличиваются со временем. Функция rate() вычисляет скорость изменения счетчика за заданный временной интервал, позволяя оценить темпы роста или убывания метрики.
- Выражение rate(<metric_name>[<time_interval>]) получает имя метрики <metric_name> и временной интервал <time_interval>, за который вычисляется скорость изменения. Временной интервал указывается в виде строки, например [5m] для подсчета скорости изменения за последние 5 минут.
- ui_request_count{http_status=~"^[45].*"}[1m] это количество ошибочных HTTP-ответов за последнюю минуту.
- rate(ui_request_count{http_status=~"^[45].*"}[1m]) вычисляет скорость изменения метрики "ui_request_count" только для ошибочных HTTP-ответов за последнюю минуту.
- Сохранил изменениея в дашборде, проверил наличие версий в options дашборда
- Добавил rate(ui_request_count[1m]) для первого графика. Это скорость изменения количиства http запросов поступающих ui сервису за последнюю минуту
- Добавил новый график с вычислением 95-ого процентиля для метрики ui_request_response_time_bucket время обработки запросов (за это время или меньше обрабатываются 95% запросов) `histogram_quantile(0.95, sum(rate(ui_request_response_time_bucket[5m])) by (le))`
- Экспортировал дашборд в виде json

### Сбор метрик бизнес логики

- Создал новый дашборд Business_Logic_Monitoring
- Добавил на дашборд график `rate(post_count[1h])`
- Добавил график `rate(comment_count[1h])`
- Экпортировал дашборд в json

### Алертинг

- Создал Dockerfile для alertmanager
- Добавил config.yml для alertmanager с индвидуальными настройками webhook
- Собрал образ alertmanager и запушил в Docker Hub
- Добавил alertmanager в docker-compose-monitoring.yml
- Добавил alerts.yml для prometheus
- Добавил копирование alerts.yml в Dockerfile prometheus
- Добавил информацию об алертинге в конфиг prometheus и пересобрал образ
- Перезапустил контейнеры мониторинга
- Убедился что правила алертинга отображаются в web-интерфейсе Prometheus
- Запушил все образы в Docker Hub

### HW21: Задание со *
- В Makefile добавлены команды для сборки новых образов

- В Docker в экспериментальном режиме реализована отдача метрик в формате Prometheus. Добавьте сбор этих метрик в Prometheus. Сравните количество метрик с Cadvisor. Выберите готовый дашборд или создайте свой для этого источника данных. Выгрузите его в monitoring/grafana/dashboards;
- https://docs.docker.com/config/daemon/prometheus/

- На docker-host в /etc/docker добавлен daemon.json (172.17.0.1 - адрес хоста в сети docker0)
- Чтобы заработалу нужно перезагрузить хост
```json
{
  "metrics-addr" : "172.17.0.1:9323",
  "experimental" : true
}
```
- ВАЖНО: в официальной документации предлагалось указать metrics-addr равным 127.0.0.1:9323, но учитывая, что контейнеры у нас запускаются не в сети host, потребовалось изменить адрес на 172.17.0.1. Так же можно указывать bridge interface (соответствует bridge-интерфейсу)

- В prometheus.yml добавлен таргет для docker

``` yml
  - job_name: 'docker'
    static_configs:
    - targets:
      - '172.17.0.1:9323'
```

- В Grafana добавлен дашборд Docker Engine Metrics <https://grafana.com/grafana/dashboards/1229>
- В интерфейсе prometheus появятся метрики engine_daemon_ По количеству и главное по составу, сильно уступает метрикам cAdvisor (начинаются с container_).

### Telegraf
- Добавлен Dockerfile monitoring/telegraf/Dockerfile и конфиг monitoring/telegraf/telegraf.conf
- Запуск Telegraf добавлен в docker-compose-monitoring.yml

```yml
  telegraf:
    image: ${USER_NAME}/telegraf
    ports:
      - 9273:9273
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      back_net:
        aliases:
          - telegraf
      front_net:
        aliases:
          - telegraf
```

- В prometheus.yml добавлен таргет на telegraf
```yml
  - job_name: 'telegraf'
    static_configs:
      - targets: ['telegraf:9273']
```

- Поднимаем сервисы

```bash
cd docker
docker-compose up -d
docker-compose -f docker-compose-monitoring.yml up -d
```

- В интерфейсе prometheus появятся метрики docker_container_ docker_n_, весь перечень метрик доступен по ссылке https://github.com/influxdata/telegraf/tree/master/plugins/inputs/docker

- 987 метрик (vs. 1482 в cAdvisor) Готовых дашбордов к Grafana для Telegraf:Docker от источника Prometheus нет, есть только от источника InfluxDB.


- В Grafana добавлен дашборд Telegraf Docker. Telegraf1.json

Задание:

- Придумайте и реализуйте другие алерты, например на 95 процентиль времени ответа UI, который рассмотрен выше; 
- Настройте интеграцию Alertmanager с e-mail помимо слака;
- Решение: monitoring/prometheus/alerts.yml

```yml
groups:
  - name: alert.rules
    rules:
    - alert: LackOfSpace
      expr: node_filesystem_free{mountpoint="/"} / node_filesystem_size * 100 < 20
      labels:
        severity: moderate
      annotations:
        summary: "Instance {{ $labels.instance }} is low on disk space"
        description: "On {{ $labels.instance }}, / has only {{ $value | humanize }}% of disk space left"
```

### Задание с **
Выполнено частично.

Задание:
В Grafana 5.0 была добавлена возможность описать в конфигурационных файлах источники данных и дашборды. Реализуйте автоматическое добавление источника данных и созданных в данном ДЗ дашбордов в графану;

Решение:
Потребовалось создать отдельный Dockerfile:

monitoring/grafana/Dockerfile
```dockerfile
FROM grafana/grafana:5.0.0
COPY dashboards-providers/providers.yml /etc/grafana/provisioning/dashboards/
COPY datasources/datasources.yml /etc/grafana/provisioning/datasources/
COPY dashboards/* /var/lib/grafana/dashboards/
```

monitoring/grafana/dashboards-providers/providers.yml
```yaml
---
apiVersion: 1

providers:
  # <string> provider name
- name: 'default'
  # <string, required> provider type. Required
  type: file
  # <bool> disable dashboard deletion
  disableDeletion: false
  # <bool> enable dashboard editing
  editable: true
  # <int> how often Grafana will scan for changed dashboards
  updateIntervalSeconds: 10
  options:
    # <string, required> path to dashboard files on disk. Required
    path: /var/lib/grafana/dashboards
```

monitoring/grafana/datasources/datasources.yml
```yaml
---
# config file version
apiVersion: 1

datasources:
  # <string, required> name of the datasource. Required
- name: Prometheus Server
  # <string, required> datasource type. Required
  type: prometheus
  # <string, required> access mode. proxy or direct (Server or Browser in the UI). Required
  access: proxy
  # <string> url
  url: http://prometheus:9090/
  # <string> Deprecated, use secureJsonData.password
  isDefault: true
  version: 2
  # <bool> allow users to edit datasources from the UI.
  editable: true
```

ВАЖНО: с экспортированными через web-интерфейс grafana dashboards была обнаружена интересная особенность:
```
grafana_1            | t=2019-06-13T12:28:11+0000 lvl=eror msg="failed to save dashboard" logger=provisioning.dashboard type=file name=default error="Invalid alert data. Cannot save dashboard"
grafana_1            | t=2019-06-13T12:28:11+0000 lvl=info msg="Initializing Alerting" logger=alerting.engine
grafana_1            | t=2019-06-13T12:28:11+0000 lvl=info msg="Initializing CleanUpService" logger=cleanup
grafana_1            | t=2019-06-13T12:28:14+0000 lvl=eror msg="failed to save dashboard" logger=provisioning.dashboard type=file name=default error="Invalid alert data. Cannot save dashboard"
```
Как выяснилось, в json-файлах фигурировали переменные ${DS_PROMETHEUS} и ${DS_PROMETHEUS_SERVER} в параметре datasource. Потребовалось изменить их значения на "Prometheus Server" (соответствует содержимому monitoring/grafana/datasources/datasources.yml).

## Logging

В данной работе мы:

познакомились с особенностями сбора структурированных и неструктурированных логов (EFK);
рассмотрели распределенную трасировку (zipkin).

Создали отдельный compose-файл для нашей системы логирования
```yml
version: '3.3'
services:
  fluentd:
    image: ${USER_NAME}/fluentd
    ports:
      - "24224:24224"
      - "24224:24224/udp"
    depends_on:
      - elasticsearch
      - kibana      
    networks:
      front_net:
        aliases:
          - fluentd
      back_net:
        aliases:
          - fluentd

  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:${ELASTIC_VERSION}
    container_name: elasticsearch
    environment:
    # With latest version of Elasticsearch, it is necessary to set the option discovery.type=single-node for a single node cluster otherwise it won't start
      - "discovery.type=single-node"
    # Открываем для других докер контерйнеров которые находятся в той же сети. but the container cannot be accessed from outside the Docker network  
    expose:
      - 9200
    ports:
      - "9200:9200"
    networks:
      front_net:
        aliases:
          - elasticsearch
      back_net:
        aliases:
          - elasticsearch
  kibana:
    image: docker.elastic.co/kibana/kibana:${KIBANA_VERSION}
    depends_on:
      - elasticsearch    
    ports:
      - "5601:5601"
    networks:
      front_net:
        aliases:
          - kibana
      back_net:
        aliases:
          - kibana

  zipkin:
    image: openzipkin/zipkin:${ZIPKIN_VERSION}
    ports:
      - "9411:9411"
    networks:
      front_net:
        aliases:
          - zipkin
      back_net:
        aliases:
          - zipkin

networks:
  front_net:
    ipam:
      config:
        - subnet: 10.0.1.0/24
  back_net:
    ipam:
      config:
        - subnet: 10.0.2.0/24
```
Подготовка окружения
В презентации была отсылка к ветке logging, которая больше не используется, а сам код находится в неработоспопсобном состоянии. В качестве основной используется ветка microservices, с которой мы уже работали ранее. Чтобы контейнер с ElasticSearch не падал, необходимо подкрутить sysctl на docker host:
```bash
$ docker-compose -f docker-compose-logging.yml logs elasticsearch
[...]
elasticsearch_1  | [1]: max virtual memory areas vm.max_map_count [65530] is too low, increase to at least [262144]
[...]
```

```bash
sudo sysctl -w vm.max_map_count=262144
```
To set this value permanently, update the vm.max_map_count setting in /etc/sysctl.conf. To verify after rebooting, run sysctl vm.max_map_count.

Используемые инструменты:
* ElasticSearch (TSDB + поисковый движок для хранения данных);
* fluentd (агрегация и трансформация данных);
* Kibana (визуализация)

kibana: x.x.x.x:5601

***Fluentd
Fluentd инструмент, который может использоваться для отправки, агрегации и преобразования лог сообщений. Мы будем использовать Fluentd для агрегации (сбора в одной месте) и парсинга логов сервисов нашего приложения.

Создадим образ Fluentd с нужной нам конфигурацией.
директория logging/ﬂuentd

```Dockerfile
FROM fluent/fluentd:v1.12.0-debian-1.0
USER root
RUN gem uninstall -I elasticsearch && gem install elasticsearch -v 7.17.0
RUN ["gem", "install", "fluent-plugin-elasticsearch", "--no-document", "--version", "5.0.3"]
RUN gem install fluent-plugin-grok-parser -v 2.6.2
COPY fluent.conf /fluentd/etc
USER fluent
```

logging/ﬂuentd/ﬂuent.conf
```
<source>
  @type forward
  port 24224
  bind 0.0.0.0
</source>

# фильтр сообщений от сервиса post
<filter service.post>
  @type parser
  key_name log # в этом случае мы парсим поле log  и все что находится внутри этого поля теперь тоже доступно для фильтрации 
  # (появятся новые значения представленные внутри этого поля разбитые по парам ключ значение)
  <parse>
    @type json
  </parse>
</filter>

# <filter service.ui>
#   @type parser
#   format /\[(?<time>[^\]]*)\]  (?<level>\S+) (?<user>\S+)[\W]*service=(?<service>\S+)[\W]*event=(?<event>\S+)[\W]*(?:path=(?<path>\S+)[\W]*)?request_id=(?<request_id>\S+)[\W]*(?:remote_addr=(?<remote_addr>\S+)[\W]*)?(?:method= (?<method>\S+)[\W]*)?(?:response_status=(?<response_status>\S+)[\W]*)?(?:message='(?<message>[^\']*)[\W]*)?/
#   key_name log
# </filter>

<filter service.ui>
  @type parser
  key_name log
  <parse>
    @type grok
    grok_pattern %{RUBY_LOGGER}
  </parse>  
</filter>

<filter service.ui>
  @type parser
  key_name message
  reserve_data true
  <parse>
    @type grok
    grok_pattern service=%{WORD:service} \| event=%{WORD:event} \| request_id=%{GREEDYDATA:request_id} \| message='%{GREEDYDATA:message}'
  </parse>  
</filter>

<filter service.ui>
  @type parser
  key_name message
  reserve_data true
  <parse>
    @type grok
    grok_pattern service=%{WORD:service} \| event=%{WORD:event} \| path=%{URIPATH:path} \| request_id=%{GREEDYDATA:request_id} \| remote_addr=%{IP:remote_addr} \| method= %{WORD:method} \| response_status=%{NUMBER:response_status}
  </parse>    
</filter>

<match *.**>
  @type copy

  <store>
    @type elasticsearch
    host elasticsearch
    port 9200
    logstash_format true
    logstash_prefix fluentd
    logstash_dateformat %Y%m%d
    include_tag_key true
    type_name access_log
    tag_key @log_name
    flush_interval 1s
  </store>

  <store>
    @type stdout
  </store>
</match>
```

Соберите docker image для ﬂuentd
Из директории logging/ﬂuentd
```bash
docker build -t $USER_NAME/fluentd .
```

По умолчанию, docker использует драйвер json для хранения логов, которая пишется сервисом внутри контейнера в stdout (и stderr)
Файл находится /var/lib/docker/containers/<container-id>/<container-id>-json.log на хосте. Нам же необходимо использовать fluentd. Поэтому, для сервисов ui и post мы переопределяем секцию logging
Для отправки логов во Fluentd используем docker драйвер
https://docs.docker.com/config/containers/logging/fluentd/

docker/docker-compose.yml

```yml
    logging:
      driver: "fluentd"
      options:
        fluentd-address: localhost:24224
        tag: service.post
```
Поднимем инфраструктуру централизованной системы логирования и перезапустим сервисы приложения Из каталога docker
```bash
$ docker-compose -f docker-compose-logging.yml up -d
$ docker-compose down
$ docker-compose up -d
```
Нельзя заходить на сервер kibana из под vpn иначе получим ошибку 
Request must contain a kbn-xsrf header. 
Version: 7.16.2 Build: 46307 Error: Bad Request at fetch_Fetch.fetchResponse (http://34.79.83.252:5601/46307/bundles/core/core.entry.js:8:56906) at async http://34.79.83.252:5601/46307/bundles/core/core.entry.js:8:55074 at async http://34.79.83.252:5601/46307/bundles/core/core.entry.js:8:55031

Создадим несколько постов в приложении:
Kibana - инструмент для визуализации и анализа логов от компании Elastic.
Откроем WEB-интерфейс Kibana для просмотра собранных в
ElasticSearch логов Post-сервиса

### Парсинг структурированных логов
Парсинг json-логов (=структурированных) от сервиса post:
logging/fluentd/fluent.conf
```
# фильтр сообщений от сервиса post
<filter service.post>
  @type parser
  key_name log # в этом случае мы парсим поле log  и все что находится внутри этого поля теперь тоже доступно для фильтрации 
  # (появятся новые значения представленные внутри этого поля разбитые по парам ключ значение)
  <parse>
    @type json
  </parse>
</filter>
```
После этого персоберите образ и перезапустите сервис ﬂuentd
```bash
logging/fluentd $ docker build -t $USER_NAME/fluentd
docker/ $ docker-compose -f docker-compose-logging.yml up -d fluentd
```
Создадим пару новых постов, чтобы проверить парсинг логов
Взглянем на одно из сообщений и увидим, что вместо одного
поля log появилось множество полей с нужной нам информацией

### Парсинг неструктурированных логов
Сервис ui отправляет неструктурированные логи в нескольких форматах. Для парсинга мы можем воспользоваться либо регулярными выражениями, либо готовым grok-шаблоном (именованный шаблон регулярных выражений). Последнее - гораздо удобнее.

По аналогии с post сервисом определим для ui сервиса
драйвер для логирования ﬂuentd в compose-файле

Перезапустим ui сервис Из каталога docker
```bash
$ docker-compose stop ui
$ docker-compose rm ui
$ docker-compose up -d
```

регулярные выражения
```
 <filter service.ui>
   @type parser
   format /\[(?<time>[^\]]*)\]  (?<level>\S+) (?<user>\S+)[\W]*service=(?<service>\S+)[\W]*event=(?<event>\S+)[\W]*(?:path=(?<path>\S+)[\W]*)?request_id=(?<request_id>\S+)[\W]*(?:remote_addr=(?<remote_addr>\S+)[\W]*)?(?:method= (?<method>\S+)[\W]*)?(?:response_status=(?<response_status>\S+)[\W]*)?(?:message='(?<message>[^\']*)[\W]*)?/
   key_name log
 </filter>
 ```

 Парсим с помощью плагина grok

 ```
<filter service.ui>
  @type parser
  key_name log
  <parse>
    @type grok
    grok_pattern %{RUBY_LOGGER}
  </parse>  
</filter>

<filter service.ui>
  @type parser
  key_name message
  reserve_data true
  <parse>
    @type grok
    grok_pattern service=%{WORD:service} \| event=%{WORD:event} \| request_id=%{GREEDYDATA:request_id} \| message='%{GREEDYDATA:message}'
  </parse>  
</filter>

<filter service.ui>
  @type parser
  key_name message
  reserve_data true
  <parse>
    @type grok
    grok_pattern service=%{WORD:service} \| event=%{WORD:event} \| path=%{URIPATH:path} \| request_id=%{GREEDYDATA:request_id} \| remote_addr=%{IP:remote_addr} \| method= %{WORD:method} \| response_status=%{NUMBER:response_status}
  </parse>    
</filter>
 ```

### Zipkin
сервисраспределенного трейсинга

docker/docker-compose-logging.yml
```yml
  zipkin:
    image: openzipkin/zipkin:${ZIPKIN_VERSION}
    ports:
      - "9411:9411"
    networks:
      front_net:
        aliases:
          - zipkin
      back_net:
        aliases:
          - zipkin
```

Для активации трейсов необходимо проинструктировать приложение через специальную переменную окружения:
docker/docker-compose.yml
```dockerfile
  ui:
    environment:
      - ZIPKIN_ENABLED=${ZIPKIN_ENABLED}
	  
  post:
    environment:
      - ZIPKIN_ENABLED=${ZIPKIN_ENABLED}

  comment:
    environment:
      - ZIPKIN_ENABLED=${ZIPKIN_ENABLED}
```
docker/.env
```
ZIPKIN_ENABLED=true
```
### Задание со * (стр. 53)
Задание:
С нашим приложением происходит что-то странное. Пользователи жалуются, что при нажатии на пост они вынуждены долго ждать, пока у них загрузится страница с постом. Жалоб на загрузку других страниц не поступало. Нужно выяснить, в чем проблема, используя Zipkin. 
Репозиторий со сломанным кодом приложения: https://github.com/Artemmkin/bugged-code

Решение:
Исходники приложения размещены в src/bugged-code. "Из коробки" оно не собиралось (у образа ruby:2.2 проблемы с запросом отдельных списков в apt) + отсутствовали необходимые переменные окружения в Dockerfile (видимо, предполагалось, что будут задаваться через секцию environment в docker-compose.yml).
Исправленные Dockerfile выглядят следующим образом:

bugged-code/ui/Dockerfile
```dockerfile
FROM ruby:2.3

RUN apt-get update -qq && apt-get install -y build-essential

ENV APP_HOME /app
RUN mkdir $APP_HOME
WORKDIR $APP_HOME

ADD Gemfile* $APP_HOME/
RUN bundle install

ADD . $APP_HOME

ENV POST_SERVICE_HOST post
ENV POST_SERVICE_PORT 5000
ENV COMMENT_SERVICE_HOST comment
ENV COMMENT_SERVICE_PORT 9292

CMD ["puma"]
```

bugged-code/post-py/Dockerfile
```dockerfile
# FROM python:3.6.0-alpine
FROM python:2.7
WORKDIR /app
ADD requirements.txt /app
RUN pip install -r requirements.txt
ADD . /app
EXPOSE  5000
ENV POST_DATABASE_HOST post_db
ENV POST_DATABASE posts

ENTRYPOINT ["python", "post_app.py"]
```
bugged-code/comment/Dockerfile

```dockerfile
FROM ruby:2.3

RUN apt-get update -qq && apt-get install -y build-essential

ENV APP_HOME /app
RUN mkdir $APP_HOME
WORKDIR $APP_HOME

ADD Gemfile* $APP_HOME/
RUN bundle install

ADD . $APP_HOME

ENV COMMENT_DATABASE_HOST comment_db
ENV COMMENT_DATABASE comments

CMD ["puma"]
```

Чтобы не смешивать образы из веток microservices и bugged-code, подправил docker-build.sh файлы для каждого сервиса - добавил тэг bug. E.g.:
src/bugged-code/ui/docker_build.sh
```bash
docker build -t $USER_NAME/ui:bug .
```

docker/.env
```
UI_VERSION=bug
POST_VERSION=bug
COMMENT_VERSION=bug
```

Теперь можно приступить к трейсингу.
Пример трейса при открытии любого поста:

zipkin: x.x.x.x:9411
```
post./post/<id>: 3.052s
×
Services: post,ui_app
Date Time	Relative Time	Annotation	Address
6/17/2019, 4:57:43 PM	2.463ms	Client Start	10.0.1.5:9292 (ui_app)
6/17/2019, 4:57:43 PM	5.044ms	Server Start	10.0.2.5:5000 (post)
6/17/2019, 4:57:46 PM	3.039s	Server Finish	10.0.2.5:5000 (post)
6/17/2019, 4:57:46 PM	3.054s	Client Finish	10.0.1.5:9292 (ui_app)
Key	Value
http.path	/post/5d07877fa9cc96000e30efba
http.status	200
Server Address	10.0.1.4:5000 (post)
```
- Здесь мы видим, что span post выполняется за 3 секунды. Он соответствует функции find_post(id) в src/bugged-code/post-py/post_app.py:
Поиск нужной функции нужно осуществлять по полю span_name=
в нашем случае это db_find_single_post это название видно в span zipkin

```python
# Retrieve information about a post
@zipkin_span(service_name='post', span_name='db_find_single_post')
def find_post(id):
    start_time = time.time()
    try:
        post = app.db.find_one({'_id': ObjectId(id)})
    except Exception as e:
        log_event('error', 'post_find',
                  "Failed to find the post. Reason: {}".format(str(e)),
                  request.values)
        abort(500)
    else:
        stop_time = time.time()  # + 0.3
        resp_time = stop_time - start_time
        app.post_read_db_seconds.observe(resp_time)
        time.sleep(3)
        log_event('info', 'post_find',
                  'Successfully found the post information',
                  {'post_id': id})
        return dumps(post)
```
Блок else выполняется, если в функции не возникло никаких исключений. За задержку в 3 секунды ответственна строка:
```python
time.sleep(3)
```

# HW#25 (kubernetes-1)
В данной работе мы:
* развернули kubernetes, опираясь на Kubernetes The Hard Way;
* ознакомились с описанием основных примитивов нашего приложения и его дальнейшим запуском в Kubernetes.

## Установка Kubernetes
https://github.com/kelseyhightower/kubernetes-the-hard-way

## Kubernetes
Controller Manager в Kubernetes - это компонент управления, который запускает и мониторит контроллеры Kubernetes. Каждый контроллер отвечает за управление определенным ресурсом в Kubernetes, таким как ReplicaSet, Deployment, StatefulSet, DaemonSet и т.д.
Controller Manager включает в себя несколько контроллеров, каждый из которых является отдельным процессом:
    1. Node Controller - отвечает за обнаружение, добавление и удаление узлов из кластера Kubernetes.
    2. Replication Controller - управляет ReplicaSets и обеспечивает, чтобы определенное количество копий Pod всегда было доступно в кластере.
    3. Endpoints Controller - обновляет Endpoints объекты и обеспечивает, чтобы они содержали актуальную информацию о сервисах и IP-адресах Pod.
    4. Service Account & Token Controllers - отвечают за создание, обновление и удаление учетных записей и токенов сервисных аккаунтов в кластере.
    5. Namespace Controller - обрабатывает создание и удаление пространств имен в кластере.
    6. Service Controller - управляет объектами Service в Kubernetes.
Контроллеры запускаются в режиме постоянного мониторинга состояния объектов, которыми они управляют. Если обнаруживается какое-то несоответствие между текущим и желаемым состоянием объекта, контроллер автоматически принимает меры для исправления ситуации, пока текущее состояние не соответствует желаемому.
Controller Manager является одним из основных компонентов Kubernetes, который обеспечивает надежную и автоматизированную работу кластера, позволяя пользователям создавать, масштабировать и управлять приложениями в контейнерах.

Kubelet - это агент управления узлом в кластере Kubernetes. Kubelet запускается на каждом узле кластера и отвечает за управление контейнерами, которые запущены на этом узле. Kubelet получает информацию о контейнерах, которые должны быть запущены на узле, из API-сервера Kubernetes и затем работает непосредственно с Docker-демоном, чтобы создавать и управлять контейнерами.
Kubelet выполняет следующие функции:
    1. Запускает и останавливает контейнеры на узле в соответствии с API-сервером Kubernetes.
    2. Мониторит работу контейнеров и перезапускает их, если они перестали работать.
    3. Обеспечивает наличие необходимых ресурсов для запуска контейнеров на узле, например, проверяет наличие достаточного количества свободной памяти и процессорного времени.
    4. Предоставляет API-интерфейс для управления контейнерами на узле.
    5. Обновляет состояние узла в API-сервере Kubernetes и отчитывается о статусе контейнеров на узле.
Kubelet работает в тесном взаимодействии с другими компонентами Kubernetes, такими как API-сервер, Scheduler и Controller Manager, и является ключевым элементом в механизме управления контейнерами на узлах кластера.

kube-proxy - это сетевой прокси-сервер, который работает на каждом узле кластера Kubernetes. Он отвечает за маршрутизацию сетевых запросов внутри кластера, обеспечивая доступ к сервисам Kubernetes изнутри и снаружи кластера.
kube-proxy выполняет следующие функции:
    1. Он устанавливает правила IP-маршрутизации и балансировки нагрузки для сервисов Kubernetes.
    2. Он следит за состоянием сервисов и обновляет правила маршрутизации и балансировки нагрузки, если происходят изменения в состоянии сервисов.
    3. Он обеспечивает доступ к сервисам Kubernetes изнутри и снаружи кластера.
    4. Он обеспечивает возможность работы сетевых политик Kubernetes.
kube-proxy работает в тесном взаимодействии с другими компонентами Kubernetes, такими как API-сервер, Scheduler, Controller Manager и Kubelet, и является важным компонентом в механизме работы сервисов и сети в Kubernetes.

kube-scheduler - это компонент Kubernetes, который отвечает за планирование запуска подов на узлах кластера. Kube-scheduler выбирает подходящий узел для запуска пода на основе ряда критериев, таких как доступность ресурсов, местоположение пода и требования к сети.
Когда создается новый под, kube-scheduler анализирует его требования к ресурсам, политику толерантности к отказам и другие параметры, затем выбирает подходящий узел для запуска пода. В случае, если несколько узлов удовлетворяют требованиям пода, kube-scheduler выберет наиболее подходящий из них.
Kube-scheduler использует также возможности сети для планирования размещения подов. Он учитывает требования к сети, такие как доступность сервисов и маршрутизация трафика, при выборе узла для запуска пода.
Kube-scheduler является важным компонентом в механизме управления запуском подов в Kubernetes. Он работает в тесном взаимодействии с другими компонентами Kubernetes, такими как API-сервер, Controller Manager и Kubelet, и обеспечивает эффективное распределение подов по узлам кластера.

etcd - это распределенное хранилище ключ-значение, используемое для хранения конфигурации, метаданных и состояния в кластере Kubernetes. Оно предназначено для сохранения и синхронизации данных между узлами кластера.
etcd является частью стека технологий, используемых в Kubernetes, и предоставляет механизм, необходимый для обеспечения согласованности и надежности кластера. etcd является распределенным, надежным и устойчивым к сбоям хранилищем данных, которое обеспечивает возможность хранения ключ-значение пар с возможностью автоматического определения и устранения ошибок.
В Kubernetes etcd используется для хранения всех важных конфигурационных данных, таких как информация о ресурсах кластера, состояние запущенных приложений, конфигурация сети и т.д. Все компоненты Kubernetes, такие как API-сервер, Scheduler, Controller Manager и Kubelet, общаются с etcd для получения и обновления информации о состоянии кластера.
etcd поддерживает механизмы репликации и распределения данных, что позволяет ему обеспечивать высокую доступность и устойчивость к сбоям. Это позволяет Kubernetes работать бесперебойно даже в случае отказа одного или нескольких узлов кластера.
apiVersion - это поле в конфигурационных файлах Kubernetes, которое указывает на версию API, используемую для определенного ресурса. В Kubernetes API используется схема версионирования, где каждая версия API имеет свой собственный набор объектов и ресурсов.
Например, объекты Deployment, Service и Pod относятся к разным версиям API в Kubernetes:
    • Deployment использует API-версию apps/v1
    • Service использует API-версию v1
    • Pod использует API-версию v1
kind - это поле в конфигурационных файлах Kubernetes, которое указывает на тип ресурса, который вы пытаетесь создать или изменить. Оно определяет объект Kubernetes, который должен быть создан или изменен в вашем кластере.


Deployment – наиболее часто используемый объект API в кластере  Kubernetes. Это типичный объект API, выполняющий развертывание, например, микросервиса;

metadata - это поле в конфигурационных файлах Kubernetes, которое содержит метаданные об объекте, такие как имя объекта, его уникальный идентификатор, аннотации, метки (labels) и т.д.
Каждый объект Kubernetes имеет метаданные, которые определяют его уникальность и помогают в управлении им. Например, имя объекта должно быть уникальным в пределах одного пространства имен (namespace) Kubernetes.
Метаданные также могут содержать аннотации, которые могут использоваться для хранения дополнительной информации о объекте. Это может быть полезно для интеграции с другими системами и инструментами.
Метки (labels) - это пары ключ-значение, которые могут использоваться для сортировки, поиска и выборки объектов. Например, можно использовать метки для разделения приложений на продукционные и тестовые версии.
В конфигурационном файле Kubernetes, метаданные определяются в блоке metadata. Например, вот пример метаданных для объекта Pod:
```
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
  labels:
    app: myapp
  annotations:
    description: "This is my test pod"
```
В этом примере мы определили имя объекта my-pod и метки app: myapp. Мы также определили аннотацию description, которая содержит дополнительную информацию о нашем тестовом поде.

spec - это поле в конфигурационных файлах Kubernetes, которое содержит специфические для ресурса параметры и описание желаемого состояния объекта Kubernetes. в Kubernetes есть множество различных ресурсов, и каждый ресурс имеет свои собственные параметры в поле spec. в поле spec могут быть указаны параметры, такие как количество контейнеров, образы контейнеров и т.д.
В общем случае, поле spec используется для определения желаемого состояния объекта Kubernetes, которое система должна поддерживать. Оно описывает конфигурацию ресурса, который вы хотите создать или изменить в вашем кластере.
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.21.4
        ports:
        - containerPort: 80
```
selector - это поле в конфигурационных файлах Kubernetes, которое определяет, какие объекты Kubernetes будут управляться данным ресурсом.

В этом примере мы указываем метку app: nginx в поле selector, которая соответствует метке, определенной в шаблоне Pod. Таким образом, все Pod'ы, управляемые данным Deployment, будут иметь метку app: nginx, что позволит Deployment отслеживать их состояние и автоматически перезапускать их при необходимости.
Шаблон Pod (Pod template) - это часть конфигурации объекта Deployment, которая описывает, как создавать Pod'ы, управляемые данным Deployment. Шаблон Pod может содержать параметры, такие как образы контейнеров, метки и другие настройки контейнера.
В объекте Deployment в конфигурационном файле Kubernetes, шаблон Pod задается в поле spec.template
В этом примере мы определяем шаблон Pod, содержащий один контейнер Nginx. Метка app: nginx определяется в поле metadata.labels шаблона Pod, и она соответствует метке, которая была определена в поле selector объекта Deployment. 


Для того, чтобы Kubernetes мог загружать контейнеры из реестра Docker Hub, вам нужно указать учетные данные Docker Hub в качестве секрета Kubernetes. Для этого можно воспользоваться командой kubectl create secret docker-registry.
Вот пример создания секрета Docker Hub в Kubernetes:
```bash
kubectl create secret docker-registry my-secret \
    --docker-server=https://index.docker.io/v1/ \
    --docker-username=vasiliybasov \
    --docker-password=<password> \
    --docker-email=<email>
```

В этой команде my-secret - это имя секрета, --docker-server - адрес реестра Docker Hub, --docker-username и --docker-password - это учетные данные вашей учетной записи Docker Hub, а --docker-email - это адрес электронной почты, связанный с вашей учетной записью Docker Hub.

Или если мы уже логинились на dockerhub локально
docker login
то можем зайти через созданный json
cat ~/.docker/config.json

```bash
kubectl create secret generic regcred \
    --from-file=.dockerconfigjson=/home/baggurd/.docker/config.json \
    --type=kubernetes.io/dockerconfigjson
```    
###Расшифровка секрета
kubectl get secret regcred -o jsonpath='{.data.\.dockerconfigjson}' | base64 –decode

Для использования секрета:
```
apiVersion: v1
kind: Pod
metadata:
  name: private-reg
spec:
  containers:
  - name: private-reg-container
    image: <your-private-image>
  imagePullSecrets:
- name: regcred
```
Просмотр и расшифровка секретов
Вы можете просмотреть список секретов в Kubernetes с помощью команды
```bash 
kubectl get secrets
```
. По умолчанию, эта команда показывает все секреты, которые были созданы в кластере.

Чтобы получить подробную информацию о секрете, включая тип секрета и данные, которые он содержит, вы можете использовать команду 
```bash
kubectl describe secret <secret-name>.
```

Если вы хотите расшифровать данные в секрете, вы можете использовать команду
```bash
kubectl get secret <secret-name> -o jsonpath='{.data.<data-key>}' | base64 --decode
```
где <data-key> - это ключ, соответствующий данным, которые вы хотите расшифровать.
```bash
kubectl get secret <secret-name> -o jsonpath='{.data.<data-key>}' | base64 --decode
```
Например, если вы хотите расшифровать данные в секрете my-secret с ключом password, вы можете использовать следующую команду:
```bash
kubectl get secret my-secret -o jsonpath='{.data.password}' | base64 --decode
```

Получить доступ к pod с локального компьютера
```bash
kubectl port-forward ui-deployment-845dd999b-hbh7q 8080:9292
```
Команда kubectl port-forward позволяет установить прямое соединение между локальным компьютером и выбранным подом в Kubernetes, чтобы можно было получить доступ к сервисам, запущенным в этом поде.
В данном случае команда kubectl port-forward ui-deployment-845dd999b-hbh7q 8080:9292 устанавливает соединение с подом, идентифицированным метками app=ui и pod-template-hash=845dd999b, и перенаправляет локальный порт 8080 на порт 9292 в этом поде. Это означает, что если вы откроете браузер и перейдете по адресу http://localhost:8080, то вы сможете получить доступ к веб-интерфейсу, запущенному в поде.

Зайти внутрь контейнера
```bash
kubectl exec -it my-pod -- /bin/bash
```
Здесь опция -it указывает на использование интерактивного терминала, а /bin/bash - на запуск оболочки внутри контейнера. 

Тестовый запуск нашего приложения
Все yaml файлы размещены в kubernetes/reddit.

Чтобы запустить все приложения одновременно через kubectl, вы можете использовать команду kubectl apply с несколькими конфигурационными файлами, содержащими описание ваших приложений.

Если все файлы находятся в одной директории то запускаем:
```bash
kubectl apply -f .
```
Также можно применить каждый файл по отдельности с помощью команды 
```bash
kubectl apply -f <имя файла>.yaml.
```


Проверяем что контейнеры запустились:
```bash
/kubernetes/reddit$ kubectl get pods
```

Пробрасываем порт и пробуем подключиться к ui:
```bash
kubectl port-forward ui-deployment-845dd999b-hbh7q 8080:9292
```

Проверяем через другой терминал
```bash
curl -I http://127.0.0.1:8080
```
```
HTTP/1.1 200 OK
Content-Type: text/html;charset=utf-8
X-XSS-Protection: 1; mode=block
X-Content-Type-Options: nosniff
X-Frame-Options: SAMEORIGIN
Set-Cookie: rack.session=BAh7CEkiD3Nlc3Npb25faWQGOgZFVEkiRTFlNzM0ZTI1OGE5OTQ3MmY5ZTky%0AZjlhMzg2ODhmMmIxOTczNjljZmE3MWRjZDg1NGYzMWMwMmRjYTM5OTYwZWEG%0AOwBGSSIJY3NyZgY7AEZJIjFGNlJhMXlhbUtRbTdnUk0vcHhVT3hBbG1VNXp4%0ANU1PZkhCaDFKUXhNbFAwPQY7AEZJIg10cmFja2luZwY7AEZ7B0kiFEhUVFBf%0AVVNFUl9BR0VOVAY7AFRJIi1jMGJmMzlhMjAzMjY2ZjMyMmNhZmU4YjQ0YmIx%0AYTAzNmVlYzVhNThkBjsARkkiGUhUVFBfQUNDRVBUX0xBTkdVQUdFBjsAVEki%0ALWRhMzlhM2VlNWU2YjRiMGQzMjU1YmZlZjk1NjAxODkwYWZkODA3MDkGOwBG%0A--8d4e20de7757ee8f2b2ee1670f7269642395bb3a; path=/; HttpOnly
Content-Length: 1851
```
Работает

# HW#25 (kubernetes-2) Основные модели безопасности и контроллеры в Kubernetes

Разворачиваем kubernetes локально

- Директории ~/.kube - содержит служебную инфу для kubectl (конфиги, кеши, схемы API)
- minikube - утилиты для разворачивания локальной инсталляции Kubernetes.

- Устанавливаем kubectl
- https://kubernetes.io/docs/tasks/tools/
- Установка Minikube
- https://minikube.sigs.k8s.io/docs/start/

-  Запустим наш Minukube-кластер 
-  minikube start

- Посмотрим ноды:
- kubectl get nodes

Обычно порядок конфигурирования kubectl следующий:
1) Создать cluster:
```
$ kubectl config set-cluster … cluster_name
```
2) Создать данные пользователя (credentials)
```
$ kubectl config set-credentials … user_name
```
3) Создать контекст
```
$ kubectl config set-context context_name \
--cluster=cluster_name \
--user=user_name
```
4) Использовать контекст
```
$ kubectl config use-context context_name
```
Таким образом kubectl конфигурируется для подключения к
разным кластерам, под разными пользователями.

Текущий контекст можно увидеть так:
```
kubectl config current-context
```
Список всех контекстов можно увидеть так:
```
kubectl config get-contexts
```
Переключиться на другой контекста
```
kubectl config use-context <context-name>
```

Прописываем секрет в kubernetes чтобы брать образы из docker hub
```
kubectl create secret generic regcred \
    --from-file=.dockerconfigjson=/home/baggurd/.docker/config.json \
    --type=kubernetes.io/dockerconfigjson
```
Прописываем манифест для pod ui:
ui-deployment.yml

Запустим в Minikube ui-компоненту.
```
kubectl apply -f ui-deployment.yml
```

Проверяем что все применилось. Смотрим наши deployments
```
kubectl get deployment
```
- <deployment-name> - имя деплоймента.
- READY - количество готовых реплик деплоймента.
- UP-TO-DATE - количество реплик, которые соответствуют описанию деплоймента (т.е. не требуют обновления).
- AVAILABLE - количество реплик, которые могут обслуживать запросы.
- AGE - время, прошедшее с момента создания деплоймента.

Пока что мы не можем использовать наше приложение полностью, потому что никак не настроена сеть для общения с ним.
Но kubectl умеет пробрасывать сетевые порты POD-ов на локальную машину

Выведем информацию о подах, которые имеют метку component=ui
```
kubectl get pods --selector component=ui
```
Пробрасываем локальный порт 8080 на порт пода 9292 
```
kubectl port-forward ui-658468bf9b-9fxcp 8080:9292
```
Не закрывая консоли проверяем в браузере что приложение работает
http://localhost:8080

UI работает, подключим остальные компоненты

comment-deployment.yml
post-deployment.yml
Не забудьте, что post слушает по-умолчанию на порту 5000
mongo-deployment.yml

### Services

В Kubernetes ресурс kind: Service используется для создания стабильного сетевого интерфейса для доступа к одному или нескольким репликам подов в кластере.

Сервисы позволяют абстрагировать работу с подами, предоставляя стабильный IP-адрес или доменное имя, которое можно использовать для связи с ними, вне зависимости от того, на какой ноде кластера они запущены и какие IP-адреса им присвоены.

В зависимости от типа сервиса, он может быть доступен только внутри кластера, или же иметь внешний IP-адрес, чтобы быть доступным извне. Кроме того, сервисы позволяют настраивать балансировку нагрузки между несколькими репликами подов, а также настраивать маршрутизацию трафика на основе различных параметров, таких как имя пода или метки, которые ему присвоены.

В текущем состоянии приложение не будет работать, так его компоненты ещё не знают как найти друг друга
Для связи компонент между собой и с внешним миром используется объект Service – абстракция, которая определяет набор POD-ов (Endpoints) и способ доступа к ним

Каждый сервис в Kubernetes получает виртуальный IP-адрес (ClusterIP), который используется для связи с сервисом из других частей кластера. IP-адрес сервиса назначается из диапазона адресов, указанных при настройке кластера.
IP-адрес конкретного сервиса можно узнать с помощью команды 
- kubectl get svc <service-name>, где <service-name> - имя сервиса. Например, для сервиса comment команда будет выглядеть так: 
- kubectl get svc comment
Полученный IP-адрес будет являться виртуальным IP-адресом сервиса в рамках кластера Kubernetes. Этот адрес можно использовать для связи с сервисом из других частей кластера. Если необходим доступ к сервису извне кластера, необходимо использовать другие типы сервисов, такие как NodePort или LoadBalancer.

Для связи ui с post и comment нужно создать им по объекту Service. Создаем объекты 

- comment-service.yml
- post-service.yml
- mongodb-service.yml
- ui-service.yml

Узнать ip адрес сервиса
```
kubectl get svc comment
```

Посмотреть имена подов:
```
kubectl get pods
```

Посмотреть ip алреса endpoints
```
kubectl describe service comment | grep Endpoints
```

После того как мы настроили service для comment имя comment должно разрешаться из любого pod
```
kubectl exec -ti post-656c84c57d-d4mnb nslookup comment
```
```
nslookup: can't resolve '(null)': Name does not resolve
Name:      comment
Address 1: 10.107.114.159 comment.default.svc.cluster.local
```

Когда мы создали services для каждого deployment все равно приложение не работает.
Попробуем создать пост или помотреть все посты и смотрим логи pod-ов
```
kubectl logs post-656c84c57d-tm42b
```

В логах можем увидеть что мы не можем подключиться к базе данных по адресу post_db:27017

Но мы должны подключаться к mongodb а не post_db
post_db прописано в переменной Dockerfile
- ENV POST_DATABASE_HOST=post_db

В Docker Swarm проблема доступа к одному ресурсу под разными именами решалась с помощью сетевых алиасов.
В Kubernetes такого функционала нет. Мы эту проблему можем решить с помощью тех же Service-ов.

- Делаем сервисы с именами comment-db и post-db
- Это сервисы для подключения к базам данных comment и post

- comment-mongodb-service.yml
- post-mongodb-service.yml

Вносим нужные изменения в mongo-deployment.yml чтобы созданные сервисы туда подключались

Так же мы должны поменять переменные указанные в Dockerfile прописать их в:
- comment-deployment.yml
- post-deployment.yml
```yaml
        env:
        - name: COMMENT_DATABASE_HOST
          value: comment-db    
```
Удалите объект mongodb-service он нам больше не нужен
```
$ kubectl delete -f mongodb-service.yml
```
Или
```
$ kubectl delete service mongodb
```
Нам нужно как-то обеспечить доступ к ui-сервису снаружи.
Для этого нам понадобится Service для UI-компоненты
```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: ui
  labels:
    app: reddit
    component: ui
spec:
  # Настройка для полученияя доступа извне. Доступ на порту 32092
  type: NodePort
  ports:
    - nodePort: 32092
      port: 9292
      protocol: TCP
      targetPort: 9292
  selector:
    app: reddit
    component: ui
```
По-умолчанию все сервисы имеют тип ClusterIP - это значит, что сервис
распологается на внутреннем диапазоне IP-адресов кластера. Снаружи до него
нет доступа.

Тип NodePort - на каждой ноде кластера открывает порт из диапазона
30000-32767 и переправляет трафик с этого порта на тот, который указан в
targetPort Pod (похоже на стандартный expose в docker)

Теперь до сервиса можно дойти по <Node-IP>:<NodePort>
Также можно указать самим NodePort (но все равно из диапазона):

Т.е. в описании service
NodePort - для доступа снаружи кластера
port - для доступа к сервису изнутри кластера

Узнать ip всех нод
```bash
$ kubectl get nodes -o wide
```
или только адреса
```bash
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'
```

Minikube может выдавать web-странцы с сервисами которые были помечены типом NodePort
```bash
minikube service ui
```

Minikube может перенаправлять на web-странцы с сервисами которые были помечены типом NodePort Посмотрите на список сервисов:
```bash
minikube service list
```
Minikube также имеет в комплекте несколько стандартных аддонов
(расширений) для Kubernetes (kube-dns, dashboard, monitoring,…).
Каждое расширение - это такие же PODы и сервисы, какие
создавались нами, только они еще общаются с API самого Kubernetes

Получить список расширений:
```bash
$ minikube addons list
```
Интересный аддон - dashboard. Это UI для работы с
kubernetes. По умолчанию в новых версиях он включен.
Как и многие kubernetes add-on'ы, dashboard запускается в
виде pod'а.
Если мы посмотрим на запущенные pod'ы с помощью
команды kubectl get pods, то обнаружим только наше
приложение.
Потому что поды и сервисы для dashboard-а были запущены
в namespace (пространстве имен) kube-system.
Мы же запросили пространство имен default.

Namespace - это, по сути, виртуальный кластер Kubernetes
внутри самого Kubernetes. Внутри каждого такого кластера
находятся свои объекты (POD-ы, Service-ы, Deployment-ы и
т.д.), кроме объектов, общих на все namespace-ы (nodes,
ClusterRoles, PersistentVolumes)
В разных namespace-ах могут находится объекты с
одинаковым именем, но в рамках одного namespace имена
объектов должны быть уникальны.

При старте Kubernetes кластер уже имеет 3 namespace:


- default - для объектов для которых не определен другой Namespace (в нем мы работали все это время)
- kube-system - для объектов созданных Kubernetes’ом и для управления им
- kube-public - для объектов к которым нужен доступ из любой точки кластера

Активировать плагин dashboard в minikube
```bash
minikube addons enable dashboard
```

Запустить dashboard
```bash
minikube dashboard
```

http://127.0.0.1:40679/api/v1/namespaces/kubernetes-dashboard/services/http:kubernetes-dashboard:/proxy/#/workloads?namespace=default

В самом Dashboard можно:
- отслеживать состояние кластера и рабочих нагрузок в нем
- создавать новые объекты (загружать YAML-файлы)
- Удалять и изменять объекты (кол-во реплик, yaml-файлы)
- отслеживать логи в Pod-ах
- при включении Heapster-аддона смотреть нагрузку на Pod-ах
- и т.д.

### Namespace
Отделим среду для разработки приложения от всего остального кластера.
Для этого создадим свой Namespace dev
```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: dev
```
```bash
kubectl apply -f dev-namespace.yml
```
Запустим приложение в dev неймспейсе сначала поменяем порт NodePort ui сервисе чтобы небыло конфликта

смотрим результатам
```bash
minikube service ui -n dev
```

Давайте добавим инфу об окружении внутрь контейнера UI
Эта секция в файле описания Kubernetes-объекта Deployment определяет переменную окружения для контейнера, который будет запущен в поде.
Конкретно, секция "env" определяет переменную окружения с именем "ENV", которая будет доступна внутри контейнера. Значение этой переменной определяется с помощью поля "valueFrom", которое ссылается на метаданные (metadata) Namespace этого объекта Kubernetes.

Таким образом, в этом примере значение переменной "ENV" будет равно имени Namespace, в котором будет развернут этот Deployment.
```yaml
        env:
        - name: ENV
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace  
```
Применяем новые настройки
```bash
kubectl apply -f /home/baggurd/microservices/kubernetes/reddit/ui-deployment.yml -n dev
```
На сайте заголовке видим приписку Microservices Reddit in dev ui-ff5c4db7f-6b2kl container

### Разворачиваем Kubernetes в Google GKE

- Запущено создание кластера Kubernetes через web-консоль Google Cloud
- Подключимся к GKE для запуска нашего приложения. Добавляем нужные права.
- Меняем учетную запись gcloud config set account sl******v@gmail.com
- Добавляем роль
```bash
gcloud projects add-iam-policy-binding docker-377610 --member=serviceAccount:docker@docker-377610.iam.gserviceaccount.com --role=roles/container.admin
```
- Меняем учетку на сервисный аккаунта
```bash
gcloud config set account docker@docker-377610.iam.gserviceaccount.com
```
- Ставим plugin для подключения
```bash
sudo apt-get update
sudo apt-get install google-cloud-sdk-gke-gcloud-auth-plugin
```
Добавляем в ~/.kube/config данные для подключения:
```bash
gcloud container clusters get-credentials cluster-1 --zone us-central1-c --project docker-377610
```
Эту команду можно взять в: clusters – три вертикальных точки - connect

В результате в файл ~/.kube/config будут добавлены user, cluster и context для подключения к кластеру в GKE.
Также текущий контекст будет выставлен для подключения к этому кластеру. Убедиться можно, введя
```bash
kubectl config current-context
```

### Запустим наше приложение в GKE

Создадим dev namespace
```bash
$ kubectl apply -f ./kubernetes/reddit/dev-namespace.yml
```
Посмотреть
```bash
kubectl get namespaces
```

Посмотреть состояние компонентов кластерам
```bash
kubectl get componentstatuses
```

Задеплоим все компоненты приложения в namespace dev:
```bash
kubectl apply -f ./kubernetes/reddit/ -n dev
```

Откроем Reddit для внешнего мира:
Зададим правила Firewall. мы открыли порты tcp:30000-32767 для all instances.
```bash
gcloud compute firewall-rules create kube-reddit --allow tcp:30000-32767 --direction INGRESS --source-ranges 0.0.0.0/0
```

Посмотрим наши ноды с ip адресами
```bash
kubectl get nodes -o wide
```
Посмотрим порт нашего приложениям
```bash
kubectl describe service ui -n dev | grep NodePort
```

Проверяем что приложение доступно
http://34.27.188.190:32091/
http://104.154.226.105:32091/



### Разверните Kubenetes-кластер в GKE с помощью Terraform модуля
- Подготовил сценарий создания кластера при помощи terraform согласно рекомендациям.
/kubernetes/terraform

Kubernetes Dashboard add-on больше не поддерживается
https://cloud.google.com/kubernetes-engine/docs/concepts/dashboards


## Homework Kubernetes. Network. Storage

### Сетевое взаимодействие
Service - определяет конечные узлы доступа (Endpoint’ы):
•селекторные сервисы (k8s сам находит POD-ы по label’ам)
•безселекторные сервисы (мы вручную описываем конкретные endpoint’ы)
и способ коммуникации с ними (тип (type) сервиса):
•ClusterIP - дойти до сервиса можно только изнутри кластера
•nodePort - клиент снаружи кластера приходит на опубликованный порт
•LoadBalancer - клиент приходит на облачный (aws elb, Google gclb) ресурс балансировки
•ExternalName - внешний ресурс по отношению к кластеру

ClusterIP - это виртуальный (в реальности нет интерфейса, pod’а или машины с таким адресом) IP-адрес из диапазона адресов для работы внутри, скрывающий за собой IP-адреса реальных POD-ов. Сервису любого типа (кроме ExternalName) назначается этот IP-адрес.
kubectl get services -n dev

#### Kube-DNS
Отметим, что Service - это лишь абстракция и описание того, как получить доступ к сервису. Но опирается она на реальные механизмы и объекты: DNS-сервер, балансировщики, iptables.

Для того, чтобы дойти до сервиса, нам нужно узнать его адрес по имени. Kubernetes не имеет своего собственного DNS-сервера для разрешения имен. Поэтому используется плагин kube-dns (это тоже Pod).
Его задачи:
• ходить в API Kubernetes’a и отслеживать Service-объекты
• заносить DNS-записи о Service’ах в собственную базу
• предоставлять DNS-сервис для разрешения имен в IP-адреса (как внутренних, так и внешних)

При отключенном kube-dns сервисе связность между компонентами reddit-app пропадет и он перестанет работать.

Посмотрим наши сервисы в kube-system
```bash
kubectl get deployment --namespace=kube-system
```
Отключим сервис kube-dns-autoscaler который следит чтобы dns-kube подов всегда хватало
```bash
kubectl scale deployment --replicas 1 -n kube-system kube-dns-autoscaler
```
Отключим dns-kube
```bash
kubectl scale deployment kube-dns --replicas=0 -n kube-system
```
Попробуйте достучатсья по имени до любого сервиса.
Например:
```bash
kubectl exec -ti -n dev post-747469c777-5f2lm -- ping comment
```
ping: bad address 'comment'
command terminated with exit code 1
Вернем kube-dns-autoscale в исходную
```bash
kubectl scale deployment --replicas 1 -n kube-system kube-dns-autoscaler
```
Проверьте, что приложение заработало (в браузере)

Как уже говорилось, ClusterIP - виртуальный и не принадлежит ни одной реальной физической сущности. Его чтением и дальнейшими действиями с пакетами, принадлежащими ему, занимается в нашем случае iptables, который настраивается утилитой kube-proxy (забирающей инфу с API-сервера).

Сам kube-proxy, можно настроить на прием трафика, но это устаревшее поведение и не рекомендуется его применять.

Посмотреть правила IPTABLES на ноде
```bash
sudo iptables -v -n -L | column -t
```

Посмотреть pods
```bash
kubectl get pods -n dev
```
Посмотреть к какой ноде принадлежит pod
```bash
kubectl get pod comment-665df5959f-mvvtc -o wide -n dev
```

На самом деле, независимо от того, на одной ноде находятся поды или на разных - трафик проходит через цепочку, изображенную на предыдущем слайде.

Kubernetes не имеет в комплекте механизма организации overlay-сетей (как у Docker Swarm). Он лишь предоставляет интерфейс для этого. Для создания Overlay-сетей используются отдельные аддоны: Weave, Calico, Flannel, … . В Google Kontainer Engine (GKE) используется собственный плагин kubenet (он - часть kubelet).

Он работает только вместе с платформой GCP и, по-сути занимается тем, что настраивает google-сети для передачи трафика Kubernetes. Поэтому в конфигурации Docker сейчас вы не увидите никаких Overlay-сетей.

Посмотреть правила, согласно которым трафик отправляется на ноды можно здесь:
https://console.cloud.google.com/networking/routes/

####nodePort

Service с типом NodePort - похож на сервис типа ClusterIP, только к нему прибавляется прослушивание портов нод (всех нод) для доступа к сервисам снаружи. При этом ClusterIP также назначается этому сервису для доступа к нему изнутри кластера.

kube-proxy прослушивается либо заданный порт
(nodePort: 32092), либо порт из диапазона 30000-32670.

Дальше IPTables решает, на какой Pod попадет трафик.
Сервис UI мы уже публиковали наружу с помощью NodePort

Тип NodePort хоть и предоставляет доступ к сервису снаружи, но открывать все порты наружу или искать IP-адреса наших нод (которые вообще динамические) не очень удобно.

####LoadBalancer

Тип LoadBalancer позволяет нам использовать внешний облачный балансировщик нагрузки как единую точку входа в наши сервисы, а не полагаться на IPTables и не открывать наружу весь кластер.

Настроим соответствующим образом Service UI
```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: ui
  labels:
    app: reddit
    component: ui
spec:
  # Настройка для полученияя доступа извне. Доступ на порту 32092
  type: LoadBalancer
  ports:
    # Порт который будет открыт на балансировщике
    - port: 80
      # Также на ноде будет открыт порт, но нам он не нужен и его можно даже убрать
      nodePort: 32091
      protocol: TCP
      # Порт pod-а
      targetPort: 9292
  selector:
    app: reddit
    component: ui
```
Настроим соответствующим образом Service UI
```bash
kubectl apply -f ui-service.yml -n dev
```

Получим список сервисов Kubernetes, соответствующих селектору component=ui, в пространстве имён dev т.е. наш ui service.
```bash
kubectl get service -n dev --selector component=ui
```
Немного подождем и сервис получит External_IP
```bash
kubectl get service -n dev --selector component=ui
```

34.121.151.16  наш адрес
Проверим в браузере: http://<external-ip>:port

Будет создано правило для балансировки:
Балансировка с помощью Service типа LoadBalancing имеет ряд недостатков:
• нельзя управлять с помощью http URI (L7-балансировка)
• используются только облачные балансировщики (AWS, GCP)
• нет гибких правил работы с трафиком

#### Ingress

Для более удобного управления входящим снаружи трафиком и решения недостатков
LoadBalancer можно использовать другой объект Kubernetes - Ingress.
Ingress – это набор правил внутри кластера Kubernetes, предназначенных для того, чтобы входящие подключения могли достичь сервисов (Services)

Сами по себе Ingress’ы это просто правила. Для их применения нужен Ingress Controller.

#### Ingress Conroller

Для работы Ingress-ов необходим Ingress Controller.
В отличие остальных контроллеров k8s - он не стартует вместе с кластером.

Ingress Controller - это скорее плагин (а значит и отдельный POD), который состоит из 2-х функциональных частей:

•Приложение, которое отслеживает через k8s API новые объекты Ingress и обновляет конфигурацию балансировщика
•Балансировщик (Nginx, haproxy, traefik,…), который и занимается управлением сетевым трафиком

Основные задачи, решаемые с помощью Ingress’ов:

• Организация единой точки входа в приложения снаружи
• Обеспечение балансировки трафика
• Терминация SSL
• Виртуальный хостинг на основе имен и т.д

Посколько у нас web-приложение, нам вполне было бы логично использовать L7-балансировщик вместо Service LoadBalancer.
Google в GKE уже предоставляет возможность использовать их собственные решения балансирощик в качестве Ingress controller-ов.

Убедитесь, что встроенный Ingress включен.
Если нет - включите

Перейдите в настройки кластера в веб-консоли gcloud
https://console.cloud.google.com/kubernetes

Убедитесь, что встроенный Ingress включен. 
Для работы Ingress-ов необходим Ingress Controller.
В отличие остальных контроллеров k8s - он не стартует вместе с кластером.

Ingress Controller - это скорее плагин (а значит и отдельный POD), который состоит из 2-х функциональных частей:

•Приложение, которое отслеживает через k8s API новые объекты Ingress и обновляет конфигурацию балансировщика
•Балансировщик (Nginx, haproxy, traefik,…), который и занимается управлением сетевым трафиком

Основные задачи, решаемые с помощью Ingress’ов:

• Организация единой точки входа в приложения снаружи
• Обеспечение балансировки трафика
• Терминация SSL
• Виртуальный хостинг на основе имен и т.д

Посколько у нас web-приложение, нам вполне было бы логично использовать L7-балансировщик вместо Service LoadBalancer.
Google в GKE уже предоставляет возможность использовать их собственные решения балансирощик в качестве Ingress controller-ов.

Убедитесь, что встроенный Ingress включен.
Если нет - включите

Перейдите в настройки кластера в веб-консоли gcloud
https://console.cloud.google.com/kubernetes

Убедитесь, что встроенный Ingress включен. 
HTTP Load Balancing Enabled

Создадим Ingress для сервиса UI

```yaml
---
# этот конфигурационный файл определяет Ingress ресурс с именем "ui", 
# который настроен на использование сервиса "ui" и порта 80 в качестве backend для маршрутизации входящих HTTP запросов.
apiVersion: networking.k8s.io/v1
kind: Ingress
# Определяет метаданные для ресурса, такие как имя.
metadata:
  # имя Ingress ресурса.
  name: ui
# спецификация Ingress ресурса.
spec:
 # здесь мы определяем правила маршрутизации для входящих запросов.
  rules:
  # мы указываем, что будем маршрутизировать запросы по HTTP протоколу.
  - http:
      # здесь мы определяем пути, которые будут маршрутизироваться.
      paths:
      # мы определяем, что будем маршрутизировать запросы с корневого пути.
      - path: /
        # это указывает, что мы будем использовать префиксное сопоставление для маршрутизации запросов. 
        # То есть любой запрос, который начинается с указанного пути, будет считаться соответствующим.
        pathType: Prefix
        # здесь мы определяем, какой сервис будет обрабатывать запросы, соответствующие указанному пути.
        backend:
          # мы указываем, что будем использовать сервис для обработки запросов.
          service:
            # мы указываем имя сервиса, который будет обрабатывать запросы.
            name: ui
            port:
              number: 80
```
Это Singe Service Ingress - значит, что весь ingress контроллер будет просто балансировать нагрузку на Node-ы для одного сервиса (очень похоже на Service LoadBalancer)

Этот сервис определяет Ingress ресурс для Kubernetes, который позволяет управлять входящим трафиком в приложения, развернутые в кластере Kubernetes.
В данном случае, Ingress определяет обратное проксирование для сервиса с именем "ui" на порт 80, который должен быть настроен на прием входящих HTTP запросов и маршрутизировать их на соответствующие поды или контейнеры внутри кластера.
Это позволяет внешним клиентам обращаться к приложению, не зная о его внутреннем расположении и необходимости взаимодействия с конкретными подами или контейнерами.

Один из основных примеров применения обратного прокси - это балансировка нагрузки (load balancing), при которой несколько серверов обслуживают один URL или доменное имя, а Обратный прокси распределяет трафик между ними. Обратный прокси может также обеспечивать дополнительные функции, такие как кэширование, сжатие, шифрование трафика, блокировка вредоносных запросов и другие.
Обратное проксирование также может использоваться для скрытия внутренней инфраструктуры от внешнего доступа, например, чтобы скрыть IP-адреса имен серверов внутри сети от внешнего мира.
Применим конфиг
```bash
kubectl apply -f ui-ingress.yml -n dev
```

Зайдем в консоль GCP и увидим уже несколько правил:
https://console.cloud.google.com/net-services/loadbalancing/loadBalancers/list

Посмотрим в сам кластер:
```bash
kubectl get ingress -n dev
NAME   CLASS    HOSTS   ADDRESS        PORTS   AGE
ui          <none>        *           34.111.45.26       80      16h
 ```

Адрес сервиса (если не появился, подождите)
http://34.111.45.26 :80

В текущей схеме есть несколько недостатков:
• у нас 2 балансировщика для 1 сервиса
• Мы не умеем управлять трафиком на уровне HTTP

Один балансировщик можно спокойно убрать. Обновим сервис для UI

Убираем настройку LoadBalancer в ui-service.yml и меняем ее на NodePort
```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: ui
  labels:
    app: reddit
    component: ui
spec:
  # Настройка для полученияя доступа извне. Доступ на порту 32092
#  type: LoadBalancer
  # Для работы с Ingress в GCP нам нужен минимум Service с типом NodePort: 
  type: NodePort
  ports:
    # Порт который будет открыт на балансировщике
 #   - port: 80
    # Порт на который будет обращаться Ingress сервис.
    - port: 9292
      # Также на ноде будет открыт порт, но нам он не нужен и его можно даже убрать
#       nodePort: 32091
      protocol: TCP
      # Порт pod-а
      targetPort: 9292
  # К каким объектам будет применяься настройка:    
  selector:
    app: reddit
    component: ui
```

Меняем порт на ui-ingress.yml
```yaml
            port:
              number: 9292
```

Применяем настройки
```bash
kubectl apply -f ui-service.yml -n dev
kubectl apply -f ui-ingress.yml -n dev
```
```bash
kubectl get ingress -n dev
```

Проверяем что приложение работает.
http://34.111.45.26/

#### Secret

Теперь давайте защитим наш сервис с помощью TLS.

Далее подготовим сертификат используя IP как CN
Данная настройка выполняет создание самоподписанного сертификата SSL/TLS с помощью утилиты OpenSSL. В результате создания сертификата будет создана пара ключей (private key) и сам сертификат (certificate).
```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=34.111.45.26"
```
Конкретно в этой команде мы:
    • req: используем команду OpenSSL для генерации запроса на сертификат.
    • -x509: указываем, что мы хотим сгенерировать самоподписанный сертификат X.509.
    • -nodes: генерируем приватный ключ без пароля, чтобы не требовалось вводить пароль каждый раз при использовании ключа.
    • -days 365: задаем срок действия сертификата на 1 год.
    • -newkey rsa:2048: генерируем новую пару ключей RSA длиной 2048 бит.
    • -keyout tls.key: указываем, что приватный ключ должен быть сохранен в файл tls.key.
    • -out tls.crt: указываем, что сертификат должен быть сохранен в файл tls.crt.
    • -subj "/CN=34.111.45.26/": устанавливаем параметр subject (субъект) сертификата с указанием Common Name (CN) - в данном случае, это IP-адрес, который будет использоваться в качестве имени сервера при подключении к нему по HTTPS.

После выполнения этой команды в текущей директории будут созданы два файла: tls.key (приватный ключ) и tls.crt (сертификат). Эти файлы могут быть использованы для настройки HTTPS соединения между сервером и клиентами.
И загрузим сертификат в кластер kubernetes
```bash
kubectl create secret tls ui-ingress --key tls.key --cert tls.crt -n dev
```

посмотреть секреты
```bash
kubectl get secrets -n dev
```
Подробная информация
```bash
kubectl describe secret ui-ingress -n dev
```

#### TLS Termination
Теперь настроим Ingress на прием только HTTPS траффика
ui-ingress.yml
```yaml
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ui
  # это блок метаданных (metadata) для Kubernetes-объекта, который позволяет хранить произвольные пары "ключ-значение" в виде аннотаций
  # Например, в Ingress-объекте аннотации могут использоваться для настройки поведения Ingress-контроллера, который обрабатывает HTTP-запросы и маршрутизирует их на соответствующие сервисы в Kubernetes-кластере.
  annotations:
    # Перенаправляет все http запросы на https, также требует, чтобы на сервере был установлен SSL-сертификат и ключ, даже если само соединение использует HTTP-протокол. Если сервер не настроен с SSL-сертификатом и ключом, то запросы будут отвергнуты с ошибкой.    
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    # изменяет путь запроса на /, что означает, что он будет передан целевому сервису без изменений. Таким образом, в приложении можно настроить обработку запросов, которые пришли на конкретный путь, например /api/v1 или /dashboard, и все запросы будут корректно переданы соответствующему сервису внутри кластера Kubernetes.
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  tls:
  - secretName: ui-ingress
 # здесь мы определяем правила маршрутизации для входящих запросов.
  rules:
  # мы указываем, что будем маршрутизировать запросы по HTTP протоколу.
  - http:
      # здесь мы определяем пути, которые будут маршрутизироваться.
      paths:
      # мы определяем, что будем маршрутизировать запросы с корневого пути.
      - path: /
        # это указывает, что мы будем использовать префиксное сопоставление для маршрутизации запросов. 
        # То есть любой запрос, который начинается с указанного пути, будет считаться соответствующим.
        pathType: Prefix
        # здесь мы определяем, какой сервис будет обрабатывать запросы, соответствующие указанному пути.
        backend:
          # мы указываем, что будем использовать сервис для обработки запросов.
          service:
            # мы указываем имя сервиса, который будет обрабатывать запросы.
            name: ui
            # Порт на который будет посылаться трафик на сервис NodePort (прописан в ui-service.yml)
            port:
              number: 9292
```
Применем
```bash
kubectl apply -f ui-ingress.yml -n dev
```
Иногда протокол HTTP может не удалиться у существующего
Ingress правила, тогда нужно его вручную удалить и пересоздать
```bash
$ kubectl delete ingress ui -n dev
$ kubectl apply -f ui-ingress.yml -n dev
```
После пересоздание может поменяться ip адрес

Заходим на страницу нашего приложения по https,
подтверждаем исключение безопасности (у нас сертификат
самоподписанный) и видим что все работает
Правила Ingress могут долго применяться, если не
получилось зайти с первой попытки - подождите и
попробуйте еще раз

#### HW 27: Задание со *

пишите создаваемый объект Secret в виде Kubernetes-манифеста:
Данная команда создает манифест объекта Secret, который содержит TLS-сертификат и ключ для использования в Ingress, и сохраняет его в файл ui-ingress-secret.yml
```bash
kubectl create secret tls ui-ingress --key tls.key --cert tls.crt -n dev -o yaml --dry-run=client > ui-ingress-secret.yml
```
С помощью этой команды мы записываем команду
kubectl create secret tls ui-ingress --key tls.key --cert tls.crt -n dev
в манифест ui-ingress-secret.yml
ключ -dry-run=client означает не применять настройки к кластеру а только проверить что команада выполняется без ошибок.
Параметр -o yaml используется для вывода объекта Secret в формате YAML

#### Network Policy
В прошлых проектах мы договорились о том, что хотелось бы разнести сервисы базы данных и сервис фронтенда по разным сетям, сделав их недоступными друг для друга. И приняли следующую схему сервисов.

В Kubernetes у нас так сделать не получится с помощью отдельных сетей, так как все POD-ы могут достучаться друг до друга по-умолчанию.

Мы будем использовать NetworkPolicy – инструмент для декларативного описания потоков трафика. Отметим, что не все сетевые плагины поддерживают политики сети.

В частности, у GKE эта функция пока в Beta-тесте и для её работы отдельно будет включен сетевой плагин Calico (вместо Kubenet).

Давайте ее протеструем.
Наша задача - ограничить трафик, поступающий на mongodb отовсюду, кроме сервисов post и comment.
Найдите имя кластера
```bash
gcloud beta container clusters list
NAME         LOCATION       MASTER_VERSION   MASTER_IP       MACHINE_TYPE  NODE_VERSION     NUM_NODES  STATUS
dev-cluster  us-central1-c  1.24.9-gke.3200  146.148.104.77  g1-small      1.24.9-gke.3200  2          RUNNING
```

Включим network-policy для GKE.
```bash
gcloud beta container clusters update dev-cluster \
--zone=us-central1-c --update-addons=NetworkPolicy=ENABLED
```
```bash
gcloud beta container clusters update dev-cluster \
--zone=us-central1-c --enable-network-policy
```

### Хранилище для базы

Рассмотрим вопросы хранения данных. Основной Stateful сервис в нашем приложении - это база данных MongoDB.
В текущий момент она запускается в виде Deployment и хранит данные в стаднартный Docker Volume-ах. Это имеет несколько проблем:

    • при удалении POD-а удаляется и Volume
    • потеря Nod’ы с mongo грозит потерей данных
    • запуск базы на другой ноде запускает новый экземпляр данных
```yaml
    spec:
      containers:
      - image: mongo:4.0-xenial
        name: mongo
        # Точка монтирования в контейнере (не в POD-е)
        volumeMounts:
        - name: mongo-persistent-storage
          # Путь в контейнере до базы данных
          mountPath: /data/db
      # Ассоциированные с POD-ом Volume-ы В данном примере mongo-persistent-storage является типом Kubernetes emptyDir, который создает временную директорию внутри контейнера.
      # При перезапуске контейнера, содержимое этой директории будет удалено.
      volumes:
      - name: mongo-persistent-storage
        emptyDir: {}
        # hostPath:
        #   path: /home/baggurd/kub_mongodb
```
Сейчас используется тип Volume emptyDir. При создании пода с таким типом просто создается пустой docker volume.
При остановке POD’a содержимое emtpyDir удалится навсегда. Хотя
в общем случае падение POD’a не вызывает удаления Volume’a.

Задание:
1) создайте пост в приложении
2) удалите deployment для mongo
3) Создайте его заново
```bash
kubectl get deployments -n dev
kubectl delete deployment mongo -n dev
kubectl apply -f mongo-deployment.yml -n dev
```
Вместо того, чтобы хранить данные локально на ноде, имеет смысл подключить удаленное хранилище. В нашем случае можем использовать Volume gcePersistentDisk, который будет складывать данные в хранилище GCE

Создадим диск в Google Cloud
```bash
gcloud compute disks create --size=25GB --zone=us-central1-c reddit-mongo-disk
```

Добавим новый Volume POD-у базы.
```yaml
      volumes:
      - name: mongo-gce-pd-storage
        gcePersistentDisk: # тип volume, указывает на использование Google Compute Engine Persistent Disk
          pdName: reddit-mongo-disk # Имя диска который мы создали в GCP
          fsType: ext4
```
```bash
kubectl apply -f mongo-deployment.yml -n dev
```
Дождитесь, пересоздания Pod'а (занимает до 10 минут).
Зайдем в приложение и добавим пост

Удалим deployment
```bash
kubectl delete deploy mongo -n dev
```
Снова создадим деплой mongo
```bash
kubectl apply -f mongo-deployment.yml -n dev
```

Наш пост все еще на месте
Здесь можно посмотреть на созданный диск и увидеть какой машиной он используется
https://console.cloud.google.com/compute/disks

#### PersistentVolume
Используемый механизм Volume-ов можно сделать удобнее.
Мы можем использовать не целый выделенный диск для каждого пода, а целый ресурс хранилища, общий для всего кластера.

Тогда при запуске Stateful-задач в кластере, мы сможем запросить хранилище в виде такого же ресурса, как CPU или оперативная память.

Для этого будем использовать механизм PersistentVolume.

Создадим описание PersistentVolume
mongo-volume.yml
```yaml
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: reddit-mongo-disk
spec:
  capacity:
    storage: 25Gi
  # Том может быть смонтирован в режиме чтения-записи только на одном узле (node) в кластере Kubernetes  
  accessModes:
    - ReadWriteOnce
  # Определяет политику удаления для PersistentVolume
  # Показывает на то, что даже если PersistentVolumeClaim (PVC), который использует этот PV, будет удален, 
  # то сам PV не будет удален автоматически и его содержимое сохранится. Вместо этого PV будет отмечен как 
  # "Released" и будет ожидать дальнейшего действия, такого как повторное использование с помощью другого PVC или удаление вручную.
  persistentVolumeReclaimPolicy: Retain
  gcePersistentDisk:
    fsType: "ext4" 
    pdName: "reddit-mongo-disk" # Имя диска в GCE
```

Добавим PersistentVolume в кластер
```bash
$ kubectl apply -f mongo-volume.yml -n dev
```
Мы создали PersistentVolume в виде диска в GCP.

#### PersistentVolumeClaim
Мы создали ресурс дискового хранилища, распространенный на весь кластер, в виде PersistentVolume.

Чтобы выделить приложению часть такого ресурса – нужно создать запрос на выдачу - PersistentVolumeClaim.
Claim - это именно запрос, а не само хранилище.

С помощью запроса можно выделить место как из конкретного PersistentVolume (тогда параметры accessModes и StorageClass должны соответствовать, а места должно хватать), так и просто создать отдельный PersistentVolume под конкретный запрос.

Создадим описание PersistentVolumeClaim (PVC)

При создании PersistentVolumeClaim, Kubernetes попытается найти подходящий PersistentVolume, соответствующий требованиям PVC, и связать их вместе, чтобы приложения могли использовать этот PV для хранения данных. Если подходящего PV не найдено, Kubernetes попытается динамически создать новый PV для PVC.

Для того, чтобы указать конкретный PersistentVolume для PersistentVolumeClaim, необходимо использовать механизм селекторов.
При создании PersistentVolume, можно указать некоторые метки (labels) или аннотации, которые затем можно использовать для выбора подходящих PersistentVolume для PersistentVolumeClaim. Например, можно создать PersistentVolume с меткой storage-class: fast, а затем создать PersistentVolumeClaim, который будет выбирать только PersistentVolume с этой меткой, указав соответствующий селектор в поле spec.selector.matchLabels:
Также чтобы этот способ работал нужно создать соответствующий storageclass и прописать его в манифестах PV и PVC
storageClassName: pdbalanced

Пример  
Создаем SC

storage-balanced.yml
```yaml
---
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: pdbalanced
provisioner: kubernetes.io/gce-pd
reclaimPolicy: Retain
parameters:
  type: pd-standard
  fsType: "ext4"
#  позволяет расширять размер существующих Persistent Volume (PV), связанных с данным StorageClass. 
# Это означает, что если вы создали PVC с некоторым размером и в последствии понадобилось увеличить этот размер, 
# то при наличии этой опции в StorageClass, вы сможете это сделать без необходимости создавать новый PVC.
allowVolumeExpansion: true
# когда PVC запрашивает этот класс хранилища, Kubernetes немедленно связывает созданный PV с запрашивающим PVC. 
# Это может быть полезно, если требуется быстро обеспечить доступ к новому хранилищу
volumeBindingMode: Immediate
```
Создаем PV
mongo-volume.yml
```yaml
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: reddit-mongo-disk
  labels:
    storage-class: pdbalanced
spec:
  capacity:
    storage: 25Gi
  # Том может быть смонтирован в режиме чтения-записи только на одном узле (node) в кластере Kubernetes, в таком режиме только один PVC может быть подключен. 
  accessModes:
    - ReadWriteMany
  # Определяет политику удаления для PersistentVolume
  # Показывает на то, что даже если PersistentVolumeClaim (PVC), который использует этот PV, будет удален, 
  # то сам PV не будет удален автоматически и его содержимое сохранится. Вместо этого PV будет отмечен как 
  # "Released" и будет ожидать дальнейшего действия, такого как повторное использование с помощью другого PVC или удаление вручную.
  persistentVolumeReclaimPolicy: Retain
  storageClassName: pdbalanced
  gcePersistentDisk:
    fsType: "ext4" 
    pdName: "reddit-mongo-disk" # Имя диска в GCE
```

Создаем PVC
mongo-claim.yml
```yaml
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongo-pvc
  namespace: dev
spec:
  storageClassName: pdbalanced
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      # Если объем PV будет больше чем PVC то PVC все равно займет весь имеющийся объем.
      storage: 15Gi
  selector:
    matchLabels:
      storage-class: pdbalanced
```
Но мы не можем так просто использовать один PV для нескольких PVC. Нужно чтобы хранилище поддерживало опцию ReadWriteMany
тандартный Persistent Disk от Google Cloud не поддерживает доступ к нескольким узлам для чтения и записи (ReadWriteMany). Для этого нужно использовать другие решения, такие как Cloud Filestore или различные варианты сетевого хранилища, например, NFS, Ceph, GlusterFS, и т.д.
Для того, чтобы использовать один PV несколькими PVC, необходимо, чтобы PersistentVolume имел атрибут accessModes: ReadWriteMany, а также был создан PersistentVolumeClaim (PVC), который запрашивает этот PV с атрибутом accessModes: ReadWriteMany.


То что было в Лабе
В нашем случаем пишем манифест без селектора
mongo-claim.yml

```yaml
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: mongo-pvc
spec:
  # Том может быть смонтирован в режиме чтения-записи только на одном узле (node) в кластере Kubernetes
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 15Gi
```
Мы выделили место в PV по запросу для нашей базы.
Одновременно использовать один PV можно только по одному Claim’у

Если Claim не найдет по заданным параметрам PV внутри кластера, либо тот будет занят другим Claim’ом то он сам создаст нужный ему PV воспользовавшись стандартным StorageClass

В Kubernetes StorageClass - это объект, который описывает класс хранилища данных для PersistentVolume, т.е. это абстракция, позволяющая администраторам определить различные уровни доступности, скорости, стоимости, резервирования и других характеристик для хранилища данных.

Default StorageClass в Kubernetes - это StorageClass, который используется по умолчанию для динамического создания PersistentVolume при создании PersistentVolumeClaim без явного указания StorageClass.

Когда пользователь создает PVC без указания StorageClass, Kubernetes автоматически ищет Default StorageClass и использует его для создания PV. Если Default StorageClass не определен, пользователю нужно явно указать StorageClass при создании PVC.
Default StorageClass может быть определен в кластере Kubernetes с помощью аннотации storageclass.kubernetes.io/is-default-class: "true" в манифесте StorageClass. Если несколько StorageClass помечены как Default, то будет использоваться только один, определенный последним.

Узнать какой StorageClass установлен в default
```bash 
kubectl get storageclass -n dev
```
```bash 
kubectl describe storageclass standard-rwo -n dev
```

Подключение PVC
Подключим PVC к нашим Pod'ам
mongo-deployment.yml

#### Динамическое выделение Volume'ов

Создав PersistentVolume мы отделили объект "хранилища" от наших Service'ов и Pod'ов. Теперь мы можем его при необходимости переиспользовать.

Но нам гораздо интереснее создавать хранилища при необходимости и в автоматическом режиме. В этом нам помогут StorageClass’ы. Они описывают где (какой провайдер) и какие хранилища создаются.

В нашем случае создадим StorageClass Fast так, чтобы монтировались SSD-диски для работы нашего хранилища.

StorageClass

Создадим описание StorageClass’а
storage-fast.yml
```yaml
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast
# provisioner: kubernetes.io/gce-pd - это параметр, указывающий на используемый провайдер хранилища, который в данном случае является GCE Persistent Disk (GCP PD).
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-ssd # Тип предоставляемого хранилища
```
Добавим StorageClass в кластер
```bash 
kubectl apply -f storage-fast.yml -n dev
```
PVC + StorageClass
Создадим описание PersistentVolumeClaim 

```yaml
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: mongo-pvc-dynamic
spec:
  # Том может быть смонтирован в режиме чтения-записи только на одном узле (node) в кластере Kubernetes
  accessModes:
    - ReadWriteOnce
  # Создаем PersistantVolumeClaim ссылаясь на созданный нами StorageClass storage-fast.yml Вместо ссылки на созданный диск.
  storageClassName: fast
  resources:
    requests:
      storage: 10Gi
```

Добавим StorageClass в кластер
```bash 
$ kubectl apply -f mongo-claim-dynamic.yml -n dev
```

Подключим PVC к нашим Pod'ам
mongo-deployment.yml
```yaml

          claimName: mongo-pvc-dynamic
```

Обновим описание нашего Deployment'а
```bash 
$ kubectl apply -f mongo-deployment.yml -n dev
```
Давайте посмотрит какие в итоге у нас получились
PersistentVolume'ы
```bash
kubectl get persistentvolume -n dev
```

На созданные Kubernetes'ом диски можно посмотреть в web console
https://console.cloud.google.com/compute/disks
