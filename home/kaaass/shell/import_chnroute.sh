#
# 导入大陆 IP 地址 ipset
# Author: KAAAsS
# 

# 下载并解析 route
wget --no-check-certificate -O- 'http://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest' | grep CN > tmp_ips
cat tmp_ips | grep ipv4 | awk -F\| '{ printf("%s/%d\n", $4, 32-log($5)/log(2)) }' > chnroute.set
cat tmp_ips | grep ipv6 | awk -F\| '{ printf("%s/%d\n", $4, 32-log($5)/log(2)) }' > chnroute6.set
rm -rf tmp_ips
# 导入 ipset 表
sudo ipset -X chnroute &>/dev/null
sudo ipset -X chnroute6 &>/dev/null
sudo ipset create chnroute hash:net family inet
sudo ipset create chnroute6 hash:net family inet6
cat chnroute.set | sudo xargs -I ip ipset add chnroute ip
cat chnroute6.set | sudo xargs -I ip ipset add chnroute6 ip
