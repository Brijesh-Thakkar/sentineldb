#!/bin/bash
set -euo pipefail
echo "=== SentinelDB GCP Setup ==="

apt-get update -qq
apt-get install -y cmake g++ make git nginx curl

mkdir -p /mnt/data/sentineldb
useradd -r -s /bin/false sentineldb 2>/dev/null || true

mkdir -p /opt/sentineldb
cd /opt/sentineldb
git clone https://github.com/Brijesh-Thakkar/sentineldb.git . || git pull
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel $(nproc)

ln -sf /mnt/data/sentineldb /opt/sentineldb/data
chown -R sentineldb:sentineldb /opt/sentineldb /mnt/data/sentineldb

cp deploy/gcp/sentineldb.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable sentineldb
systemctl start sentineldb

cp deploy/gcp/nginx.conf /etc/nginx/sites-available/sentineldb
ln -sf /etc/nginx/sites-available/sentineldb /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

echo "=== Setup complete ==="
echo "SentinelDB: http://$(curl -sf ifconfig.me)/health"
