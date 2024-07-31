FROM cbrg/darwin:latest as builder

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       git-core \
       openssh-client \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -m 700 /root/.ssh/ \
    && touch /root/.ssh/known_hosts \
    && ssh-keyscan -p 2222 lab.dessimoz.org >> /root/.ssh/known_hosts \
    && chmod 600 /root/.ssh/known_hosts

WORKDIR /src
RUN --mount=type=ssh \
    --mount=type=secret,id=labgit \
    LABGIT=$(cat /run/secrets/labgit) && \
    git clone ${LABGIT}/OMA && \
    git clone ${LABGIT}/browser && \
    git clone -b nf-convert ${LABGIT}/pyoma && \
    rm -rf OMA/.git browser/.git pyoma/.git

FROM cbrg/darwin:latest as runtime

COPY --from=builder /src /src
ENV DARWIN_OMA_REPO_PATH="/src/OMA"
ENV DARWIN_BROWSER_REPO_PATH="/src/browser"
ENV CODE_REPOS_ROOT="/src"

