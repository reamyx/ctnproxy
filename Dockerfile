#官方centos7镜像初始化,镜像TAG: ctnproxy

FROM        imginit
LABEL       function="ctnproxy"

#添加本地资源
ADD     proxyline     /srv/proxyline/
ADD     proxylog      /srv/proxylog/
ADD     proxypoptop   /srv/proxypoptop/
ADD     proxyxl2tpd   /srv/proxyxl2tpd/
ADD     proxydante3   /srv/proxydante3/

WORKDIR /srv/proxyline

#功能软件包
RUN     set -x \
        && cd ../imginit \
        && mkdir -p installtmp \
        && cd installtmp \
        \
        && yum -y install pptpd xl2tpd strongswan mariadb \
        && yum -y install gcc make automake \
        \
        && curl -L https://github.com/etcd-io/etcd/releases/download/v3.3.12/etcd-v3.3.12-linux-amd64.tar.gz \
           -o etcd-v3.3.12-linux-amd64.tar.gz \
        && tar -zxvf etcd-v3.3.12-linux-amd64.tar.gz \
        && cd etcd-v3.3.12-linux-amd64 \
        && \cp -f etcdctl /usr/bin \
        && cd - \
        \
        && curl https://codeload.github.com/reamyx/dante-zxmd/zip/master -o dante-zxmd.zip \
        && unzip dante-zxmd.zip \
        && cd dante-zxmd-master \
        && ./configure --without-gssapi --without-krb5 \
        && make \
        && make install \
        && cd - \
        \
        && cd ../ \ 
        && yum -y history undo last \
        && yum clean all \
        && rm -rf installtmp /tmp/* \
        && find ../ -name "*.sh" -exec chmod +x {} \;

ENV       ZXDK_THIS_IMG_NAME    "ctnproxy"
ENV       SRVNAME               "proxyline"

# ENTRYPOINT CMD
CMD [ "../imginit/initstart.sh" ]
