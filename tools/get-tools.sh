#!/bin/bash

mkdir -p /opt/webfocus/logs/tools
cd /opt/webfocus/logs/tools

echo "Downloading tools in /opt/webfocus/logs/tools"
ls -la 

curl -s https://raw.githubusercontent.com/ishswar/octant-service/master/tools/nc -O
chmod +x nc

curl -s https://raw.githubusercontent.com/ishswar/octant-service/master/tools/netstat -O
chmod +x netstat

curl -s https://raw.githubusercontent.com/ishswar/octant-service/master/tools/ps -O
chmod +x ps

curl -s https://raw.githubusercontent.com/ishswar/octant-service/master/tools/ping -O
curl -s https://raw.githubusercontent.com/ishswar/octant-service/master/tools/wget -O
curl -s https://raw.githubusercontent.com/ishswar/octant-service/master/tools/nano -O
curl -s https://raw.githubusercontent.com/ishswar/octant-service/master/tools/nslookup -O
curl -s https://raw.githubusercontent.com/ishswar/octant-service/master/tools/top -O
curl -s https://raw.githubusercontent.com/ishswar/octant-service/master/tools/libprocps.so.7 -O
chmod +x ping
chmod +x wget
chmod +x nano
chmod +x nslookup
chmod +x top
cp libprocps.so.7 /lib64/libprocps.so.7

echo "Done copying tools to /opt/webfocus/logs/tools"
ls -la
