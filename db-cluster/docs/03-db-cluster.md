# Database Cluster (Stateful Tier)

## Overview

High-availability database cluster with replication, automatic failover, and distributed consensus for stateful application data.

## Infrastructure Type

**LXC Container** - Databases run efficiently in containers without kernel-level isolation requirements

## Cluster Options

Choose one of the following database architectures:

### Option A: MongoDB Replica Set
- **3 MongoDB instances** - Primary + 2 secondaries
- Automatic failover
- Read scaling with secondary reads
- Suitable for document-oriented applications

### Option B: PostgreSQL with Patroni
- **3 PostgreSQL instances** - 1 primary + 2 standby replicas
- **etcd** - Distributed consensus and leader election
- High availability with automatic failover
- Suitable for relational data

## Resource Allocation

- **RAM:** 3-4GB total (1-1.5GB per database instance)
- **vCPU:** 4 cores total
- **Storage:** 100GB+ (depends on data volume)

## Architecture Diagram

```
┌─────────────────────────────────────────┐
│         LXC Container                   │
│  ┌──────────┐  ┌──────────┐  ┌────────┐│
│  │ MongoDB  │  │ MongoDB  │  │MongoDB ││
│  │ Primary  │  │Secondary │  │Replica ││
│  │ :27017   │  │ :27018   │  │ :27019 ││
│  └──────────┘  └──────────┘  └────────┘│
│         ↑            ↑           ↑      │
│         └────────────┴───────────┘      │
│              Replica Set                │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │   etcd (Consensus/Coordination)  │  │
│  │          :2379, :2380            │  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

## Implementation Steps

### 1. Create LXC Container

```bash
# Create LXC container on Proxmox
pct create 300 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname db-cluster \
  --cores 4 \
  --memory 4096 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --storage local-lvm \
  --rootfs local-lvm:100
```

### 2. MongoDB Replica Set Setup

#### Install MongoDB

```bash
# Inside LXC container
apt update && apt upgrade -y

# Import MongoDB GPG key
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
  gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor

# Add MongoDB repository
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] \
https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
  tee /etc/apt/sources.list.d/mongodb-org-7.0.list

# Install MongoDB
apt update
apt install -y mongodb-org

# Start MongoDB service
systemctl start mongod
systemctl enable mongod
```

#### Configure Replica Set

Create three MongoDB instances:

```bash
# Create data directories
mkdir -p /data/mongo-{1,2,3}

# Configuration for instance 1 (Primary)
cat > /etc/mongod-1.conf <<EOF
storage:
  dbPath: /data/mongo-1
net:
  port: 27017
  bindIp: 0.0.0.0
replication:
  replSetName: "rs0"
EOF

# Configuration for instance 2 (Secondary)
cat > /etc/mongod-2.conf <<EOF
storage:
  dbPath: /data/mongo-2
net:
  port: 27018
  bindIp: 0.0.0.0
replication:
  replSetName: "rs0"
EOF

# Configuration for instance 3 (Secondary)
cat > /etc/mongod-3.conf <<EOF
storage:
  dbPath: /data/mongo-3
net:
  port: 27019
  bindIp: 0.0.0.0
replication:
  replSetName: "rs0"
EOF

# Create systemd services
for i in {1..3}; do
  cat > /etc/systemd/system/mongod-$i.service <<EOF
[Unit]
Description=MongoDB Database Server instance $i
After=network.target

[Service]
Type=forking
User=mongodb
PIDFile=/var/run/mongodb/mongod-$i.pid
ExecStart=/usr/bin/mongod --config /etc/mongod-$i.conf --fork --pidfilepath /var/run/mongodb/mongod-$i.pid
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
done

# Start all instances
systemctl daemon-reload
systemctl start mongod-{1,2,3}
systemctl enable mongod-{1,2,3}
```

#### Initialize Replica Set

```bash
# Connect to primary
mongosh --port 27017

# Initialize replica set
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "localhost:27017", priority: 2 },
    { _id: 1, host: "localhost:27018", priority: 1 },
    { _id: 2, host: "localhost:27019", priority: 1 }
  ]
})

# Check status
rs.status()

# Create admin user
use admin
db.createUser({
  user: "admin",
  pwd: "secure_password_here",
  roles: [ { role: "root", db: "admin" } ]
})
```

### 3. PostgreSQL with Patroni Setup

#### Install PostgreSQL and Patroni

```bash
# Install PostgreSQL
apt install -y postgresql postgresql-contrib

# Install Patroni
apt install -y python3-pip python3-dev libpq-dev
pip3 install patroni[etcd] psycopg2-binary

# Install etcd
apt install -y etcd
```

#### Configure etcd

```bash
cat > /etc/default/etcd <<EOF
ETCD_NAME="etcd0"
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379"
ETCD_ADVERTISE_CLIENT_URLS="http://localhost:2379"
ETCD_LISTEN_PEER_URLS="http://0.0.0.0:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://localhost:2380"
ETCD_INITIAL_CLUSTER="etcd0=http://localhost:2380"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-token"
EOF

systemctl restart etcd
systemctl enable etcd
```

#### Configure Patroni

```bash
cat > /etc/patroni.yml <<EOF
scope: postgres-cluster
namespace: /db/
name: postgres1

restapi:
  listen: 0.0.0.0:8008
  connect_address: localhost:8008

etcd:
  host: localhost:2379

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
    postgresql:
      use_pg_rewind: true
      parameters:
        max_connections: 100
        shared_buffers: 256MB

  initdb:
    - encoding: UTF8
    - data-checksums

  pg_hba:
    - host replication replicator 0.0.0.0/0 md5
    - host all all 0.0.0.0/0 md5

  users:
    admin:
      password: admin_password
      options:
        - createrole
        - createdb
    replicator:
      password: repl_password
      options:
        - replication

postgresql:
  listen: 0.0.0.0:5432
  connect_address: localhost:5432
  data_dir: /var/lib/postgresql/14/main
  bin_dir: /usr/lib/postgresql/14/bin
  pgpass: /tmp/pgpass
  authentication:
    replication:
      username: replicator
      password: repl_password
    superuser:
      username: postgres
      password: postgres_password
  parameters:
    unix_socket_directories: '/var/run/postgresql'

tags:
  nofailover: false
  noloadbalance: false
  clonefrom: false
  nosync: false
EOF

# Create systemd service
cat > /etc/systemd/system/patroni.service <<EOF
[Unit]
Description=Patroni PostgreSQL HA
After=syslog.target network.target etcd.service

[Service]
Type=simple
User=postgres
Group=postgres
ExecStart=/usr/local/bin/patroni /etc/patroni.yml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start patroni
systemctl enable patroni
```

### 4. etcd for Distributed Coordination

etcd is used for:
- **Leader election** - Automatic primary selection
- **Configuration storage** - Cluster state management
- **Service discovery** - Node registration
- **Distributed locks** - Coordination primitives

```bash
# Check etcd cluster health
etcdctl endpoint health

# View cluster members
etcdctl member list

# Get/Set values
etcdctl put /example/key "value"
etcdctl get /example/key
```

## Serverless Functions Integration

### Use Cases

#### 1. Automated Database Backups

```python
# OpenFaaS function: db-backup
import subprocess
from datetime import datetime

def handle(req):
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_file = f"/backup/mongo_backup_{timestamp}.gz"

    # MongoDB backup
    subprocess.run([
        "mongodump",
        "--host", "localhost:27017",
        "--archive=" + backup_file,
        "--gzip"
    ])

    # Upload to S3 or NFS share
    # upload_to_storage(backup_file)

    return f"Backup completed: {backup_file}"
```

**Kubernetes CronJob:**
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: db-backup
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: openfaas/db-backup:latest
            env:
            - name: MONGO_URI
              value: "mongodb://db-cluster:27017"
```

#### 2. ETL Pipeline

```python
# Extract data from source DB, transform, load to warehouse
def handle(req):
    import pymongo

    client = pymongo.MongoClient("mongodb://localhost:27017")
    db = client.analytics

    # Extract
    raw_data = db.events.find({"processed": False})

    # Transform
    processed = [transform_record(r) for r in raw_data]

    # Load to data warehouse
    db.processed_events.insert_many(processed)

    return f"Processed {len(processed)} records"
```

#### 3. Data Cleanup Jobs

```python
# Delete old records, archive data
def handle(req):
    from datetime import datetime, timedelta

    cutoff_date = datetime.now() - timedelta(days=90)

    result = db.logs.delete_many({
        "created_at": {"$lt": cutoff_date}
    })

    return f"Deleted {result.deleted_count} old records"
```

#### 4. Real-time Data Aggregation

```python
# Aggregate metrics for dashboards
def handle(req):
    pipeline = [
        {"$match": {"timestamp": {"$gte": datetime.now() - timedelta(hours=1)}}},
        {"$group": {
            "_id": "$user_id",
            "total_events": {"$sum": 1},
            "avg_duration": {"$avg": "$duration"}
        }}
    ]

    results = db.events.aggregate(pipeline)
    return list(results)
```

## High Availability Features

### MongoDB Replica Set
- **Automatic Failover** - Secondary promoted to primary on failure
- **Read Scaling** - Distribute reads across secondaries
- **Data Redundancy** - Multiple copies of data
- **Oplog Tailing** - Real-time data sync

### PostgreSQL with Patroni
- **Automatic Failover** - Patroni handles leader election via etcd
- **Synchronous Replication** - Zero data loss mode
- **Connection Pooling** - PgBouncer integration
- **Point-in-Time Recovery** - WAL archiving

## Monitoring & Alerts

### MongoDB Monitoring

```bash
# Install MongoDB Exporter for Prometheus
docker run -d -p 9216:9216 \
  -e MONGODB_URI=mongodb://localhost:27017 \
  percona/mongodb_exporter:latest
```

### PostgreSQL Monitoring

```bash
# Install Postgres Exporter
apt install -y prometheus-postgres-exporter

# Configure connection
cat > /etc/default/prometheus-postgres-exporter <<EOF
DATA_SOURCE_NAME="user=postgres password=password host=/var/run/postgresql/ sslmode=disable"
EOF

systemctl restart prometheus-postgres-exporter
```

### Key Metrics to Monitor
- Replication lag
- Connection count
- Query performance
- Disk usage
- CPU and memory utilization
- Backup success/failure

## Backup Strategy

### MongoDB Backups

```bash
# Full backup
mongodump --host localhost:27017 --out /backup/$(date +%Y%m%d)

# Incremental backup (oplog)
mongodump --host localhost:27017 --oplog --out /backup/oplog

# Restore
mongorestore --host localhost:27017 /backup/20250130
```

### PostgreSQL Backups

```bash
# Full backup with pg_basebackup
pg_basebackup -h localhost -U replicator -D /backup/pg_backup -Fp -Xs -P

# Point-in-time recovery with WAL archiving
# Configure in postgresql.conf:
archive_mode = on
archive_command = 'cp %p /backup/wal_archive/%f'

# Restore
pg_restore -h localhost -U postgres -d mydb /backup/pg_backup
```

## Security Best Practices

- **Authentication** - Enable auth, strong passwords
- **Encryption** - TLS/SSL for client connections
- **Network Isolation** - Firewall rules, private network
- **User Roles** - Principle of least privilege
- **Audit Logging** - Track database access
- **Regular Updates** - Security patches

## Performance Tuning

### MongoDB
```javascript
// Create indexes
db.users.createIndex({ email: 1 }, { unique: true })
db.events.createIndex({ timestamp: -1, user_id: 1 })

// Enable profiling
db.setProfilingLevel(1, { slowms: 100 })

// Analyze query performance
db.collection.explain("executionStats").find({...})
```

### PostgreSQL
```sql
-- Create indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_events_timestamp ON events(timestamp DESC, user_id);

-- Analyze query plans
EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'user@example.com';

-- Vacuum and analyze
VACUUM ANALYZE;
```

## Disaster Recovery

### Recovery Time Objective (RTO)
- **MongoDB Replica Set**: < 30 seconds (automatic failover)
- **PostgreSQL with Patroni**: < 60 seconds (automatic failover)

### Recovery Point Objective (RPO)
- **Synchronous replication**: 0 data loss
- **Asynchronous replication**: Minimal data loss (seconds)

### DR Procedures

1. **Primary Failure**: Automatic failover to secondary/standby
2. **Complete Cluster Failure**: Restore from backup
3. **Data Corruption**: Point-in-time recovery
4. **Disaster Site**: Geo-replicated secondary cluster

## Scaling Considerations

### Vertical Scaling
- Increase RAM/CPU for LXC container
- Upgrade storage for larger datasets

### Horizontal Scaling
- **MongoDB**: Add more replica set members or shard cluster
- **PostgreSQL**: Add read replicas, partition tables

## Next Steps

1. Create LXC container on Proxmox
2. Choose database architecture (MongoDB or PostgreSQL)
3. Install and configure database cluster
4. Set up etcd for coordination
5. Configure backups and monitoring
6. Deploy serverless functions for automation
7. Integrate with K8s applications

---

**Related Projects:**
- [K8s Platform](./02-k8s-platform.md) - Application layer consuming database
- [CI/CD Platform](./01-cicd-platform.md) - Database for CI/CD metadata
