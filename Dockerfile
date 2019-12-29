#官方centos7镜像初始化,镜像TAG: ctnproxy

FROM        imginit
LABEL       function="ctnproxy"

#添加本地资源
ADD     proxyline       /srv/proxyline/
ADD     proxylog        /srv/proxylog/
ADD     poptop          /srv/poptop/
ADD     xl2tpd          /srv/xl2tpd/
ADD     openvpn         /srv/openvpn/
ADD     3proxy          /srv/3proxy/

WORKDIR /srv/proxyline

#功能软件包
RUN     set -x && cd && rm -rf * \
        \
        && yum -y install pptpd xl2tpd openvpn 3proxy mariadb \
        \
        && curl -L https://github.com/etcd-io/etcd/releases/download/v3.3.18/etcd-v3.3.18-linux-amd64.tar.gz \
           -o etcd-v3.3.18-linux-amd64.tar.gz \
        && tar -zxvf etcd-v3.3.18-linux-amd64.tar.gz \
        && cd etcd-v3.3.18-linux-amd64 \
        && \cp -f etcdctl /usr/bin \
        && cd \
        \
        && yum clean all \
        && rm -rf ./* /tmp/* \
        && find /srv -name "*.sh" -exec chmod +x {} \;

ENV       ZXDK_THIS_IMG_NAME    "ctnproxy"
ENV       SRVNAME               "proxyline"

# ENTRYPOINT CMD
CMD [ "../imginit/initstart.sh" ]
