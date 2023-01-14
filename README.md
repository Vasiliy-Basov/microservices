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
