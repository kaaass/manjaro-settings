#
# 透明代理配置 v1
# Author: KAAAsS
#

#---------
# 参数配置
#---------

lo_fwmark=1
tproxy_mark=1
tproxy_port=11451
dns_port=1053
direct_user=clash
chnroute_set_file=chnroute.set
chnroute6_set_file=chnroute6.set

#-------
# 地址表
#-------

readonly DNS4_DIRECT=(
    119.29.29.29/32
    114.114.114.114/32
)

readonly DNS6_DIRECT=(
    240c::6666/128
)

readonly IPV4_RESERVED_IPADDRS=(0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.0.0.0/24 192.0.2.0/24 192.88.99.0/24 192.168.0.0/16 198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4  255.255.255.255/32)

readonly IPV6_RESERVED_IPADDRS=(::/128 ::1/128 ::ffff:0:0/96 ::ffff:0:0:0/96 64:ff9b::/96 100::/64 2001::/32 2001:20::/28 2001:db8::/32 2002::/16 fc00::/7 fe80::/10 ff00::/8)

#---------
# ip 配置
#---------

# fwmark 匹配的包进入本地回环
ip -4 rule add fwmark $lo_fwmark table 100
ip -4 route add local default dev lo table 100
ip -6 rule add fwmark $lo_fwmark table 100
ip -6 route add local default dev lo table 100

#---------------
# ipset 规则导入
#---------------

sudo ipset -X chnroute &>/dev/null
sudo ipset -X chnroute6 &>/dev/null
sudo ipset create chnroute hash:net family inet
sudo ipset create chnroute6 hash:net family inet6
cat $chnroute_set_file | sudo xargs -I ip ipset add chnroute ip &>/dev/null
cat $chnroute6_set_file | sudo xargs -I ip ipset add chnroute6 ip &>/dev/null

#---------------
# iptables 配置
#---------------

is_ipv4_ipts() {
    [ "$1" = 'iptables' ]
}

do_iptables_conf() {
    ########## v4 v6 区分部分配置 ##########
    
    local privaddr_array
    is_ipv4_ipts $1 && privaddr_array=("${IPV4_RESERVED_IPADDRS[@]}") || privaddr_array=("${IPV6_RESERVED_IPADDRS[@]}")
    
    local dns_direct_array
    is_ipv4_ipts $1 && dns_direct_array=("${DNS4_DIRECT[@]}") || dns_direct_array=("${DNS6_DIRECT[@]}")
    
    local chnroute_name
    is_ipv4_ipts $1 && chnroute_name=chnroute || chnroute_name=chnroute6
    
    local loopback_addr
    is_ipv4_ipts $1 && loopback_addr=127.0.0.1 || loopback_addr=::1
    
    local local_dns
    is_ipv4_ipts $1 && local_dns=$loopback_addr:$dns_port || local_dns=[$loopback_addr]:$dns_port

    ########## 代理规则配置 ##########

    $1 -t mangle -N TRANS_RULE
    $1 -t mangle -A TRANS_RULE -j CONNMARK --restore-mark
    $1 -t mangle -A TRANS_RULE -m mark --mark $lo_fwmark -j RETURN # 避免回环
    # 私有地址
    for addr in "${privaddr_array[@]}"; do
        $1 -t mangle -A TRANS_RULE -d $addr -j RETURN
    done
    # ipset 路由
    $1 -t mangle -A TRANS_RULE -m set --match-set $chnroute_name dst -j RETURN
    # TCP/UDP 重路由 PREROUTING
    $1 -t mangle -A TRANS_RULE -p tcp --syn -j MARK --set-mark $lo_fwmark
    $1 -t mangle -A TRANS_RULE -p udp -m conntrack --ctstate NEW -j MARK --set-mark $lo_fwmark
    $1 -t mangle -A TRANS_RULE -j CONNMARK --save-mark

    ########## PREROUTING 链配置 ##########

    $1 -t mangle -N TRANS_PREROUTING
    $1 -t nat -N TRANS_PREROUTING
    $1 -t mangle -A TRANS_PREROUTING -i lo -m mark ! --mark $lo_fwmark -j RETURN
    # 局域网 DNS 路由
    $1 -t mangle -A TRANS_PREROUTING -p udp -m addrtype ! --src-type LOCAL -m udp --dport 53 -j RETURN
    $1 -t nat -A TRANS_PREROUTING -p udp -m addrtype ! --src-type LOCAL -m udp --dport 53 -j REDIRECT --to-ports $dns_port
    # 规则路由
    $1 -t mangle -A TRANS_PREROUTING -p tcp -m addrtype ! --src-type LOCAL ! --dst-type LOCAL -j TRANS_RULE
    $1 -t mangle -A TRANS_PREROUTING -p udp -m addrtype ! --src-type LOCAL ! --dst-type LOCAL -j TRANS_RULE
    # TPROXY 路由
    $1 -t mangle -A TRANS_PREROUTING -p tcp -m mark --mark $lo_fwmark -j TPROXY --on-port $tproxy_port --on-ip $loopback_addr --tproxy-mark $tproxy_mark
    $1 -t mangle -A TRANS_PREROUTING -p udp -m mark --mark $lo_fwmark -j TPROXY --on-port $tproxy_port --on-ip $loopback_addr --tproxy-mark $tproxy_mark
    # 应用规则
    $1 -t mangle -A PREROUTING -j TRANS_PREROUTING
    $1 -t nat -A PREROUTING -j TRANS_PREROUTING

    ########## OUTPUT 链配置 ##########

    $1 -t mangle -N TRANS_OUTPUT
    $1 -t nat -N TRANS_OUTPUT
    # 直连 @clash
    $1 -t mangle -A TRANS_OUTPUT -j RETURN -m owner --uid-owner $direct_user
    $1 -t mangle -A TRANS_OUTPUT -j RETURN -m mark --mark 0xff # （兼容配置) 直连 SO_MARK 为 0xff 的流量
    # 本地 DNS 路由
    $1 -t mangle -A TRANS_OUTPUT -p udp -m udp --dport 53 -j RETURN
    for addr in "${dns_direct_array[@]}"; do
        $1 -t nat -A TRANS_OUTPUT -d $addr -p udp -m udp --dport 53 -j RETURN
    done
    $1 -t nat -A TRANS_OUTPUT -p udp -m udp --dport 53 -j DNAT --to-destination $local_dns
    # 规则路由
    $1 -t mangle -A TRANS_OUTPUT -p tcp -m addrtype --src-type LOCAL ! --dst-type LOCAL -j TRANS_RULE
    $1 -t mangle -A TRANS_OUTPUT -p udp -m addrtype --src-type LOCAL ! --dst-type LOCAL -j TRANS_RULE
    # 应用规则
    $1 -t mangle -A OUTPUT -j TRANS_OUTPUT
    $1 -t nat -A OUTPUT -j TRANS_OUTPUT
}

do_iptables_conf "iptables"
do_iptables_conf "ip6tables"
