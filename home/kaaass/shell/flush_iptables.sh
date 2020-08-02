#
# 清理透明代理配置
# Author: KAAAsS
#

flush_iptables() {
    $1 -t mangle -D PREROUTING  -j TRANS_PREROUTING  &>/dev/null
    $1 -t mangle -D OUTPUT      -j TRANS_OUTPUT      &>/dev/null
    $1 -t nat    -D PREROUTING  -j TRANS_PREROUTING  &>/dev/null
    $1 -t nat    -D OUTPUT      -j TRANS_OUTPUT      &>/dev/null

    $1 -t mangle -F TRANS_PREROUTING  &>/dev/null
    $1 -t mangle -X TRANS_PREROUTING  &>/dev/null
    $1 -t mangle -F TRANS_OUTPUT      &>/dev/null
    $1 -t mangle -X TRANS_OUTPUT      &>/dev/null
    $1 -t nat    -F TRANS_PREROUTING  &>/dev/null
    $1 -t nat    -X TRANS_PREROUTING  &>/dev/null
    $1 -t nat    -F TRANS_OUTPUT      &>/dev/null
    $1 -t nat    -X TRANS_OUTPUT      &>/dev/null
    
    $1 -t mangle -F TRANS_RULE  &>/dev/null
    $1 -t mangle -X TRANS_RULE  &>/dev/null
}

flush_ip() {
    ip -4 rule del table 100
    ip -6 rule del table 100
    ip -4 route flush table 100
    ip -6 route flush table 100
}

flush_iptables "iptables"
flush_iptables "ip6tables"
flush_ip
