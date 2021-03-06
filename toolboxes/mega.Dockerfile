# syntax = docker/dockerfile:1.0.2-experimental
# help: a generic toolbox for talos. you can (and should) roll your own

###############################################################################
## base image - core installs
###############################################################################
FROM debian:buster-slim AS base
LABEL MAINTAINER "Peter McConnell <me@petermcconnell.com>"
SHELL ["/bin/bash", "-eo", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN DEBIAN_FRONTEND=noninteractive \
    apt-get update -y && \
    apt-get install --no-install-recommends -yq \
      ca-certificates \
      gnupg2 && \
    echo deb http://ppa.launchpad.net/apt-fast/stable/ubuntu bionic main >> /etc/apt/sources.list.d/apt-fast.list && \
    echo deb-src http://ppa.launchpad.net/apt-fast/stable/ubuntu bionic main >> /etc/apt/sources.list.d/apt-fast.list && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys A2166B8DE8BDC3367D1901C11EE2FF37CA8DA16B && \
    apt-get update -y && \
    apt-get install --no-install-recommends -yq \
      apt-fast && \
    apt-get clean && \
    apt-fast install --no-install-recommends -yq \
      build-essential \
      python3-dev \
      python3-pip \
      python3-setuptools \
      curl \
      tree \
      git \
      make \
      zip \
      unzip \
      zlib1g-dev \
      telnet \
      vim \
      yamllint \
      shellcheck && \
    apt-fast clean && \
    rm -rf /var/lib/apt/lists/*

###############################################################################
## pyenv incase we need it (just a convenience)
###############################################################################
FROM base AS pyenv
RUN git clone https://github.com/pyenv/pyenv.git ~/.pyenv

###############################################################################
## some base python pip installs
###############################################################################
FROM base AS pips
RUN pip3 install --user \
      radon==4.1.0 \
      bandit==1.6.2 \
      pipenv==2020.6.2 \
      flake8==3.8.3 \
      pylint==2.5.3 \
      black==19.10b0 \
      pytest==5.4.3 \
      pytest-html==2.1.1 \
      pytest-xdist==1.32.0 \
      pytest-cov==2.10.0 \
      cfn-lint==0.33.2 \
      sqlfluff==0.3.4

###############################################################################
## hadolint for dockerfile linting
###############################################################################
FROM base AS hadolint
RUN curl -L https://github.com/hadolint/hadolint/releases/download/v1.18.0/hadolint-Linux-x86_64 -o /usr/bin/hadolint && \
    chmod +x /usr/bin/hadolint

###############################################################################
## terraform linter
###############################################################################
FROM base AS tflint
RUN curl -L https://github.com/terraform-linters/tflint/releases/download/v0.17.0/tflint_darwin_amd64.zip -o tflint_darwin_amd64.zip && \
    unzip tflint_darwin_amd64.zip && \
    install tflint /usr/local/bin

###############################################################################
## BATS
###############################################################################
FROM base AS bats
RUN git clone https://github.com/bats-core/bats-core.git && \
    ./bats-core/install.sh /usr/local

###############################################################################
## Docker
###############################################################################
FROM base AS docker
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - && \
    apt-key fingerprint 0EBFCD88 && \
    echo "deb [arch=amd64] https://download.docker.com/linux/debian buster stable" >> /etc/apt/sources.list.d/docker.list && \
    apt-get update -y && \
    apt-get install -yq --no-install-recommends docker-ce-cli=5:19.03.12~3-0~debian-buster && \
    curl -L "https://github.com/docker/compose/releases/download/1.26.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && \
    chmod +x /usr/local/bin/docker-compose

###############################################################################
## Golang
###############################################################################
FROM base AS golang
RUN curl -L https://golang.org/dl/go1.14.4.linux-amd64.tar.gz -o golang.tar.gz && \
    tar -C /usr/local -xzf golang.tar.gz && \
    /usr/local/go/bin/go get -u golang.org/x/lint/golint && \
    /usr/local/go/bin/go get -u github.com/securego/gosec/cmd/gosec

###############################################################################
## our published image
###############################################################################
FROM base AS final
COPY  --from=pyenv /root/.pyenv /root/.pyenv
ENV PYENV_ROOT=/root/.pyenv
ENV PATH=$PATH:/root/.pyenv/bin/:/root/.local/bin:/usr/local/go/bin/:/root/go/bin
ENV LANG=en-US
RUN printf "if command -v pyenv 1>/dev/null 2>&1; then\n  eval \"\$(pyenv init -)\"\nfi" >> ~/.bash_profile
COPY --from=pips /root/.local/ /root/.local/
COPY --from=hadolint /usr/bin/hadolint /usr/bin/hadolint
COPY --from=tflint /usr/local/bin/tflint /usr/local/bih/tflint
COPY --from=bats /usr/local/bin/bats /usr/local/bin/bats
COPY --from=bats /usr/local/lib/bats-core /usr/local/lib/bats-core
COPY --from=bats /usr/local/libexec/bats-core /usr/local/libexec/bats-core
COPY --from=docker /usr/bin/docker /usr/bin/docker
COPY --from=docker /usr/local/bin/docker-compose /usr/local/bin/docker-compose
COPY --from=golang /usr/local/go /usr/local/go
COPY --from=golang /root/go/bin /root/go/bin
COPY . /etc/talos/
RUN ln -sf /etc/talos/talos.sh /usr/local/bin/talos
