FROM python:3.11-slim AS basis

# set environment varibles
ENV PYTHONUNBUFFERED=1

FROM basis AS builder
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential \
       libhdf5-310 \
       libhdf5-dev \
       git-core \
       pkg-config \
       openssh-client \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -m 700 /root/.ssh/ \
    && touch /root/.ssh/known_hosts \
    && ssh-keyscan -p 2222 lab.dessimoz.org >> /root/.ssh/known_hosts \
    && chmod 600 /root/.ssh/known_hosts

RUN mkdir -p /usr/src
WORKDIR /usr/src

RUN --mount=type=ssh \
    --mount=type=secret,id=labgit \
    export LABGIT="$(cat /run/secrets/labgit )" \
    && git clone ${LABGIT}/biosoda

RUN python3 -m venv /opt/venv  \
    && . /opt/venv/bin/activate \
    && pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r /usr/src/biosoda/requirements.txt 

FROM basis AS runtime
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       libhdf5-310 \
       libhdf5-dev \
       procps \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /usr/biosoda

COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /usr/src/biosoda/*owl /usr/biosoda/
COPY --from=builder /usr/src/biosoda/OMAHDF5ToRDF.py /usr/bin/OMAHDF5ToRDF
RUN sed -i 's|#!/usr/bin/env python3|#!/opt/venv/bin/python3|' /usr/bin/OMAHDF5ToRDF \
    && chmod +x /usr/bin/OMAHDF5ToRDF

CMD ["/usr/bin/OMAHDF5ToRDF"]




    
