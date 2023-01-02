FROM debian:buster-slim AS build
MAINTAINER Lakshmipathi.G

ARG BTRFS_PROGS_VERSION
ENV BTRFS_PROGS_VERSION=${BTRFS_PROGS_VERSION:-v5.6.1}

# Install needed dependencies.
RUN apt-get update && apt-get install -y --no-install-recommends git autoconf automake gcc \
    make pkg-config e2fslibs-dev libblkid-dev zlib1g-dev liblzo2-dev libzstd-dev \
    libsqlite3-dev python3-dev python3-pip python3-setuptools patch gfortran

# Clone the repo
RUN git clone --depth=1 https://github.com/Lakshmipathi/dduper.git && \
    git clone --depth=1 -b $BTRFS_PROGS_VERSION https://github.com/kdave/btrfs-progs.git

# Apply csum patch
WORKDIR /btrfs-progs
RUN patch -p1 < /dduper/patch/btrfs-progs-${BTRFS_PROGS_VERSION}/0001-Print-csum-for-a-given-file-on-stdout.patch

# Start the btrfs-progs build
RUN ./autogen.sh
RUN ./configure --disable-documentation
RUN make install DESTDIR=/btrfs-progs-build

# Start the btrfs-progs static build
RUN make clean
RUN make static
RUN make btrfs.static
RUN cp btrfs.static /btrfs-progs-build

RUN cp -rv /btrfs-progs-build/usr/local/bin/* /usr/local/bin && \
    cp -rv /btrfs-progs-build/usr/local/include/* /usr/local/include/ && \
    cp -rv /btrfs-progs-build/usr/local/lib/* /usr/local/lib
RUN btrfs inspect-internal dump-csum --help
WORKDIR /dduper
RUN pip3 install wheel -i https://mirrors.aliyun.com/pypi/simple/ && \
    pip3 install -r requirements.txt -i https://mirrors.aliyun.com/pypi/simple/ && \
    cp -v dduper /usr/sbin/
RUN dduper --version 

# Install dduper
FROM debian:buster-slim

ARG ARCH_VERSION
ENV ARCH_VERSION=${ARCH_VERSION:-aarch64}

RUN apt-get update && apt-get install -y --no-install-recommends python3

COPY --from=build /lib/${ARCH_VERSION}-linux-gnu/liblzo2.so.2 /lib/${ARCH_VERSION}-linux-gnu/
COPY --from=build /usr/local/lib/python3.7/dist-packages /usr/local/lib/python3.7/dist-packages
COPY --from=build /usr/sbin/dduper /usr/sbin/dduper
COPY --from=build /btrfs-progs-build /btrfs-progs 

RUN mv /btrfs-progs/btrfs.static / && \
    cp -rv /btrfs-progs/usr/local/bin/* /usr/local/bin && \
    cp -rv /btrfs-progs/usr/local/include/* /usr/local/include/ && \
    cp -rv /btrfs-progs/usr/local/lib/* /usr/local/lib && \
    btrfs inspect-internal dump-csum --help && \
    dduper --version
WORKDIR /dduper
