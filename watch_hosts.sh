#!/bin/bash

echo "watch hosts"
if [ -f "/shared_etc/yg_hosts" ]
then
echo "found yg_hosts, copying"
cat /shared_etc/yg_hosts > /etc/hosts
fi

while inotifywait -e close_write /shared_etc/yg_hosts; 
do 
echo "updated, copy yg_hosts"
cat /shared_etc/yg_hosts > /etc/hosts
done