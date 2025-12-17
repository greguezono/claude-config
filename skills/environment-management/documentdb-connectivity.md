# DocumentDB Connectivity

## Overview

DocumentDB clusters store MongoDB-compatible data. They require VPN/VPC access and specific connection parameters.

## Available Clusters

| Cluster | Host | Database | Username |
|---------|------|----------|----------|
| Billing Service | `billing-service-documentdb-cluster.cluster-cmus3xwk5ytb.us-east-1.docdb.amazonaws.com` | billing-external | biller |
| Yardi Integration | `flex-prod-yardiintegration.cluster-cmus3xwk5ytb.us-east-1.docdb.amazonaws.com` | yardi | yardi_user |

## Connection Requirements

**CRITICAL parameters for DocumentDB:**
- `authMechanism=SCRAM-SHA-1` - Required (not default MongoDB auth)
- `retryWrites=false` - Required (DocumentDB doesn't support retryable writes)

## Python Connection

```python
from pymongo import MongoClient

# Basic connection
connection_string = (
    "mongodb://username:password@"
    "billing-service-documentdb-cluster.cluster-cmus3xwk5ytb.us-east-1.docdb.amazonaws.com/"
    "billing-external?authMechanism=SCRAM-SHA-1&retryWrites=false"
)

client = MongoClient(
    connection_string,
    serverSelectionTimeoutMS=5000
)

# Access database and collection
db = client["billing-external"]
collection = db["collection_name"]

# Query
results = collection.find({"field": "value"})
```

### With TLS Certificate

```python
client = MongoClient(
    connection_string,
    serverSelectionTimeoutMS=5000,
    tlsCAFile='/Users/kmark/workspace/kube/rds-combined-ca-bundle.pem'
)
```

## Configuration Files

**Location:** `~/workspace/kube/`

- `billing_doc_db.conf` - Billing service connection
- `yardi_doc_db.conf` - Yardi integration connection

**Certificate:** `rds-combined-ca-bundle.pem`

## Analysis Scripts

**Location:** `~/workspace/aws/documentdb-scripts/`

| Script | Purpose |
|--------|---------|
| `test_documentdb_connection.py` | Verify connection, list collections |
| `find_top_growth.py` | Top properties by resident growth |
| `analyze_property_detail.py` | Property data analysis |
| `analyze_resident_growth.py` | Resident growth metrics |
| `compare_lease_statuses.py` | Lease status comparisons |

### Running Scripts

```bash
cd ~/workspace/aws/documentdb-scripts
source venv/bin/activate  # if virtual env exists
python test_documentdb_connection.py
```

## Network Access

**Important:** DocumentDB clusters are in private VPCs. Access requires:
1. VPN connection to AWS network, OR
2. Running from EC2 instance in same VPC, OR
3. SSH tunnel through bastion host

## Safety Rules

**Read-Only by Default:**
- Only run `find()` queries without permission
- Never run `insert`, `update`, `delete`, `drop` without explicit confirmation

**Safe Operations:**
- `find()` queries
- `count()` operations
- `aggregate()` (without `$out` or `$merge`)
- `list_collections()`

**Unsafe Operations (require confirmation):**
- `insert_one()`, `insert_many()`
- `update_one()`, `update_many()`
- `delete_one()`, `delete_many()`
- `drop()`, `create_collection()`, `create_index()`

## Troubleshooting

### Connection Timeout
- Check VPN is connected
- Verify network access to VPC

### Authentication Failed
- Verify `authMechanism=SCRAM-SHA-1` in connection string
- Check username/password

### retryWrites Error
- Ensure `retryWrites=false` in connection string
