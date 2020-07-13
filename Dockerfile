FROM docker:latest AS docker
FROM python:3.8-alpine AS build

ARG COMPOSE_VERSION=1.26.2

COPY --from=docker /usr/local/bin/docker \
                   /usr/local/bin/docker

RUN apk add --no-cache \
        bash \
        build-base \
        ca-certificates \
        curl \
        gcc \
        git \
        libc-dev \
        libffi-dev \
        libgcc \
        make \
        musl-dev \
        openssl \
        openssl-dev \
        zlib-dev \
 && git clone https://github.com/docker/compose.git \
 && cd compose \
 && git checkout "${COMPOSE_VERSION}" \
 && pip install virtualenv==16.2.0 \
 && pip install tox==2.9.1 \
 && PY_ARG=$(python -V | awk '{print $2}' | awk 'BEGIN{FS=OFS="."} NF--' | sed 's|\.||g' | sed 's|^|py|g') \
 && sed -i "s|envlist = .*|envlist = ${PY_ARG},pre-commit|g" tox.ini \
 && tox --notest \
 && mkdir -p dist \
 && chmod 777 dist \
 && .tox/${PY_ARG}/bin/pip install -q -r requirements-build.txt \
 && script/build/write-git-sha > compose/GITSHA \
 && export SRC_PATH="$(pwd)" \
 && export PATH="/compose/pyinstaller:${PATH}" \
 && git clone --single-branch --branch develop https://github.com/pyinstaller/pyinstaller.git /tmp/pyinstaller \
 && cd /tmp/pyinstaller/bootloader \
 && git checkout v$("${SRC_PATH}"/.tox/${PY_ARG}/bin/python -c 'import PyInstaller; print(PyInstaller.__version__)') \
 && "${SRC_PATH}"/.tox/${PY_ARG}/bin/python ./waf configure --no-lsb all \
 && "${SRC_PATH}"/.tox/${PY_ARG}/bin/pip install .. \
 && cd "${SRC_PATH}" \
 && rm -Rf /tmp/pyinstaller \
 && .tox/${PY_ARG}/bin/pyinstaller --exclude-module pycrypto --exclude-module PyInstaller docker-compose.spec \
 && ls -la dist/ \
 && ldd dist/docker-compose \
 && mv dist/docker-compose /usr/local/bin \
 && docker-compose version


FROM alpine:latest

LABEL maintainer="Saswat Padhi saswat.sourav@gmail.com"

COPY --from=docker /usr/local/bin/docker \
                   /usr/local/bin/docker
COPY --from=build /compose/docker-compose-entrypoint.sh \
                  /usr/local/bin/docker-compose-entrypoint.sh
COPY --from=build /usr/local/bin/docker-compose \
                  /usr/local/bin/docker-compose

ENTRYPOINT ["sh", "/usr/local/bin/docker-compose-entrypoint.sh"]
