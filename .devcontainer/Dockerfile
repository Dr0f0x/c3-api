FROM mcr.microsoft.com/devcontainers/python:3.14

RUN apt-get update && apt-get install -y \
    curl \
    tar \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /opt/c3 \
    && curl -L https://github.com/c3lang/c3c/releases/latest/download/c3-linux-static.tar.gz \
       -o /tmp/c3.tar.gz \
    && tar -xzf /tmp/c3.tar.gz -C /opt/c3 --strip-components=1 \
    && rm /tmp/c3.tar.gz \
    && curl -L https://github.com/codesenberg/bombardier/releases/latest/download/bombardier-linux-amd64 \
       -o /usr/local/bin/bombardier \
    && chmod +x /usr/local/bin/bombardier

ENV PATH="/opt/c3:$PATH"

RUN echo 'export PATH="/opt/c3:$PATH"' >> /home/vscode/.bashrc