# Скрипт для сборки докер контейнеров с помощью скриптов docker_build.sh
export USER_NAME=vasiliybasov
for i in ui post-py comment; do
 cd src/$i;
 bash docker_build.sh;
 cd -;
done
