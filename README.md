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
