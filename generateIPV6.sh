# Generate random hex symbol
 P_VALUES=( 1 2 3 4 5 6 7 8 9 0 a b c d e f )
 PROXY_NET_MASK=48
 generate_proxy() {
  a=${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}
  b=${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}
  c=${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}
  d=${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}
  e=${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}${P_VALUES[$RANDOM % 16]}

  echo "2602:fe90:5a0:$a:$b:$c:$d$([ $PROXY_NET_MASK == 48 ] && echo ":$e" || echo "")" 
  
}

  # Temporary variable to count generated ip's in cycle
  count=1

  # Generate random 'proxy_count' ipv6 of specified subnet and write it to 'ip.list' file
  while [ "$count" -le 30000 ]
  do
    generate_proxy >> /root/data.txt;
    let "count += 1";
  done;
sort -u /root/data.txt > /root/data_temp.txt && mv /root/data_temp.txt /root/data.txt
