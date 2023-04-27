  #!/usr/bin/bash

  # Remove leading whitespaces in every string in text
  function dedent() {
    local reference="$1"
    reference="$(echo "$reference" | sed 's/^[[:space:]]*//')"
  }

  # Close 3proxy daemon, if it's working
  ps -ef | awk '/[3]proxy/{print $2}' | while read -r pid; do
    kill $pid
  done

  # Remove old random ip list before create new one
  if test -f /usr/local/etc/proxyserver/ipv6.list; 
  then
    # Remove old ips from interface
    for ipv6_address in $(cat /usr/local/etc/proxyserver/ipv6.list); do /sbin/ip -6 addr del $ipv6_address dev enp1s0f0;done;
    rm -f /usr/local/etc/proxyserver/ipv6.list; 
  fi;

  # Array with allowed symbols in hex (in ipv6 addresses)
  array=( 1 2 3 4 5 6 7 8 9 0 a b c d e f )

  # Generate random hex symbol
  function rh () { echo ${array[$RANDOM%16]}; }

  rnd_subnet_ip () {
    echo -n 2602:fe90:5a0;
    symbol=48
    while (( $symbol < 128)); do
      if (($symbol % 16 == 0)); then echo -n :; fi;
      echo -n $(rh);
      let "symbol += 4";
    done;
    echo ;
  }

  # Temporary variable to count generated ip's in cycle
  count=1

  # Generate random 'proxy_count' ipv6 of specified subnet and write it to 'ip.list' file
  while [ "$count" -le 7000 ]
  do
    rnd_subnet_ip >> /usr/local/etc/proxyserver/ipv6.list;
    let "count += 1";
  done;

  immutable_config_part="daemon
maxconn 1000
nserver 1.1.1.1
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
stacksize 6000
flush"
  auth_part="auth none"

  if [ true = true ]; then
    auth_part="auth strong
users admin:CL:qniP123
allow admin"
  fi;

  dedent immutable_config_part;
  dedent auth_part;   

  echo "$immutable_config_part"$'\n'"$auth_part"  > /usr/local/etc/proxyserver/3proxy/3proxy.cfg

  # Add all ipv6 backconnect proxy with random adresses in proxy server startup config
  port=40000
  count=1
  for random_ipv6_address in $(cat /usr/local/etc/proxyserver/ipv6.list); do
      if [ "http" = "http" ]; then proxy_startup_depending_on_type="proxy -6 -n -a"; else proxy_startup_depending_on_type="socks -6 -a"; fi;
      echo "$proxy_startup_depending_on_type -p$port -i92.118.234.226 -e$random_ipv6_address" >> /usr/local/etc/proxyserver/3proxy/3proxy.cfg
      ((port+=1))
      ((count+=1))
  done

  # Script that adds all random ipv6 to default interface and runs backconnect proxy server
  ulimit -n 600000
  ulimit -u 600000
  for ipv6_address in $(cat /usr/local/etc/proxyserver/ipv6.list); do /sbin/ip -6 addr add ${ipv6_address} dev enp1s0f0;done;
  /usr/local/etc/proxyserver/3proxy/bin/3proxy /usr/local/etc/proxyserver/3proxy/3proxy.cfg
  exit 0
