FROM centos:8 as builder

# Fluent Bit version
ENV FLB_MAJOR 1
ENV FLB_MINOR 5
ENV FLB_PATCH 2
ENV FLB_VERSION 1.5.2

RUN packages="gcc-c++ \
    curl \
    ca-certificates \
    cmake \
    make \
    tar \
    openssl-devel \
    cyrus-sasl-devel \
    systemd-devel \
    zlib-devel \
    libpq-devel \
    flex \
    bison" && \
    yum install -y --setopt=tsflags=nodocs ${packages} && \
    rpm -V ${packages} && \
    yum clean all

RUN mkdir -p /fluent-bit/bin /fluent-bit/etc /fluent-bit/log /tmp/src/
COPY . /tmp/src/
RUN rm -rf /tmp/src/build/*

WORKDIR /tmp/src/build/
RUN cmake -DFLB_DEBUG=Off \
          -DFLB_TRACE=Off \
          -DFLB_JEMALLOC=On \
          -DFLB_TLS=On \
          -DFLB_SHARED_LIB=Off \
          -DFLB_EXAMPLES=Off \
          -DFLB_HTTP_SERVER=On \
          -DFLB_IN_SYSTEMD=On \
          -DFLB_OUT_KAFKA=On \
          -DFLB_OUT_PGSQL=On ../

RUN make -j $(getconf _NPROCESSORS_ONLN)
RUN mkdir -p /etc/fluent-bit && \
    mkdir -p /var/log/fluent-bit

# Configuration files
COPY conf/fluent-bit.conf \
     conf/parsers.conf \
     conf/parsers_ambassador.conf \
     conf/parsers_java.conf \
     conf/parsers_extra.conf \
     conf/parsers_openstack.conf \
     conf/parsers_cinder.conf \
     conf/plugins.conf \
     /etc/fluent-bit

FROM centos:8 
LABEL maintainer="OpenShift Logging <aos-logging@redhat.com>"
LABEL Description="Fluent Bit docker image" Vendor="Fluent Organization" Version="1.1"

COPY --from=builder /usr/lib64/*sasl* /usr/lib64/
COPY --from=builder /usr/lib64/libz* /usr/lib64/
#COPY --from=builder /lib64/libz* /lib64/
COPY --from=builder /usr/lib64/libssl.so* /usr/lib64/
COPY --from=builder /usr/lib64/libcrypto.so* /usr/lib64/

# These below are all needed for systemd
COPY --from=builder /lib64/libsystemd* /lib64/
COPY --from=builder /lib64/libselinux.so* /lib64/
COPY --from=builder /lib64/liblzma.so* /lib64/
COPY --from=builder /usr/lib64/liblz4.so* /usr/lib64/
COPY --from=builder /lib64/libgcrypt.so* /lib64/
COPY --from=builder /lib64/libpcre.so* /lib64/
COPY --from=builder /lib64/libgpg-error.so* /lib64/

# PostgreSQL output plugin
COPY --from=builder /usr/lib64/libpq.so* /usr/lib64/
COPY --from=builder /usr/lib64/libgssapi* /usr/lib64/
COPY --from=builder /usr/lib64/libldap* /usr/lib64/
COPY --from=builder /usr/lib64/libkrb* /usr/lib64/
COPY --from=builder /usr/lib64/libk5crypto* /usr/lib64/
COPY --from=builder /usr/lib64/liblber* /usr/lib64/
COPY --from=builder /usr/lib64/libgnutls* /usr/lib64/
COPY --from=builder /usr/lib64/libp11-kit* /usr/lib64/
COPY --from=builder /usr/lib64/libidn2* /usr/lib64/
COPY --from=builder /usr/lib64/libunistring* /usr/lib64/
COPY --from=builder /usr/lib64/libtasn1* /usr/lib64/
COPY --from=builder /usr/lib64/libnettle* /usr/lib64/
COPY --from=builder /usr/lib64/libhogweed* /usr/lib64/
COPY --from=builder /usr/lib64/libgmp* /usr/lib64/
COPY --from=builder /usr/lib64/libffi* /usr/lib64/
COPY --from=builder /lib64/libcom_err* /lib64/
COPY --from=builder /lib64/libkeyutils* /lib64/

COPY --from=builder /tmp/src/build/bin/* /usr/bin/

#
EXPOSE 2020

# Entry point
CMD ["/usr/bin/fluent-bit", "-c", "/etc/fluent-bit/fluent-bit.conf"]
