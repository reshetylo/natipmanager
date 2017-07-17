# NAT IP Manager/Switch
Small Bash script for NAT port destination management.
In other words this is IPTABLES port destination IP Manager/Switch (for NAT table)

Currently it is checking among 3 IP:Port pairs. Primary, Secondary and Failover. Number of incoming NAT ports is not limited in script.

If Primary is not accessible it is checking Secondary and if it is accessible then it performs a switch in iptables. Example:
```
2017-07-17 08:07:33 RUN: /sbin/iptables -t nat -D PREROUTING -p tcp -m tcp --dport 443 -j DNAT --to-destination 10.8.0.1:8082
2017-07-17 08:07:33 RUN: /sbin/iptables -t nat -A PREROUTING -p tcp -m tcp --dport 443 -j DNAT --to-destination 10.8.0.2:443
2017-07-17 08:07:33 Record:   -A PREROUTING -p tcp -m tcp --dport 443 -j DNAT --to-destination 10.8.0.1:8082
Updated with: /sbin/iptables -t nat -A PREROUTING -p tcp -m tcp --dport 443 -j DNAT --to-destination 10.8.0.2:443
```

Once Primary destination becomes available it swithches back to Primary. The the same happens with Secondary and Failover pair.

## Requirements
* bash 4.x
* iptables
* root rights

## Port and Servers list file (ip_list.csv)
First column is incoming port in NAT table.
Next 3 are destination IPs for that port.

File format:
Incoming_Port,PrimaryDestination,SecondaryDestination,FaioverDestination

Example:
```
443,10.8.0.1:443,10.8.0.2:443,10.8.0.10:4443
80,10.8.0.1:80,10.8.0.2:80,10.8.0.10:8080
8081,10.8.0.1:8081,10.8.0.2:8081,10.8.0.10:8082
```

## Installation
1. Clone git repository to some folder on your server
2. Edit configuration file **ip_list.csv** for your needs.
3. Start it manually or via cron **using root**

Manual command:
```
./natipmanager.sh ip_list.csv
```
Command with logging redirect:
```
./natipmanager.sh ip_list.csv >> natipmanager.log 2>> natipmanager_error.log
```
Command for crontab (runs every 15 minutes. If another copy is running it is not doing anything). Logs redirected to /var/log dir:
```
*/15 * * * * /bin/bash /root/natipmanager.sh /root/ip_list.csv >> /var/log/natipmanager.log 2>> /var/log/natipmanager_error.log
```

## Configurable variables
TIMEOUT=5 **# timeout for each destination**

CHECK_DELAY=8 **# delay before checking list next time**

LOCK_FILE=~/natipmanagemer.lock  **# lock file location**

IPTABLES_BIN="/sbin/iptables" **# iptables binary location**


## Example logs
```
2017-07-17 06:07:01 IP list updated.
2017-07-17 06:07:01 SOURCE PORT: 443
Primary: 10.8.0.4 port 443
Secondary: 10.8.0.2 port 443
Failover: 10.8.0.1 port 8082
=========
2017-07-17 06:07:01 Port 443: PR Connection fail (10.8.0.4:443)
2017-07-17 06:07:01 Port 443: SE Connection fail (10.8.0.2:443)
2017-07-17 06:07:01 Port 443: FO Connection OK
2017-07-17 06:07:01 RUN: /sbin/iptables -t nat -A PREROUTING -p tcp -m tcp --dport 443 -j DNAT --to-destination 10.8.0.1:8082
2017-07-17 06:07:01 Record:
Updated with:   /sbin/iptables -t nat -A PREROUTING -p tcp -m tcp --dport 443 -j DNAT --to-destination 10.8.0.1:8082
=========
2017-07-17 06:07:01 Port 443: SWITCHED to FO (10.8.0.1:8082)
2017-07-17 06:07:01 SOURCE PORT: 80
Primary: 10.8.0.4 port 80
Secondary: 10.8.0.2 port 80
Failover: 10.8.0.1 port 8082
=========
2017-07-17 06:07:01 Port 80: PR Connection OK
2017-07-17 06:07:01 RUN: /sbin/iptables -t nat -A PREROUTING -p tcp -m tcp --dport 80 -j DNAT --to-destination 10.8.0.4:80
2017-07-17 06:07:01 Record:
Updated with:   /sbin/iptables -t nat -A PREROUTING -p tcp -m tcp --dport 80 -j DNAT --to-destination 10.8.0.4:80
=========
2017-07-17 06:07:01 Port 80: SWITCHED to PR (10.8.0.4:80)
2017-07-17 06:07:01 SOURCE PORT: 8081
Primary: 10.8.0.4 port 8081
Secondary: 10.8.0.2 port 8081
Failover: 10.8.0.1 port 8082
=========
2017-07-17 06:07:01 Port 8081: PR Connection fail (10.8.0.4:8081)
2017-07-17 06:07:01 Port 8081: SE Connection fail (10.8.0.2:8081)
2017-07-17 06:07:01 Port 8081: FO Connection OK
2017-07-17 06:07:01 RUN: /sbin/iptables -t nat -A PREROUTING -p tcp -m tcp --dport 8081 -j DNAT --to-destination 10.8.0.1:8082
2017-07-17 06:07:01 Record:
Updated with:   /sbin/iptables -t nat -A PREROUTING -p tcp -m tcp --dport 8081 -j DNAT --to-destination 10.8.0.1:8082
=========
2017-07-17 06:07:01 Port 8081: SWITCHED to FO (10.8.0.1:8082)
```

Script tested on Debian
