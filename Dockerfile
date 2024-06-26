# FROM registry.access.redhat.com/ubi9/ubi-init:9.4
# FROM debian:bookworm-slim as docker_install
FROM ubuntu:latest as docker_install

# Add Docker's official GPG key:
RUN apt-get update \
    && apt-get install -y ca-certificates curl \
    && install -m 0755 -d /etc/apt/keyrings \
    # && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
RUN echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN apt-get update && apt-get install -y docker-ce-cli

# FROM debian:bookworm-slim
FROM ubuntu:latest

# Arguments
ARG TARGETPLATFORM

# https://github.com/actions/runner/releases
ARG RUNNER_VERSION=2.317.0

# https://github.com/actions/runner-container-hooks/releases
ARG RUNNER_CONTAINER_HOOKS_VERSION=0.6.1

# Shell setup
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# The UID env var should be used in child Containerfile.
ENV UID=1000
ENV GID=0
ENV USERNAME="runner"
ENV DOCKER_GROUP_GID=123

# # Install software
# RUN dnf update -y
# RUN dnf install dnf-plugins-core -y \
#     && dnf install -y \
#     git \
#     krb5-libs \
#     libicu \
#     libyaml-devel \
#     lttng-ust \
#     openssl-libs \
#     passwd \
#     rpm-build \
#     vim \
#     wget \
#     yum-utils \
#     zlib

COPY --from=docker_install /usr/bin/docker /usr/bin/docker

RUN apt-get update \
    && apt-get install -y curl unzip

# RUN dnf remove -y docker \
#     docker-client \
#     docker-client-latest \
#     docker-common \
#     docker-latest \
#     docker-latest-logrotate \
#     docker-logrotate \
#     docker-engine \
#     podman \
#     runc

# RUN yum-config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo

# RUN dnf install -y docker-ce-cli docker-buildx-plugin

# RUN dnf clean all

# # RUN systemctl enable docker.service containerd.service

# This is to mimic the OpenShift behaviour of adding the dynamic user to group 0.
RUN useradd -G ${GID} ${USERNAME}
RUN groupadd -g ${DOCKER_GROUP_GID} dind && usermod -aG ${DOCKER_GROUP_GID} $USERNAME
# RUN usermod -aG docker $USERNAME
ENV HOME=/home/${USERNAME}

# Make and set the working directory
RUN mkdir -p /home/runner \
    && chown -R $USERNAME:$GID /home/runner

WORKDIR /home/runner

# # Install GitHub CLI
# # COPY images/software/gh-cli.sh gh-cli.sh
# # RUN bash gh-cli.sh && rm gh-cli.sh

# # # Install kubectl
# # COPY images/software/kubectl.sh kubectl.sh
# # RUN bash kubectl.sh && rm kubectl.sh

# # Install helm
# # RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

RUN test -n "$TARGETPLATFORM" || (echo "TARGETPLATFORM must be set" && false)

# Runner download supports amd64 as x64
RUN export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && if [ "$ARCH" = "amd64" ]; then export ARCH=x64 ; fi \
    && curl -L -o runner.tar.gz https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${ARCH}-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./runner.tar.gz \
    && rm runner.tar.gz \
    && ./bin/installdependencies.sh

# Install container hooks
RUN curl -f -L -o runner-container-hooks.zip https://github.com/actions/runner-container-hooks/releases/download/v${RUNNER_CONTAINER_HOOKS_VERSION}/actions-runner-hooks-k8s-${RUNNER_CONTAINER_HOOKS_VERSION}.zip \
    && unzip ./runner-container-hooks.zip -d ./k8s \
    && rm runner-container-hooks.zip


# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

USER $USERNAME
