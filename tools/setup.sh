#!/usr/bin/env bash

BASEDIR=$(dirname $(dirname $(dirname "$0")))

fetch_docker_repos() {
    mkdir -p ${BASEDIR}/repos
    if [[ ! -d ${BASEDIR}"/repos/apisix-docker" ]]; then
        git clone https://github.com/apache/apisix-docker.git ${BASEDIR}/repos/apisix-docker --depth=1
    fi

    if [[ ! -d ${BASEDIR}"/repos/kong-docker" ]]; then
        git clone https://github.com/Kong/docker-kong.git ${BASEDIR}/repos/kong-docker --depth=1
    fi
}

setup_with_docker_compose() {
    fetch_docker_repos

    docker ps > /dev/null
    if [ $? -ne 0 ]; then
        echo "docker not working"
        exit 1
    fi

    retries=10
    if [ $(curl -k -i -m 20 -o /dev/null -s -w %{http_code} http://localhost:9080) -eq 404 ]; then
        echo "apisix work as expected"
    else
        docker-compose -f ${BASEDIR}/repos/apisix-docker/example/docker-compose.yml up -d
        count=0
        while [ $(curl -k -i -m 20 -o /dev/null -s -w %{http_code} http://localhost:9080) -ne 404 ];
        do
            echo "Waiting for apisix setup" && sleep 1;

            ((count=count+1))
            if [ $count -gt ${retries} ]; then
                printf "apisix not work as expected\n"
                exit 1
            fi
        done
        echo "apisix work as expected"
    fi

    if [ $(curl -k -i -m 20 -o /dev/null -s -w %{http_code} http://localhost:8001) -eq 200 ]; then
        echo "kong work as expected"
    else
        docker-compose -f ${BASEDIR}/repos/kong-docker/compose/docker-compose.yml up -d
        count=0
        while [ $(curl -k -i -m 20 -o /dev/null -s -w %{http_code} http://localhost:8001) -ne 200 ];
        do
            echo "Waiting for kong setup" && sleep 1;

            ((count=count+1))
            if [ $count -gt ${retries} ]; then
                printf "kong not work as expected\n"
                exit 1
            fi
        done
        echo "kong work as expected"
    fi

    if ! docker ps --format '{{.Names}}' | grep -w httpbin &> /dev/null; then
        docker run --name httpbin -d -p 8088:80 kennethreitz/httpbin
    else
        echo "upstream work as expected"
    fi
}

setup_with_docker_compose
