FROM debian:12-slim AS build

ARG LIBTORRENT_VERSION="0.13.8"
ARG LIBTORRENT_HASH="ed115a28f4ae8cfcd33b94a597c076ca74fd549867a26e4fac9505c27288e983"
ARG LIBTORRENT_URL="https://github.com/rakshasa/rtorrent-archive/raw/master/libtorrent-${LIBTORRENT_VERSION}.tar.gz"

ARG RTORRENT_VERSION="0.9.8"
ARG RTORRENT_HASH="9edf0304bf142215d3bc85a0771446b6a72d0ad8218efbe184b41e4c9c7542af"
ARG RTORRENT_URL="https://github.com/rakshasa/rtorrent-archive/raw/master/rtorrent-${RTORRENT_VERSION}.tar.gz"

RUN apt-get update && \
    apt-get install -y \
        build-essential \
        curl \
        libcurl4-openssl-dev \
        libncursesw5-dev \
        libssl-dev \
        pkg-config \
        zlib1g-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN curl -s -o "/tmp/libtorrent-${LIBTORRENT_VERSION}.tar.gz" -L "$LIBTORRENT_URL" && \
    FILE_HASH="$(sha256sum /tmp/libtorrent-${LIBTORRENT_VERSION}.tar.gz | cut -d' ' -f1)" && \
    echo hey; \
    du -sh "/tmp/libtorrent-${LIBTORRENT_VERSION}.tar.gz"; \
    if [ ! "$LIBTORRENT_HASH" = "$FILE_HASH" ]; then \
        echo "SHA256 verification failed!" && \
        echo -e "EXPECTED:\t$LIBTORRENT_HASH" && \
        echo -e "ACTUAL:\t$FILE_HASH" && \
        exit 1; \
    fi && \
    tar -xzvf "/tmp/libtorrent-${LIBTORRENT_VERSION}.tar.gz" -C /tmp/ && \
    rm -rf "/tmp/libtorrent-${LIBTORRENT_VERSION}.tar.gz"

WORKDIR "/tmp/libtorrent-${LIBTORRENT_VERSION}"

RUN ./configure && \
    make && \
    make install

RUN curl -s -o "/tmp/rtorrent-${RTORRENT_VERSION}.tar.gz" -L "$RTORRENT_URL" && \
    FILE_HASH="$(sha256sum /tmp/rtorrent-${RTORRENT_VERSION}.tar.gz | cut -d' ' -f1)" && \
    if [ ! "$RTORRENT_HASH" = "$FILE_HASH" ]; then \
        echo "SHA256 verification failed!" && \
        echo -e "EXPECTED:\t$RTORRENT_HASH" && \
        echo -e "ACTUAL:\t$FILE_HASH" && \
        exit 1; \
    fi && \
    tar -xzvf "/tmp/rtorrent-${RTORRENT_VERSION}.tar.gz" -C /tmp/ && \
    rm -rf "/tmp/rtorrent-${RTORRENT_VERSION}.tar.gz"

WORKDIR "/tmp/rtorrent-${RTORRENT_VERSION}"

RUN ./configure && \
    make && \
    make install

RUN curl -s -L "https://raw.githubusercontent.com/wiki/rakshasa/rtorrent/CONFIG-Template.md" \
        | sed -ne "/^######/,/^### END/p" \
        | sed -re "s:/home/USERNAME:/home/rtorrent:" > /tmp/rtorrent.rc.template

FROM debian:12-slim AS runtime

COPY --from=build /usr/local/lib/libtorrent.so* /usr/local/lib/
COPY --from=build /usr/local/bin/rtorrent /usr/local/bin/
COPY --from=build /tmp/rtorrent.rc.template /tmp/rtorrent.rc.template

RUN apt-get update && \
    apt-get install -y \
        libcurl4 \
        libncursesw6 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]
