#!/bin/ash
HOME=/opt/pleroma

set -e

echo "-- Waiting for database..."
while ! pg_isready -U ${DB_USER:-pleroma} -d postgres://${DB_HOST:-db}:5432/${DB_NAME:-pleroma} -t 1; do
    sleep 1s
done

echo "-- Running migrations..."
$HOME/bin/pleroma_ctl migrate

$HOME/watch_hosts.sh & jobs

echo "-- Starting!"
sleep infinity
exec $HOME/bin/pleroma start
