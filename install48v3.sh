#!/bin/bash

if ping6 -c3 google.com &>/dev/null; then
  echo "Your server is ready to set up IPv6 proxies!"
else
  echo "Your server can't connect to IPv6 addresses."
  echo "Please, connect ipv6 interface to your server to continue."
  exit 1
fi

####
echo "↓ Routed /48 or /64 IPv6 prefix from tunnelbroker (*:*:*::/*):"
read PROXY_NETWORK

if [[ $PROXY_NETWORK == *"::/48"* ]]; then
  PROXY_NET_MASK=48
elif [[ $PROXY_NETWORK == *"::/64"* ]]; then
  PROXY_NET_MASK=64
else
  echo "● Unsupported IPv6 prefix format: $PROXY_NETWORK"
  exit 1
fi

####
echo "↓ Server IPv4 address from tunnelbroker:"
read TUNNEL_IPV4_ADDR
if [[ ! "$TUNNEL_IPV4_ADDR" ]]; then
  echo "● IPv4 address can't be emty"
  exit 1
fi



####
echo "↓ Port numbering start (default 1500):"
read PROXY_START_PORT
if [[ ! "$PROXY_START_PORT" ]]; then
  PROXY_START_PORT=1500
fi

####
echo "↓ Proxies count (default 1):"
read PROXY_COUNT
if [[ ! "$PROXY_COUNT" ]]; then
  PROXY_COUNT=1
fi

####
echo "↓ Proxies protocol (http, socks5; default http):"
read PROXY_PROTOCOL
if [[ PROXY_PROTOCOL != "socks5" ]]; then
  PROXY_PROTOCOL="http"
fi

####
clear
sleep 1
PROXY_NETWORK=$(echo $PROXY_NETWORK | awk -F:: '{print $1}')
echo "● Network: $PROXY_NETWORK"
echo "● Network Mask: $PROXY_NET_MASK"
HOST_IPV4_ADDR=$(hostname -I | awk '{print $1}')
echo "● Host IPv4 address: $HOST_IPV4_ADDR"
echo "● Tunnel IPv4 address: $TUNNEL_IPV4_ADDR"
echo "● Proxies count: $PROXY_COUNT, starting from port: $PROXY_START_PORT"
echo "● Proxies protocol: $PROXY_PROTOCOL"


####
echo "-------------------------------------------------"
echo ">-- Updating packages and installing dependencies"
sudo yum update >/dev/null 2>&1
sudo yum -y install gcc g++ make bc pwgen git >/dev/null 2>&1

####
echo ">-- Setting up sysctl.conf"
cat >>/etc/sysctl.conf <<END
net.ipv6.conf.enp1s0f0.proxy_ndp=1
net.ipv6.conf.all.proxy_ndp=1
net.ipv6.conf.default.forwarding=1
net.ipv6.conf.all.forwarding=1
net.ipv6.ip_nonlocal_bind=1
net.ipv4.ip_local_port_range=1024 64000
net.ipv6.route.max_size=409600
net.ipv4.tcp_max_syn_backlog=4096
net.ipv6.neigh.default.gc_thresh3=102400
kernel.threads-max=1200000
kernel.max_map_count=6000000
vm.max_map_count=6000000
kernel.pid_max=2000000
END

####
echo ">-- Setting up logind.conf"
echo "UserTasksMax=1000000" >>/etc/systemd/logind.conf

####
echo ">-- Setting up system.conf"
cat >>/etc/systemd/system.conf <<END
UserTasksMax=1000000
DefaultMemoryAccounting=no
DefaultTasksAccounting=no
DefaultTasksMax=1000000
UserTasksMax=1000000
END

####
echo ">-- Setting up ndppd"
sudo yum install git
	sudo yum install gcc-c++
	sudo yum install gcc make
	git clone https://github.com/DanielAdolfsson/ndppd.git
	cd ndppd
	make
	sudo make install
cat >~/ndppd/ndppd.conf <<END
route-ttl 30000
proxy enp1s0f0 {
   router no
   timeout 500
   ttl 30000
   rule ${PROXY_NETWORK}::/${PROXY_NET_MASK} {
      static
   }
}
END
####

echo ">-- Setting up 3proxy"
cd ~
wget -q https://github.com/z3APA3A/3proxy/archive/0.8.13.tar.gz
tar xzf 0.8.13.tar.gz
mv ~/3proxy-0.8.13 ~/3proxy
rm 0.8.13.tar.gz
cd ~/3proxy
chmod +x src/
touch src/define.txt
echo "#define ANONYMOUS 1" >src/define.txt
sed -i '31r src/define.txt' src/proxy.h
make -f Makefile.Linux >/dev/null 2>&1

random() {
	tr </dev/urandom -dc A-Za-z0-9 | head -c5
	echo
}

LAST_PORT=$(($PROXY_START_PORT + $PROXY_COUNT))
P_VALUES=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
generate_proxy() {
  a=${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}
  b=${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}
  c=${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}
  d=${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}
  e=${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}

  echo "$PROXY_NETWORK:$a:$b:$c:$d$([ $PROXY_NET_MASK == 48 ] && echo ":$e" || echo "")" 
  

}
gen_3proxy() {
    cat <<EOF
daemon
maxconn 10000
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
flush
auth strong

users $(awk -F "/" 'BEGIN{ORS="";} {print $1 ":CL:" $2 " "}' ${WORKDATA})

$(awk -F "/" '{print "auth strong\n" \
"allow " $1 "\n" \
"proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" \
"flush\n"}' ${WORKDATA})
EOF
}

gen_proxy_file_for_user() {
    cat >/root/proxy.txt <<EOF
$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA})
EOF
}


gen_data() {
    seq $PROXY_START_PORT $LAST_PORT | while read port; do
        echo "usr$(random)/pass$(random)/$HOST_IPV4_ADDR/$port/$(generate_proxy)"
    done
}
gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/48"}' ${WORKDATA})
EOF
}
echo "working folder = /home/proxy-installer"
WORKDIR="/home/proxy-installer"
WORKDATA="${WORKDIR}/data.txt"
mkdir $WORKDIR && cd $_
gen_data >$WORKDIR/data.txt

gen_3proxy > ~/3proxy/3proxy.cfg
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
chmod +x ${WORKDIR}/boot_*.sh /etc/rc.local

gen_proxy_file_for_user

####
echo ">-- Setting up rc.local"
cat >/etc/rc.local <<END
#!/bin/bash

ulimit -n 600000
ulimit -u 600000
ulimit -i 1200000
ulimit -s 1000000
ulimit -l 200000
bash ${WORKDIR}/boot_ifconfig.sh
/sbin/ip addr add ${PROXY_NETWORK}::/${PROXY_NET_MASK} dev enp1s0f0
sleep 5
/sbin/ip -6 route add default via ${PROXY_NETWORK}::1
/sbin/ip -6 route add local ${PROXY_NETWORK}::/${PROXY_NET_MASK} dev lo
/sbin/ip tunnel add enp1s0f0 mode sit remote ${TUNNEL_IPV4_ADDR} local ${HOST_IPV4_ADDR} ttl 255
/sbin/ip link set enp1s0f0 up
/sbin/ip -6 route add 2000::/3 dev enp1s0f0
~/ndppd/ndppd -d -c ~/ndppd/ndppd.conf
sleep 2
~/3proxy/src/3proxy ~/3proxy/3proxy.cfg
exit 0

END

####
echo "Finishing and rebooting"
reboot now
