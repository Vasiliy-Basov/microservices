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






