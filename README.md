### 项目名称 ctnproxy

#### 项目说明
    构建容器镜像用于在PPPOE拨号环境中快速启动一个socks5或pptpvpn或l2tpvpn代理线路
    
    镜像内包含日志收集服务proxylog.
    
    现有设计的认证,状态注册及日志推送均基于etcd服务(v2)实现.
    
#### 启动方法
    参考基础镜像imginit的说明文档.
