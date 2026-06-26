FROM alpine:edge

# Install L2TP server, amnezia wireguard, and routing tools
RUN apk add --no-cache \
    iptables \
    iproute2 \
    xl2tpd \
    amneziawg-tools \
    amneziawg-go \
    bash \
    --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing/ \
    --repository=http://dl-cdn.alpinelinux.org/alpine/edge/main/ \
    --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community/

COPY xl2tpd.conf /etc/xl2tpd/xl2tpd.conf
COPY options.xl2tpd /etc/ppp/options.xl2tpd
COPY chap-secrets /etc/ppp/chap-secrets
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# L2TP UDP port
EXPOSE 1701/udp

ENTRYPOINT ["/entrypoint.sh"]
