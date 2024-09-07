FROM docker.io/golang:1.22-alpine3.19 AS builder

WORKDIR /src
RUN set -eu;\
    apk update; \
    apk add --no-cache git make bash build-base linux-headers; \
    git clone --depth 1 --branch master https://github.com/amnezia-vpn/amneziawg-go.git; \
    git clone --depth 1 --branch master https://github.com/amnezia-vpn/amneziawg-tools.git

WORKDIR /src/amneziawg-go
RUN go build -ldflags '-linkmode external -extldflags "-fno-PIC -static"' -v -o /usr/bin

WORKDIR /src/amneziawg-tools/src
RUN make

FROM docker.io/alpine:3.19

COPY --from=builder /usr/bin/amneziawg-go /usr/bin/amneziawg-go
COPY --from=builder /src/amneziawg-tools/src/wg /usr/bin/awg
COPY --from=builder /src/amneziawg-tools/src/wg-quick/linux.bash /usr/bin/awg-quick
COPY src/rt_tables /etc/iproute2/rt_tables
COPY src/awg-start /usr/bin/awg-start

RUN set -eu;\
    apk update; \
    apk add --no-cache bash iptables iptables-legacy iproute2; \
    sed -i 's/^\(tty\d\:\:\)/#\1/' /etc/inittab; \
    rm -f /etc/init.d/hwdrivers /etc/init.d/machine-id || :; \
    sed -i 's/cmd sysctl -q \(.*\?\)=\(.*\)/[[ "$(sysctl -n \1)" != "\2" ]] \&\& \0/' /usr/bin/awg-quick; \
    chmod +x /usr/bin/amneziawg-go /usr/bin/awg /usr/bin/awg-quick /usr/bin/awg-start; \
    ln -s /sbin/iptables-legacy /bin/iptables; \
    ln -s /sbin/iptables-legacy-save /bin/iptables-save; \
    ln -s /sbin/iptables-legacy-restore /bin/iptables-restore; \
    ln -s /usr/bin/awg /usr/bin/wg; \
    ln -s /usr/bin/awg-quick /usr/bin/wg-quick

VOLUME ["/sys/fs/cgroup"]

ENTRYPOINT ["/usr/bin/awg-start"]
