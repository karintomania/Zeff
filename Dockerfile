FROM --platform=linux/amd64  ubuntu:24.04 AS install_zig

RUN apt-get update && apt-get -y install curl xz-utils
RUN curl -LO https://ziglang.org/download/0.14.1/zig-x86_64-linux-0.14.1.tar.xz && \
    tar xf zig-x86_64-linux-0.14.1.tar.xz && \
    mv zig-x86_64-linux-0.14.1/zig zig-x86_64-linux-0.14.1/lib/ usr/local/bin/

FROM --platform=linux/amd64 ubuntu:24.04
RUN apt-get update && apt-get -y install \
    libncurses5-dev \
    libncursesw5-dev \
    libtinfo6 \
    libtinfo-dev \
    build-essential

COPY --from=install_zig /usr/local/bin/ /usr/local/bin/
WORKDIR /app
