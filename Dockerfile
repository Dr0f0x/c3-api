FROM alpine:3.22 AS builder

RUN apk add --no-cache \
    curl \
    tar \
    ca-certificates \
    build-base

RUN mkdir -p /opt/c3 \
    && curl -L https://github.com/c3lang/c3c/releases/latest/download/c3-linux-static.tar.gz \
    -o /tmp/c3.tar.gz \
    && tar -xzf /tmp/c3.tar.gz -C /opt/c3 --strip-components=1 \
    && rm /tmp/c3.tar.gz

ENV PATH="/opt/c3:$PATH"

WORKDIR /app

# Project configuration
COPY project.json .

# Library sources
COPY src ./src

# Example executable
COPY example ./example

RUN c3c build c3api-demo

FROM alpine:3.22

RUN apk add --no-cache libgcc

WORKDIR /app

COPY --from=builder /app/build/c3api-demo ./c3api-demo
COPY --from=builder /app/example/public ./example/public

EXPOSE 8080

CMD ["./c3api-demo"]