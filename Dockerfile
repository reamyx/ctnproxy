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
        && git clone https://gitee.com/reamyx/etcdbin \
        && chmod +x ./etcdbin/etcd* \
        && \cp -f ./etcdbin/etcdctl /usr/bin \
        \
        && yum clean all \
        && rm -rf ./* /tmp/* \
        && find /srv -name "*.sh" -exec chmod +x {} \;

ENV       ZXDK_THIS_IMG_NAME    "ctnproxy"
ENV       SRVNAME               "proxyline"

# ENTRYPOINT CMD
CMD [ "../imginit/initstart.sh" ]
