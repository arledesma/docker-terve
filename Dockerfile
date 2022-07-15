# syntax=docker.io/docker/dockerfile:1.4
ARG BASE=jammy
FROM ubuntu:${BASE} as base

SHELL ["/bin/bash", "-eo", "pipefail", "-x", "-c"]

ENV \
  HOME=/opt/terve \
  USER=terve
RUN <<HEREDOC
  useradd -r -d "$HOME" -m -s /sbin/nologin -c "${USER} user" "${USER}"
  chown -R "${USER}:" "$HOME"
HEREDOC

WORKDIR $HOME
ARG DEBIAN_FRONTEND=noninteractive
RUN <<HEREDOC
  apt-get update
  apt-get install -y --no-install-recommends \
    "curl=7.*" \
    "ca-certificates=20*"

  apt-get clean
  rm -rf /var/lib/apt/lists/*
HEREDOC

# install terve
ARG TARGETARCH
ARG \
  TERVE_VERSION=v0.8.0
RUN <<HEREDOC
  curl -fsL https://github.com/superblk/terve/releases/download/${TERVE_VERSION}/terve_linux_${TARGETARCH} -o /usr/bin/terve
  chmod 0755 /usr/bin/terve
  terve --bootstrap
  chown -R "${USER}:" "${HOME}/.terve"
HEREDOC

USER terve
ENV PATH="$HOME/.terve/bin:$PATH"

RUN <<HEREDOC
  terve list tg remote | tee terragrunt.versions
  terve list tf remote | tee terraform.versions
HEREDOC

# end base stage

# test stage
FROM base as test

# Install terve and terragrunt
ARG TARGETARCH
ARG \
  TERRAGRUNT_VERSION=0.36.10 \
  TERRAFORM_VERSION=1.2.5

ENV PATH="$HOME/.terve/bin:$PATH"
# install and validate terragrunt
RUN <<HEREDOC
  terve install tg "${TERRAGRUNT_VERSION}"
  terve select tg "${TERRAGRUNT_VERSION}"
  terragrunt -version
HEREDOC

# install and validate terraform
RUN <<HEREDOC
  terve install tf "${TERRAFORM_VERSION}"
  terve select tf "${TERRAFORM_VERSION}"
  terraform -version
HEREDOC
