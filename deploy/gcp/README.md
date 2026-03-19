# GCP Free Tier Deployment

## One-time setup (GCP Free Tier — $0/month)

### Step 1: Create VM
```bash
gcloud compute instances create sentineldb \
  --machine-type=e2-micro \
  --zone=us-central1-a \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=30GB \
  --tags=http-server \
  --metadata-from-file startup-script=deploy/gcp/startup.sh
```

### Step 2: Open firewall
```bash
gcloud compute firewall-rules create allow-http \
  --allow tcp:80 \
  --target-tags=http-server
```

### Step 3: Get IP and test
```bash
EXTERNAL_IP=$(gcloud compute instances describe sentineldb \
  --zone=us-central1-a \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

curl http://$EXTERNAL_IP/health
```

### Step 4: Use Python SDK
```python
from sentineldb import SentinelDB
db = SentinelDB(f"http://{EXTERNAL_IP}")
db.set("hello", "world")
print(db.get("hello"))
```

## Monitoring
```bash
# View logs
gcloud compute ssh sentineldb -- sudo journalctl -u sentineldb -f

# Restart
gcloud compute ssh sentineldb -- sudo systemctl restart sentineldb
```
