#!/bin/ash
HOME=/opt/pleroma

set -e

echo "-- Waiting for database..."
while ! pg_isready -U ${DB_USER:-pleroma} -d postgres://${DB_HOST:-db}:5432/${DB_NAME:-pleroma} -t 1; do
    sleep 1s
done

while [ ! -f /yggdrasil/config.conf ]
do
echo "waiting for yggdrasil config"
sleep 5
done

echo "get public key"
PUB=$(jq '.PublicKey' /yggdrasil/config.conf | tr -d '"')
echo $PUB
P1=${PUB:0:63}
P2=${PUB:63:1}
echo $PUB
export DOMAIN="pleroma.$P1.$P2.yg"
echo $DOMAIN

echo "-- Running migrations..."
$HOME/bin/pleroma_ctl migrate

$HOME/watch_hosts.sh & jobs

echo "-- Starting!"
# sleep infinity
exec $HOME/bin/pleroma start
