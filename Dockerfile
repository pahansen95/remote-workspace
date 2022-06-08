FROM mcr.microsoft.com/vscode/devcontainers/base:ubuntu AS base
SHELL [ "/bin/bash", "-c" ]

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV LANG=en_US.UTF-8
ENV PATH=/home/linuxbrew/.linuxbrew/bin:${PATH}

RUN \
  apt-get update && \
  apt-get install -y \
    curl \
    build-essential \
    ssh

RUN \
  mkdir -p /home/vscode/workspace && \
  chown -R vscode:vscode /home/vscode/workspace

USER vscode

RUN \
  /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && \
  brew --version && \
  brew install \
    gcc \
    git \
    git-lfs \
    helm \
    kubectl \
    docker \
    fish \
    bash \
    emacs

ENV PATH="/home/linuxbrew/.linuxbrew/bin:${PATH}"

COPY --chown=vscode:vscode ./entrypoint.sh /home/vscode/entrypoint.sh
RUN \
  chmod +x /home/vscode/entrypoint.sh && \
  mkdir -p /home/vscode/.sshd /home/vscode/.ssh

WORKDIR /home/vscode

ENTRYPOINT [ "/home/vscode/entrypoint.sh" ]
CMD [ "--log-level", "info" ]