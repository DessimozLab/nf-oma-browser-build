FROM python:3.11-slim as basis

# set environment varibles
#ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

FROM basis as builder
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential \
       libhdf5-103 \
       libhdf5-dev \
       git-core \
       pkg-config \
       libxml2 \
       openssh-client \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -m 700 /root/.ssh/ \
    && touch /root/.ssh/known_hosts \
    && ssh-keyscan -p 2222 lab.dessimoz.org >> /root/.ssh/known_hosts \
    && chmod 600 /root/.ssh/known_hosts

# Tell pipenv to create venv in the current directory
ENV PIPENV_VENV_IN_PROJECT=1

WORKDIR /usr/src
RUN pip install --upgrade pipenv pip
COPY Pipfile Pipfile.lock ./
RUN --mount=type=ssh \
    --mount=type=secret,id=labgit \
    . /run/secrets/labgit && \
    pipenv sync

FROM basis as runtime
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       libxml2 \
       procps \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/src/.venv /usr/src/.venv
ENV PATH="/usr/src/.venv/bin:$PATH"
RUN adduser omabuild
WORKDIR /usr/src
USER omabuild

CMD ["./.venv/bin/python"]