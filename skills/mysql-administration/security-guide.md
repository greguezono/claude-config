# MySQL Security Guide

## Purpose

This guide provides comprehensive MySQL security coverage including authentication mechanisms, authorization and privilege management, encryption (data at rest and in transit), audit logging, network security, and compliance considerations. It covers MySQL 8.0+ features, Aurora MySQL security, and production hardening best practices.

## When to Use

Use this guide when you need to:

- Set up secure user authentication and access control
- Implement encryption for data at rest and in transit
- Configure audit logging for compliance requirements
- Harden MySQL installations against security threats
- Review and improve existing security configurations
- Implement least-privilege access patterns
- Prepare for security audits or compliance assessments
- Secure Aurora MySQL deployments

## Core Concepts

### Defense in Depth

MySQL security follows a defense-in-depth approach with multiple layers:

1. **Network Security**: Control who can connect
2. **Authentication**: Verify user identity
3. **Authorization**: Control what users can do
4. **Encryption**: Protect data in transit and at rest
5. **Auditing**: Track and log all activities
6. **Application Security**: Prevent SQL injection and misuse

### MySQL Security Model

MySQL uses a two-stage security model:

**Stage 1: Connection Verification**
- Host/IP address check
- Username verification
- Password/authentication method validation
- SSL/TLS certificate validation (if required)

**Stage 2: Request Verification**
- Check privileges for each operation
- Evaluate grants at global, database, table, column levels
- Verify routine and proxy privileges

```sql
-- View how MySQL verifies connections
SELECT user, host, authentication_string, plugin
FROM mysql.user
ORDER BY user, host;
```

## Authentication

### Authentication Plugins

MySQL 8.0 supports multiple authentication plugins:

| Plugin | Description | Use Case |
|--------|-------------|----------|
| `caching_sha2_password` | Default in 8.0, secure | Standard use |
| `mysql_native_password` | Legacy, less secure | Backward compatibility |
| `sha256_password` | SHA-256, requires SSL | High security |
| `auth_socket` | Unix socket authentication | Local admin access |
| `authentication_ldap_sasl` | LDAP with SASL | Enterprise SSO |
| `authentication_ldap_simple` | Simple LDAP bind | Enterprise directory |
| `authentication_pam` | PAM authentication | System integration |

### Setting Default Authentication Plugin

```ini
# my.cnf
[mysqld]
# MySQL 8.0 default
default_authentication_plugin = caching_sha2_password

# For legacy application compatibility (not recommended)
# default_authentication_plugin = mysql_native_password
```

### Creating Users with Different Authentication

```sql
-- Default authentication (caching_sha2_password in 8.0)
CREATE USER 'app_user'@'10.0.0.%'
    IDENTIFIED BY 'SecureP@ssw0rd123!';

-- Explicit authentication plugin
CREATE USER 'secure_user'@'%'
    IDENTIFIED WITH caching_sha2_password BY 'SecureP@ssw0rd123!';

-- Native password (legacy compatibility)
CREATE USER 'legacy_user'@'%'
    IDENTIFIED WITH mysql_native_password BY 'LegacyP@ss123!';

-- Socket authentication (local only, no password)
CREATE USER 'local_admin'@'localhost'
    IDENTIFIED WITH auth_socket;

-- Require SSL for connection
CREATE USER 'ssl_user'@'%'
    IDENTIFIED BY 'SecureP@ss!'
    REQUIRE SSL;

-- Require specific SSL certificate
CREATE USER 'cert_user'@'%'
    IDENTIFIED BY 'SecureP@ss!'
    REQUIRE X509;

-- Require specific issuer/subject
CREATE USER 'strict_cert_user'@'%'
    IDENTIFIED BY 'SecureP@ss!'
    REQUIRE ISSUER '/CN=MySQL CA'
    AND SUBJECT '/CN=client.example.com';
```

### Password Policies

```sql
-- Configure password policy
-- In my.cnf or dynamically:
SET GLOBAL validate_password.policy = STRONG;
SET GLOBAL validate_password.length = 14;
SET GLOBAL validate_password.mixed_case_count = 2;
SET GLOBAL validate_password.number_count = 2;
SET GLOBAL validate_password.special_char_count = 2;

-- Check current policy
SHOW VARIABLES LIKE 'validate_password%';

-- Create user with password expiration
CREATE USER 'rotating_user'@'%'
    IDENTIFIED BY 'SecureP@ssw0rd123!'
    PASSWORD EXPIRE INTERVAL 90 DAY;

-- Create user with password history
CREATE USER 'history_user'@'%'
    IDENTIFIED BY 'SecureP@ssw0rd123!'
    PASSWORD HISTORY 5
    PASSWORD REUSE INTERVAL 365 DAY;

-- Create user with failed login tracking
CREATE USER 'lockout_user'@'%'
    IDENTIFIED BY 'SecureP@ssw0rd123!'
    FAILED_LOGIN_ATTEMPTS 3
    PASSWORD_LOCK_TIME 1;  -- days

-- Unlock locked account
ALTER USER 'lockout_user'@'%' ACCOUNT UNLOCK;

-- Check account status
SELECT user, host, account_locked, password_expired,
       password_last_changed, password_lifetime
FROM mysql.user;
```

### Multi-Factor Authentication (MySQL 8.0.27+)

```sql
-- Enable MFA for user
ALTER USER 'secure_user'@'%'
    IDENTIFIED WITH caching_sha2_password BY 'FirstFactor!'
    AND IDENTIFIED WITH authentication_ldap_sasl;

-- Register multiple authentication factors
CREATE USER 'mfa_user'@'%'
    IDENTIFIED WITH caching_sha2_password BY 'Password1!'
    AND IDENTIFIED WITH authentication_fido;
```

### LDAP Authentication (Enterprise)

```ini
# my.cnf
[mysqld]
plugin-load-add = authentication_ldap_sasl.so
plugin-load-add = authentication_ldap_simple.so

authentication_ldap_simple_server_host = ldap.example.com
authentication_ldap_simple_server_port = 389
authentication_ldap_simple_bind_base_dn = 'ou=users,dc=example,dc=com'
authentication_ldap_simple_user_search_attr = uid
```

```sql
-- Create LDAP-authenticated user
CREATE USER 'ldap_user'@'%'
    IDENTIFIED WITH authentication_ldap_simple
    BY 'uid=ldap_user,ou=users,dc=example,dc=com';
```

## Authorization and Privileges

### Privilege Hierarchy

```
Global (*.*)
├── Database (db.*)
│   ├── Table (db.table)
│   │   ├── Column (db.table.column)
│   │   └── (privileges on specific columns)
│   └── Routine (db.routine)
└── Proxy (user@host proxies another)
```

### Available Privileges

```sql
-- View all available privileges
SHOW PRIVILEGES;

-- Common privilege categories:
-- Data Privileges: SELECT, INSERT, UPDATE, DELETE
-- Structure Privileges: CREATE, ALTER, DROP, INDEX
-- Admin Privileges: SUPER, SHUTDOWN, RELOAD, PROCESS
-- Replication: REPLICATION SLAVE, REPLICATION CLIENT
-- Security: CREATE USER, GRANT OPTION
```

### Granting Privileges

```sql
-- Grant specific privileges on database
GRANT SELECT, INSERT, UPDATE, DELETE ON myapp.* TO 'app_user'@'10.0.0.%';

-- Grant with column-level restrictions
GRANT SELECT (id, name, email),
      UPDATE (email, preferences)
ON myapp.users TO 'limited_user'@'%';

-- Grant all on specific database (avoid on production)
GRANT ALL PRIVILEGES ON myapp.* TO 'admin_user'@'localhost';

-- Grant global privileges (use sparingly)
GRANT PROCESS, REPLICATION CLIENT ON *.* TO 'monitoring'@'%';

-- Grant ability to grant to others
GRANT SELECT ON myapp.* TO 'team_lead'@'%' WITH GRANT OPTION;

-- Grant proxy privilege
GRANT PROXY ON 'admin_user'@'localhost' TO 'delegate'@'localhost';
```

### Role-Based Access Control (MySQL 8.0+)

```sql
-- Create roles
CREATE ROLE 'app_read', 'app_write', 'app_admin';

-- Assign privileges to roles
GRANT SELECT ON myapp.* TO 'app_read';
GRANT INSERT, UPDATE, DELETE ON myapp.* TO 'app_write';
GRANT ALL PRIVILEGES ON myapp.* TO 'app_admin';

-- Grant roles to users
GRANT 'app_read' TO 'analyst'@'%';
GRANT 'app_read', 'app_write' TO 'developer'@'%';
GRANT 'app_admin' TO 'dba'@'localhost';

-- Set default role
SET DEFAULT ROLE 'app_read' TO 'analyst'@'%';
SET DEFAULT ROLE ALL TO 'developer'@'%';

-- Activate role in session
SET ROLE 'app_write';
SET ROLE ALL;
SET ROLE NONE;

-- Check current roles
SELECT CURRENT_ROLE();

-- View role assignments
SELECT * FROM mysql.role_edges;

-- View roles granted to current user
SHOW GRANTS;
```

### Least Privilege Patterns

```sql
-- Application user: CRUD on specific tables
CREATE USER 'myapp'@'10.0.%.%'
    IDENTIFIED BY 'AppP@ssw0rd!'
    PASSWORD EXPIRE NEVER;

GRANT SELECT, INSERT, UPDATE, DELETE
ON myapp.users TO 'myapp'@'10.0.%.%';

GRANT SELECT, INSERT, UPDATE, DELETE
ON myapp.orders TO 'myapp'@'10.0.%.%';

GRANT SELECT ON myapp.products TO 'myapp'@'10.0.%.%';

-- Read-only reporting user
CREATE USER 'reporting'@'%'
    IDENTIFIED BY 'ReportP@ss!'
    REQUIRE SSL;

GRANT SELECT ON myapp.* TO 'reporting'@'%';
GRANT SELECT ON analytics.* TO 'reporting'@'%';

-- Backup user (minimal for backups)
CREATE USER 'backup'@'localhost'
    IDENTIFIED BY 'BackupP@ss!';

GRANT SELECT, RELOAD, LOCK TABLES, REPLICATION CLIENT,
      SHOW VIEW, EVENT, TRIGGER, BACKUP_ADMIN
ON *.* TO 'backup'@'localhost';

-- Monitoring user
CREATE USER 'monitoring'@'10.0.0.%'
    IDENTIFIED BY 'MonitorP@ss!';

GRANT PROCESS, REPLICATION CLIENT ON *.* TO 'monitoring'@'10.0.0.%';
GRANT SELECT ON performance_schema.* TO 'monitoring'@'10.0.0.%';
GRANT SELECT ON sys.* TO 'monitoring'@'10.0.0.%';

-- Replication user
CREATE USER 'repl'@'10.0.0.%'
    IDENTIFIED BY 'ReplP@ss!'
    REQUIRE SSL;

GRANT REPLICATION SLAVE ON *.* TO 'repl'@'10.0.0.%';
```

### Auditing Privileges

```sql
-- Show grants for specific user
SHOW GRANTS FOR 'app_user'@'%';

-- Show all users and their hosts
SELECT user, host FROM mysql.user ORDER BY user;

-- Find users with dangerous privileges
SELECT user, host
FROM mysql.user
WHERE Super_priv = 'Y'
   OR Grant_priv = 'Y'
   OR File_priv = 'Y';

-- Find users with global privileges
SELECT user, host, Select_priv, Insert_priv, Update_priv, Delete_priv
FROM mysql.user
WHERE Select_priv = 'Y' OR Insert_priv = 'Y';

-- List all database-level grants
SELECT * FROM mysql.db WHERE user != '' ORDER BY user, db;

-- Check for users without password
SELECT user, host FROM mysql.user
WHERE authentication_string = '' OR authentication_string IS NULL;

-- Check for users with wildcard hosts
SELECT user, host FROM mysql.user WHERE host = '%';
```

### Revoking Privileges

```sql
-- Revoke specific privileges
REVOKE INSERT, UPDATE ON myapp.* FROM 'user'@'%';

-- Revoke all privileges
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'user'@'%';

-- Revoke role
REVOKE 'app_write' FROM 'user'@'%';

-- Drop user entirely
DROP USER 'user'@'%';

-- Always flush after changes
FLUSH PRIVILEGES;
```

## Encryption

### Encryption at Rest (InnoDB)

#### Tablespace Encryption

```ini
# my.cnf
[mysqld]
# Enable keyring plugin (file-based for non-production)
early-plugin-load = keyring_file.so
keyring_file_data = /var/lib/mysql-keyring/keyring

# Enable default table encryption
default_table_encryption = ON

# Encrypt binary logs and relay logs
binlog_encryption = ON

# Encrypt redo and undo logs
innodb_redo_log_encrypt = ON
innodb_undo_log_encrypt = ON
```

```sql
-- Create encrypted table
CREATE TABLE sensitive_data (
    id INT PRIMARY KEY,
    ssn VARCHAR(11),
    credit_card VARCHAR(16)
) ENCRYPTION = 'Y';

-- Encrypt existing table
ALTER TABLE existing_table ENCRYPTION = 'Y';

-- Encrypt tablespace
ALTER TABLESPACE my_tablespace ENCRYPTION = 'Y';

-- Encrypt system tablespace
ALTER TABLESPACE mysql ENCRYPTION = 'Y';

-- Check encryption status
SELECT TABLE_SCHEMA, TABLE_NAME, CREATE_OPTIONS
FROM information_schema.TABLES
WHERE CREATE_OPTIONS LIKE '%ENCRYPTION%';

-- Check tablespace encryption
SELECT SPACE, NAME, FLAG, ENCRYPTION
FROM information_schema.INNODB_TABLESPACES
WHERE ENCRYPTION = 'Y';
```

#### Using AWS KMS for Key Management

```ini
# my.cnf for AWS KMS integration
[mysqld]
early-plugin-load = keyring_aws.so
keyring_aws_conf_file = /etc/mysql/keyring_aws.conf
keyring_aws_data_file = /var/lib/mysql-keyring/keyring_aws_data
```

```ini
# /etc/mysql/keyring_aws.conf
[keyring_aws]
region = us-east-1
kms_key_id = alias/mysql-encryption-key
```

#### HashiCorp Vault Integration

```ini
# my.cnf for Vault integration
[mysqld]
early-plugin-load = keyring_hashicorp.so
keyring_hashicorp_server_url = https://vault.example.com:8200
keyring_hashicorp_token = s.xxxxxxxxxxxxxxxxxxxxxxxx
keyring_hashicorp_secret_mount_point = secret
keyring_hashicorp_store_path = mysql/encryption_keys
```

### Encryption in Transit (SSL/TLS)

#### Generating SSL Certificates

```bash
#!/bin/bash
# Generate MySQL SSL certificates

CERT_DIR="/var/lib/mysql-ssl"
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

# Generate CA key and certificate
openssl genrsa 4096 > ca-key.pem
openssl req -new -x509 -nodes -days 3650 -key ca-key.pem \
    -out ca-cert.pem -subj "/CN=MySQL CA"

# Generate server key and certificate
openssl req -newkey rsa:4096 -nodes -keyout server-key.pem \
    -out server-req.pem -subj "/CN=mysql-server.example.com"
openssl x509 -req -days 3650 -in server-req.pem \
    -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial \
    -out server-cert.pem

# Generate client key and certificate
openssl req -newkey rsa:4096 -nodes -keyout client-key.pem \
    -out client-req.pem -subj "/CN=mysql-client"
openssl x509 -req -days 3650 -in client-req.pem \
    -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial \
    -out client-cert.pem

# Set permissions
chmod 600 *.pem
chown mysql:mysql *.pem
```

#### Configuring SSL on Server

```ini
# my.cnf
[mysqld]
# SSL certificate paths
ssl_ca = /var/lib/mysql-ssl/ca-cert.pem
ssl_cert = /var/lib/mysql-ssl/server-cert.pem
ssl_key = /var/lib/mysql-ssl/server-key.pem

# Require SSL for all connections
require_secure_transport = ON

# TLS version restrictions
tls_version = TLSv1.2,TLSv1.3

# Cipher suite (TLS 1.2)
ssl_cipher = ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256

# TLS 1.3 cipher suites
tls_ciphersuites = TLS_AES_256_GCM_SHA384:TLS_AES_128_GCM_SHA256

# Verify client certificates (optional)
# ssl_verify_server_cert = ON
```

#### Configuring SSL for Client

```ini
# ~/.my.cnf for client
[client]
ssl_ca = /path/to/ca-cert.pem
ssl_cert = /path/to/client-cert.pem
ssl_key = /path/to/client-key.pem
ssl_mode = VERIFY_IDENTITY
```

#### Verifying SSL Configuration

```sql
-- Check SSL status
SHOW VARIABLES LIKE '%ssl%';
SHOW VARIABLES LIKE '%tls%';

-- Check if current connection uses SSL
SHOW STATUS LIKE 'Ssl_cipher';
SHOW STATUS LIKE 'Ssl_version';

-- View SSL session details
SELECT * FROM performance_schema.session_status
WHERE VARIABLE_NAME LIKE 'Ssl%';

-- Check which users require SSL
SELECT user, host, ssl_type FROM mysql.user WHERE ssl_type != '';
```

### Aurora MySQL Encryption

Aurora handles encryption differently as a managed service:

```bash
# Create encrypted Aurora cluster
aws rds create-db-cluster \
    --db-cluster-identifier my-encrypted-cluster \
    --engine aurora-mysql \
    --engine-version 8.0.mysql_aurora.3.04.0 \
    --master-username admin \
    --master-user-password 'SecurePassword123!' \
    --storage-encrypted \
    --kms-key-id alias/aurora-encryption-key

# Enable SSL enforcement
aws rds modify-db-cluster \
    --db-cluster-identifier my-cluster \
    --apply-immediately \
    --db-cluster-parameter-group-name ssl-required-group
```

```sql
-- Aurora: Force SSL connections via parameter group
-- Set 'require_secure_transport' = 1 in cluster parameter group

-- Verify SSL is being used
SELECT ssl_cipher FROM performance_schema.status_by_thread
WHERE thread_id = (SELECT THREAD_ID FROM performance_schema.threads
                   WHERE PROCESSLIST_ID = CONNECTION_ID());
```

## Audit Logging

### MySQL Enterprise Audit (Commercial)

```ini
# my.cnf
[mysqld]
plugin-load = audit_log.so
audit_log_file = /var/log/mysql/audit.log
audit_log_format = JSON
audit_log_policy = ALL
audit_log_rotate_on_size = 1073741824  # 1GB
```

### Using the sys schema for Auditing

```sql
-- Enable statement history (performance_schema)
UPDATE performance_schema.setup_consumers
SET ENABLED = 'YES'
WHERE NAME = 'events_statements_history';

UPDATE performance_schema.setup_consumers
SET ENABLED = 'YES'
WHERE NAME = 'events_statements_history_long';

-- View recent queries
SELECT * FROM performance_schema.events_statements_history_long
ORDER BY TIMER_START DESC LIMIT 100;

-- Track login attempts
SELECT * FROM performance_schema.host_cache;

-- Track connection errors
SELECT * FROM performance_schema.accounts;
```

### MariaDB Audit Plugin (Open Source Alternative)

```ini
# my.cnf (works with MySQL too)
[mysqld]
plugin-load-add = server_audit=server_audit.so
server_audit = FORCE_PLUS_PERMANENT
server_audit_logging = ON
server_audit_events = CONNECT,QUERY_DDL,QUERY_DML
server_audit_file_path = /var/log/mysql/audit.log
server_audit_file_rotate_size = 1073741824
server_audit_file_rotations = 10
server_audit_incl_users = app_user,admin_user
server_audit_excl_users = monitoring
```

### Percona Audit Log Plugin

```ini
# my.cnf
[mysqld]
plugin-load = audit_log.so
audit_log_file = /var/log/mysql/audit.log
audit_log_format = JSON
audit_log_policy = QUERIES
audit_log_rotate_on_size = 1073741824
```

### Custom Audit Logging with Triggers

```sql
-- Create audit table
CREATE TABLE audit_log (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(64),
    action_type ENUM('INSERT', 'UPDATE', 'DELETE'),
    old_values JSON,
    new_values JSON,
    user VARCHAR(100),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_table_time (table_name, timestamp)
) ENGINE=InnoDB;

-- Create audit trigger for sensitive table
DELIMITER $$

CREATE TRIGGER users_audit_insert
AFTER INSERT ON users
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action_type, new_values, user)
    VALUES ('users', 'INSERT',
            JSON_OBJECT('id', NEW.id, 'email', NEW.email, 'name', NEW.name),
            CURRENT_USER());
END$$

CREATE TRIGGER users_audit_update
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action_type, old_values, new_values, user)
    VALUES ('users', 'UPDATE',
            JSON_OBJECT('id', OLD.id, 'email', OLD.email, 'name', OLD.name),
            JSON_OBJECT('id', NEW.id, 'email', NEW.email, 'name', NEW.name),
            CURRENT_USER());
END$$

CREATE TRIGGER users_audit_delete
AFTER DELETE ON users
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action_type, old_values, user)
    VALUES ('users', 'DELETE',
            JSON_OBJECT('id', OLD.id, 'email', OLD.email, 'name', OLD.name),
            CURRENT_USER());
END$$

DELIMITER ;
```

### CloudWatch Integration for Aurora

```bash
# Enable audit logs export to CloudWatch
aws rds modify-db-cluster \
    --db-cluster-identifier my-cluster \
    --cloudwatch-logs-export-configuration \
    EnableLogTypes=["audit","error","general","slowquery"]

# Create CloudWatch alarm for suspicious activity
aws cloudwatch put-metric-alarm \
    --alarm-name mysql-failed-logins \
    --metric-name LoginFailures \
    --namespace MySQL \
    --statistic Sum \
    --period 300 \
    --threshold 10 \
    --comparison-operator GreaterThanThreshold \
    --alarm-actions arn:aws:sns:us-east-1:123456789012:security-alerts
```

## Network Security

### Binding to Specific Interface

```ini
# my.cnf
[mysqld]
# Bind to specific IP
bind_address = 10.0.0.50

# Bind to localhost only (local connections)
bind_address = 127.0.0.1

# Bind to all interfaces (default)
bind_address = 0.0.0.0

# Bind to multiple addresses (MySQL 8.0.13+)
bind_address = 127.0.0.1,10.0.0.50
```

### Skip Networking (Local Only)

```ini
# my.cnf
[mysqld]
# Disable TCP/IP (only Unix socket)
skip_networking = ON
socket = /var/run/mysqld/mysqld.sock
```

### Firewall Rules (iptables)

```bash
#!/bin/bash
# MySQL firewall rules

# Allow MySQL from specific subnet
iptables -A INPUT -p tcp --dport 3306 -s 10.0.0.0/24 -j ACCEPT

# Allow from specific hosts
iptables -A INPUT -p tcp --dport 3306 -s 10.0.0.100 -j ACCEPT
iptables -A INPUT -p tcp --dport 3306 -s 10.0.0.101 -j ACCEPT

# Deny all other MySQL connections
iptables -A INPUT -p tcp --dport 3306 -j DROP

# Save rules
iptables-save > /etc/iptables/rules.v4
```

### AWS Security Groups for Aurora

```bash
# Create security group for Aurora
aws ec2 create-security-group \
    --group-name aurora-mysql-sg \
    --description "Security group for Aurora MySQL" \
    --vpc-id vpc-12345678

# Allow access from application servers
aws ec2 authorize-security-group-ingress \
    --group-id sg-aurora123 \
    --protocol tcp \
    --port 3306 \
    --source-group sg-app-servers

# Allow access from specific CIDR
aws ec2 authorize-security-group-ingress \
    --group-id sg-aurora123 \
    --protocol tcp \
    --port 3306 \
    --cidr 10.0.1.0/24
```

### IAM Database Authentication (Aurora)

```bash
# Enable IAM authentication
aws rds modify-db-cluster \
    --db-cluster-identifier my-cluster \
    --enable-iam-database-authentication

# Create IAM policy for database access
cat > db-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "rds-db:connect"
            ],
            "Resource": [
                "arn:aws:rds-db:us-east-1:123456789012:dbuser:cluster-xxxxx/db_user"
            ]
        }
    ]
}
EOF

aws iam create-policy \
    --policy-name AuroraDBAccess \
    --policy-document file://db-policy.json
```

```sql
-- Create database user for IAM authentication
CREATE USER 'db_user'@'%' IDENTIFIED WITH AWSAuthenticationPlugin AS 'RDS';
GRANT SELECT, INSERT, UPDATE, DELETE ON mydb.* TO 'db_user'@'%';
```

```python
# Python: Connect using IAM authentication
import boto3
import mysql.connector

rds_client = boto3.client('rds')

# Generate authentication token
token = rds_client.generate_db_auth_token(
    DBHostname='my-cluster.cluster-xxxxx.us-east-1.rds.amazonaws.com',
    Port=3306,
    DBUsername='db_user',
    Region='us-east-1'
)

# Connect with token as password
conn = mysql.connector.connect(
    host='my-cluster.cluster-xxxxx.us-east-1.rds.amazonaws.com',
    user='db_user',
    password=token,
    database='mydb',
    ssl_ca='/path/to/rds-ca-cert.pem'
)
```

## Security Hardening Checklist

### Installation Hardening

```bash
# Run MySQL secure installation
mysql_secure_installation

# This will:
# - Set root password
# - Remove anonymous users
# - Disable remote root login
# - Remove test database
# - Reload privilege tables
```

### Configuration Hardening

```ini
# my.cnf security settings
[mysqld]
# Disable dangerous features
local_infile = OFF
symbolic_links = OFF
skip_show_database = ON

# Require secure transport
require_secure_transport = ON

# Disable dangerous commands for non-admin users
# (Requires creating limited users)

# Set secure file permissions
secure_file_priv = /var/lib/mysql-files

# Disable LOAD DATA LOCAL
local_infile = 0

# Connection limits
max_connections = 500
max_user_connections = 50
max_connect_errors = 10000
wait_timeout = 28800
interactive_timeout = 28800

# Password policy
validate_password.policy = STRONG
validate_password.length = 14
```

### User Hardening

```sql
-- Remove default accounts
DROP USER IF EXISTS ''@'localhost';
DROP USER IF EXISTS ''@'%';
DROP USER IF EXISTS 'root'@'%';

-- Rename root user (optional)
RENAME USER 'root'@'localhost' TO 'db_admin'@'localhost';

-- Set strong root password
ALTER USER 'root'@'localhost'
    IDENTIFIED BY 'VeryStr0ng&SecureP@ssword!';

-- Remove test database
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db LIKE 'test%';
FLUSH PRIVILEGES;

-- Verify no anonymous users
SELECT user, host FROM mysql.user WHERE user = '';

-- Verify no users with wildcard host
SELECT user, host FROM mysql.user WHERE host = '%';
```

### File System Hardening

```bash
# Set proper permissions on data directory
chown -R mysql:mysql /var/lib/mysql
chmod 750 /var/lib/mysql
chmod 640 /var/lib/mysql/mysql/*

# Set proper permissions on configuration
chmod 644 /etc/mysql/my.cnf
chown root:root /etc/mysql/my.cnf

# Protect binary logs
chmod 750 /var/log/mysql
chmod 640 /var/log/mysql/*

# Protect SSL certificates
chmod 600 /var/lib/mysql-ssl/*.pem
chown mysql:mysql /var/lib/mysql-ssl/*.pem
```

## SQL Injection Prevention

### Input Validation Best Practices

```sql
-- WRONG: String concatenation
SET @sql = CONCAT('SELECT * FROM users WHERE id = ', user_input);
PREPARE stmt FROM @sql;
EXECUTE stmt;

-- RIGHT: Parameterized queries
SET @user_id = user_input;
PREPARE stmt FROM 'SELECT * FROM users WHERE id = ?';
EXECUTE stmt USING @user_id;
DEALLOCATE PREPARE stmt;
```

### Application-Level Prevention

```python
# Python with mysql-connector - CORRECT (parameterized)
cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))

# Python with mysql-connector - WRONG (string format)
cursor.execute(f"SELECT * FROM users WHERE id = {user_id}")  # VULNERABLE!
```

```java
// Java - CORRECT (PreparedStatement)
PreparedStatement stmt = conn.prepareStatement("SELECT * FROM users WHERE id = ?");
stmt.setInt(1, userId);
ResultSet rs = stmt.executeQuery();

// Java - WRONG (String concatenation)
Statement stmt = conn.createStatement();
ResultSet rs = stmt.executeQuery("SELECT * FROM users WHERE id = " + userId);  // VULNERABLE!
```

### Stored Procedure Security

```sql
-- Secure stored procedure with input validation
DELIMITER $$

CREATE PROCEDURE get_user_secure(IN p_user_id INT)
BEGIN
    -- Validate input
    IF p_user_id IS NULL OR p_user_id < 1 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid user ID';
    END IF;

    -- Parameterized query (safe)
    SELECT id, username, email
    FROM users
    WHERE id = p_user_id;
END$$

DELIMITER ;

-- Grant execute only (no direct table access)
GRANT EXECUTE ON PROCEDURE myapp.get_user_secure TO 'app_user'@'%';
```

## Compliance Considerations

### PCI-DSS Requirements

```sql
-- Requirement 8.2.3: Passwords must meet complexity
-- Configure validate_password plugin

-- Requirement 8.2.4: Change passwords at least every 90 days
CREATE USER 'pci_user'@'%'
    IDENTIFIED BY 'ComplexP@ssw0rd!'
    PASSWORD EXPIRE INTERVAL 90 DAY;

-- Requirement 8.5: Do not use group, shared, or generic accounts
-- Create individual accounts per user

-- Requirement 8.6: Limit repeated access attempts
CREATE USER 'pci_user'@'%'
    IDENTIFIED BY 'ComplexP@ssw0rd!'
    FAILED_LOGIN_ATTEMPTS 6
    PASSWORD_LOCK_TIME UNBOUNDED;

-- Requirement 10.2: Implement audit trails
-- Enable audit logging
```

### GDPR Requirements

```sql
-- Right to erasure (deletion)
-- Create procedure for user data deletion
DELIMITER $$

CREATE PROCEDURE delete_user_data(IN p_user_id INT)
BEGIN
    START TRANSACTION;

    -- Delete personal data but keep audit trail
    DELETE FROM user_preferences WHERE user_id = p_user_id;
    DELETE FROM user_addresses WHERE user_id = p_user_id;
    DELETE FROM user_payment_methods WHERE user_id = p_user_id;

    -- Anonymize user record (keep for referential integrity)
    UPDATE users
    SET email = CONCAT('deleted_', p_user_id, '@example.com'),
        name = 'Deleted User',
        phone = NULL,
        deleted_at = NOW()
    WHERE id = p_user_id;

    COMMIT;

    -- Log the deletion
    INSERT INTO audit_log (action, user_id, timestamp)
    VALUES ('GDPR_DELETION', p_user_id, NOW());
END$$

DELIMITER ;

-- Right to access (data export)
CREATE PROCEDURE export_user_data(IN p_user_id INT)
BEGIN
    SELECT
        u.id, u.email, u.name, u.phone, u.created_at,
        a.street, a.city, a.country,
        p.preference_key, p.preference_value
    FROM users u
    LEFT JOIN user_addresses a ON u.id = a.user_id
    LEFT JOIN user_preferences p ON u.id = p.user_id
    WHERE u.id = p_user_id;
END$$
```

### SOC 2 Requirements

```sql
-- Logical access controls
-- Document all user access

-- Access review query
SELECT
    u.user, u.host,
    db.db,
    db.Select_priv, db.Insert_priv, db.Update_priv, db.Delete_priv
FROM mysql.user u
LEFT JOIN mysql.db db ON u.user = db.user
ORDER BY u.user;

-- Connection logging
SET GLOBAL general_log = ON;
SET GLOBAL general_log_file = '/var/log/mysql/general.log';

-- Failed login monitoring (from performance_schema)
SELECT
    HOST,
    COUNT_HANDSHAKE_ERRORS,
    COUNT_AUTHENTICATION_ERRORS,
    COUNT_SSL_ERRORS
FROM performance_schema.host_cache
WHERE COUNT_AUTHENTICATION_ERRORS > 0;
```

## Security Monitoring Scripts

### Daily Security Check Script

```bash
#!/bin/bash
# MySQL daily security check

MYSQL_USER="security_audit"
MYSQL_PASS="AuditP@ss!"
OUTPUT_FILE="/var/log/mysql/security_audit_$(date +%Y%m%d).log"

echo "MySQL Security Audit - $(date)" > "$OUTPUT_FILE"
echo "================================" >> "$OUTPUT_FILE"

# Check for users without passwords
echo -e "\n## Users Without Passwords ##" >> "$OUTPUT_FILE"
mysql -u"$MYSQL_USER" -p"$MYSQL_PASS" -N -e "
SELECT user, host FROM mysql.user
WHERE authentication_string = '' OR authentication_string IS NULL;
" >> "$OUTPUT_FILE"

# Check for users with wildcard hosts
echo -e "\n## Users With Wildcard Hosts ##" >> "$OUTPUT_FILE"
mysql -u"$MYSQL_USER" -p"$MYSQL_PASS" -N -e "
SELECT user, host FROM mysql.user WHERE host = '%';
" >> "$OUTPUT_FILE"

# Check for users with SUPER privilege
echo -e "\n## Users With SUPER Privilege ##" >> "$OUTPUT_FILE"
mysql -u"$MYSQL_USER" -p"$MYSQL_PASS" -N -e "
SELECT user, host FROM mysql.user WHERE Super_priv = 'Y';
" >> "$OUTPUT_FILE"

# Check for expired passwords
echo -e "\n## Users With Expired Passwords ##" >> "$OUTPUT_FILE"
mysql -u"$MYSQL_USER" -p"$MYSQL_PASS" -N -e "
SELECT user, host, password_expired FROM mysql.user
WHERE password_expired = 'Y';
" >> "$OUTPUT_FILE"

# Check SSL configuration
echo -e "\n## SSL Configuration ##" >> "$OUTPUT_FILE"
mysql -u"$MYSQL_USER" -p"$MYSQL_PASS" -N -e "
SHOW VARIABLES LIKE '%ssl%';
" >> "$OUTPUT_FILE"

# Check for recent failed logins
echo -e "\n## Recent Failed Logins ##" >> "$OUTPUT_FILE"
mysql -u"$MYSQL_USER" -p"$MYSQL_PASS" -N -e "
SELECT HOST, COUNT_AUTHENTICATION_ERRORS
FROM performance_schema.host_cache
WHERE COUNT_AUTHENTICATION_ERRORS > 0;
" >> "$OUTPUT_FILE"

# Check file permissions
echo -e "\n## Critical File Permissions ##" >> "$OUTPUT_FILE"
ls -la /var/lib/mysql/*.pem 2>/dev/null >> "$OUTPUT_FILE"
ls -la /etc/mysql/my.cnf >> "$OUTPUT_FILE"

echo -e "\nAudit complete. Report: $OUTPUT_FILE"
```

### Real-Time Alert Script

```bash
#!/bin/bash
# Monitor for security events

THRESHOLD_FAILED_LOGINS=5
SLACK_WEBHOOK="https://hooks.slack.com/services/xxx/yyy/zzz"

while true; do
    # Check for failed logins
    failed=$(mysql -N -e "
        SELECT SUM(COUNT_AUTHENTICATION_ERRORS)
        FROM performance_schema.host_cache;
    ")

    if [ "$failed" -gt "$THRESHOLD_FAILED_LOGINS" ]; then
        message="ALERT: $failed failed MySQL login attempts detected"
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"$message\"}" \
            "$SLACK_WEBHOOK"
    fi

    sleep 60
done
```

## Best Practices Summary

### Security Checklist

1. **Authentication**
   - [ ] Use strong passwords (14+ chars, complexity)
   - [ ] Enable password expiration (90 days max)
   - [ ] Implement account lockout policy
   - [ ] Remove default/anonymous accounts
   - [ ] Use caching_sha2_password plugin

2. **Authorization**
   - [ ] Follow least privilege principle
   - [ ] Use roles for permission management
   - [ ] Regular privilege audits
   - [ ] No wildcard hosts in production
   - [ ] Separate accounts per application

3. **Encryption**
   - [ ] Enable SSL/TLS for connections
   - [ ] Require secure transport
   - [ ] Encrypt sensitive tables at rest
   - [ ] Use strong cipher suites
   - [ ] Rotate encryption keys

4. **Auditing**
   - [ ] Enable audit logging
   - [ ] Log all DDL statements
   - [ ] Log failed authentications
   - [ ] Regular audit log review
   - [ ] Secure audit log storage

5. **Network**
   - [ ] Bind to specific interfaces
   - [ ] Use firewall rules
   - [ ] Limit connection sources
   - [ ] Use VPC/private networks
   - [ ] Disable skip-networking only if needed

6. **Monitoring**
   - [ ] Alert on failed logins
   - [ ] Monitor privilege changes
   - [ ] Track user creation/deletion
   - [ ] Monitor for unusual queries
   - [ ] Regular security scans

## Reference Commands

### Quick Reference

```sql
-- View users and authentication
SELECT user, host, plugin, authentication_string FROM mysql.user;

-- Check user privileges
SHOW GRANTS FOR 'user'@'host';

-- Create secure user
CREATE USER 'user'@'host'
    IDENTIFIED BY 'StrongPassword!'
    REQUIRE SSL
    PASSWORD EXPIRE INTERVAL 90 DAY
    FAILED_LOGIN_ATTEMPTS 3 PASSWORD_LOCK_TIME 1;

-- Grant specific privileges
GRANT SELECT, INSERT ON db.* TO 'user'@'host';

-- Revoke privileges
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'user'@'host';

-- Check SSL status
SHOW STATUS LIKE 'Ssl_cipher';

-- View audit logs
SELECT * FROM mysql.general_log ORDER BY event_time DESC LIMIT 100;

-- Check encryption status
SELECT * FROM information_schema.INNODB_TABLESPACES WHERE ENCRYPTION = 'Y';
```

## Security Incident Response

### Detecting Unauthorized Access

```sql
-- Check for recent login attempts
SELECT * FROM performance_schema.host_cache
WHERE COUNT_AUTHENTICATION_ERRORS > 0;

-- Check for unusual connection patterns
SELECT
    USER,
    HOST,
    COUNT(*) AS connection_count,
    MAX(TIME) AS longest_connection
FROM information_schema.processlist
GROUP BY USER, HOST
ORDER BY connection_count DESC;

-- Check for new users created recently
SELECT user, host, password_last_changed
FROM mysql.user
ORDER BY password_last_changed DESC;

-- Check for privilege escalations
SELECT * FROM mysql.user WHERE Super_priv = 'Y';
SELECT * FROM mysql.user WHERE Grant_priv = 'Y';
SELECT * FROM mysql.user WHERE File_priv = 'Y';

-- Check for unusual database access
SELECT
    OBJECT_SCHEMA,
    OBJECT_NAME,
    COUNT_READ,
    COUNT_WRITE
FROM performance_schema.table_io_waits_summary_by_table
WHERE OBJECT_SCHEMA NOT IN ('mysql', 'performance_schema', 'sys', 'information_schema')
ORDER BY COUNT_READ + COUNT_WRITE DESC
LIMIT 20;
```

### Response Procedures

```bash
#!/bin/bash
# Security incident response script

MYSQL_USER="root"
INCIDENT_LOG="/var/log/mysql/security_incident_$(date +%Y%m%d_%H%M%S).log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$INCIDENT_LOG"
}

mysql_query() {
    mysql -u"$MYSQL_USER" -N -e "$1" 2>/dev/null
}

log "=== Security Incident Response Started ==="

# Step 1: Capture current state
log "Capturing current connection state..."
mysql -e "SHOW PROCESSLIST" >> "$INCIDENT_LOG"

log "Capturing user accounts..."
mysql -e "SELECT user, host, plugin, authentication_string FROM mysql.user" >> "$INCIDENT_LOG"

log "Capturing privilege grants..."
for user_host in $(mysql_query "SELECT CONCAT(user, '@', host) FROM mysql.user"); do
    log "Grants for $user_host:"
    mysql -e "SHOW GRANTS FOR $user_host" >> "$INCIDENT_LOG" 2>/dev/null
done

# Step 2: Lock suspicious accounts
log "Enter username to lock (or 'skip' to skip):"
read suspicious_user

if [ "$suspicious_user" != "skip" ]; then
    log "Locking account: $suspicious_user"
    mysql -e "ALTER USER '$suspicious_user'@'%' ACCOUNT LOCK;"
    mysql -e "KILL CONNECTION ALL WHERE USER = '$suspicious_user';" 2>/dev/null
fi

# Step 3: Check for suspicious queries
log "Checking recent queries for suspicious patterns..."
mysql -e "
SELECT
    DIGEST_TEXT,
    COUNT_STAR,
    SUM_ROWS_AFFECTED
FROM performance_schema.events_statements_summary_by_digest
WHERE DIGEST_TEXT LIKE '%DROP%'
   OR DIGEST_TEXT LIKE '%GRANT%'
   OR DIGEST_TEXT LIKE '%CREATE USER%'
   OR DIGEST_TEXT LIKE '%INTO OUTFILE%'
ORDER BY LAST_SEEN DESC
LIMIT 50;
" >> "$INCIDENT_LOG"

# Step 4: Export binary logs for forensics
log "Exporting recent binary logs..."
BINLOG_DIR="/var/log/mysql"
FORENSIC_DIR="/var/log/mysql/forensic_$(date +%Y%m%d)"
mkdir -p "$FORENSIC_DIR"

for binlog in $(ls -t "$BINLOG_DIR"/mysql-bin.* | head -5); do
    cp "$binlog" "$FORENSIC_DIR/"
done

log "=== Incident Response Data Collected ==="
log "Report saved to: $INCIDENT_LOG"
log "Binary logs saved to: $FORENSIC_DIR"
```

### Blocking Suspicious IP Addresses

```bash
#!/bin/bash
# Block IP addresses with too many failed login attempts

THRESHOLD=10
BLOCK_DURATION=86400  # 24 hours

# Get IPs with failed logins above threshold
ips=$(mysql -N -e "
SELECT IP
FROM performance_schema.host_cache
WHERE COUNT_AUTHENTICATION_ERRORS > $THRESHOLD
")

for ip in $ips; do
    echo "Blocking IP: $ip"
    # Using iptables
    iptables -A INPUT -s "$ip" -p tcp --dport 3306 -j DROP

    # Or using firewalld
    # firewall-cmd --add-rich-rule="rule family='ipv4' source address='$ip' port port=3306 protocol=tcp reject"
done

# Schedule unblock after duration
echo "iptables -D INPUT -s $ip -p tcp --dport 3306 -j DROP" | at now + "$BLOCK_DURATION" seconds
```

## Database Activity Monitoring (DAM)

### Implementing Basic DAM

```sql
-- Create activity log table
CREATE TABLE security.activity_log (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    event_time DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
    user VARCHAR(100),
    host VARCHAR(255),
    db VARCHAR(64),
    command_type VARCHAR(64),
    query_text TEXT,
    rows_affected INT,
    INDEX idx_time (event_time),
    INDEX idx_user (user),
    INDEX idx_db (db)
) ENGINE=InnoDB;

-- Create trigger for monitoring specific tables
DELIMITER $$

CREATE TRIGGER tr_sensitive_audit_insert
AFTER INSERT ON sensitive_data
FOR EACH ROW
BEGIN
    INSERT INTO security.activity_log (user, host, db, command_type, query_text, rows_affected)
    VALUES (CURRENT_USER(), @@hostname, DATABASE(), 'INSERT',
            CONCAT('INSERT INTO sensitive_data (id:', NEW.id, ')'), 1);
END$$

CREATE TRIGGER tr_sensitive_audit_update
AFTER UPDATE ON sensitive_data
FOR EACH ROW
BEGIN
    INSERT INTO security.activity_log (user, host, db, command_type, query_text, rows_affected)
    VALUES (CURRENT_USER(), @@hostname, DATABASE(), 'UPDATE',
            CONCAT('UPDATE sensitive_data SET ... WHERE id=', OLD.id), 1);
END$$

CREATE TRIGGER tr_sensitive_audit_delete
AFTER DELETE ON sensitive_data
FOR EACH ROW
BEGIN
    INSERT INTO security.activity_log (user, host, db, command_type, query_text, rows_affected)
    VALUES (CURRENT_USER(), @@hostname, DATABASE(), 'DELETE',
            CONCAT('DELETE FROM sensitive_data WHERE id=', OLD.id), 1);
END$$

DELIMITER ;
```

### Query Analysis for Security

```sql
-- Find queries accessing sensitive tables
SELECT
    DIGEST_TEXT,
    SCHEMA_NAME,
    COUNT_STAR AS exec_count,
    SUM_ROWS_EXAMINED AS total_rows_examined
FROM performance_schema.events_statements_summary_by_digest
WHERE DIGEST_TEXT LIKE '%sensitive%'
   OR DIGEST_TEXT LIKE '%credit_card%'
   OR DIGEST_TEXT LIKE '%ssn%'
   OR DIGEST_TEXT LIKE '%password%'
ORDER BY COUNT_STAR DESC;

-- Find queries with suspicious patterns
SELECT
    DIGEST_TEXT,
    COUNT_STAR AS exec_count
FROM performance_schema.events_statements_summary_by_digest
WHERE DIGEST_TEXT LIKE '%UNION%SELECT%'
   OR DIGEST_TEXT LIKE '%OR%=%'
   OR DIGEST_TEXT LIKE '%BENCHMARK%'
   OR DIGEST_TEXT LIKE '%SLEEP%'
ORDER BY COUNT_STAR DESC;

-- Track schema changes
SELECT
    OBJECT_SCHEMA,
    OBJECT_NAME,
    OBJECT_TYPE,
    EVENT_NAME,
    CURRENT_SCHEMA
FROM performance_schema.events_statements_history_long
WHERE DIGEST_TEXT LIKE '%ALTER%'
   OR DIGEST_TEXT LIKE '%DROP%'
   OR DIGEST_TEXT LIKE '%CREATE%'
ORDER BY TIMER_START DESC
LIMIT 50;
```

## Data Masking and De-identification

### Column-Level Masking Functions

```sql
-- Create masking functions
DELIMITER $$

CREATE FUNCTION mask_email(email VARCHAR(255))
RETURNS VARCHAR(255)
DETERMINISTIC
BEGIN
    DECLARE at_pos INT;
    SET at_pos = INSTR(email, '@');
    IF at_pos > 3 THEN
        RETURN CONCAT(LEFT(email, 2), REPEAT('*', at_pos - 3), SUBSTRING(email, at_pos));
    ELSE
        RETURN CONCAT('***', SUBSTRING(email, at_pos));
    END IF;
END$$

CREATE FUNCTION mask_phone(phone VARCHAR(20))
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    RETURN CONCAT('***-***-', RIGHT(REPLACE(REPLACE(REPLACE(phone, '-', ''), ' ', ''), '(', ''), 4));
END$$

CREATE FUNCTION mask_ssn(ssn VARCHAR(11))
RETURNS VARCHAR(11)
DETERMINISTIC
BEGIN
    RETURN CONCAT('***-**-', RIGHT(REPLACE(ssn, '-', ''), 4));
END$$

CREATE FUNCTION mask_credit_card(cc VARCHAR(20))
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    RETURN CONCAT(REPEAT('*', LENGTH(cc) - 4), RIGHT(cc, 4));
END$$

DELIMITER ;

-- Use masking in views
CREATE VIEW customers_masked AS
SELECT
    id,
    name,
    mask_email(email) AS email,
    mask_phone(phone) AS phone,
    mask_ssn(ssn) AS ssn
FROM customers;

-- Grant access to masked view instead of base table
GRANT SELECT ON customers_masked TO 'support_user'@'%';
```

### Row-Level Security with Views

```sql
-- Create function to get current user's department
CREATE FUNCTION get_user_department()
RETURNS VARCHAR(50)
DETERMINISTIC
BEGIN
    DECLARE dept VARCHAR(50);
    SELECT department INTO dept FROM app_users
    WHERE username = SUBSTRING_INDEX(CURRENT_USER(), '@', 1);
    RETURN COALESCE(dept, 'NONE');
END;

-- Create view with row-level security
CREATE VIEW orders_rls AS
SELECT *
FROM orders
WHERE department = get_user_department()
   OR get_user_department() = 'ADMIN';

-- Grant access to view
GRANT SELECT ON orders_rls TO 'app_user'@'%';
```

## Secure Backup Practices

### Encrypted Backup Script

```bash
#!/bin/bash
# Encrypted backup script

BACKUP_DIR="/backup/mysql"
ENCRYPT_KEY_FILE="/secure/backup.key"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup
mysqldump --all-databases --single-transaction --routines --triggers \
    | openssl enc -aes-256-cbc -salt -pbkdf2 -pass file:"$ENCRYPT_KEY_FILE" \
    > "$BACKUP_DIR/backup_${DATE}.sql.enc"

# Verify encryption
if openssl enc -d -aes-256-cbc -pbkdf2 -pass file:"$ENCRYPT_KEY_FILE" \
    -in "$BACKUP_DIR/backup_${DATE}.sql.enc" | head -1 | grep -q "MySQL"; then
    echo "Backup verified successfully"
else
    echo "ERROR: Backup verification failed"
    exit 1
fi

# Upload to secure storage
aws s3 cp "$BACKUP_DIR/backup_${DATE}.sql.enc" \
    s3://secure-backups/mysql/ \
    --sse aws:kms \
    --sse-kms-key-id alias/backup-key
```

### Secure Backup User

```sql
-- Create backup user with minimal privileges
CREATE USER 'backup'@'localhost'
    IDENTIFIED BY 'SecureBackupP@ss!'
    WITH MAX_QUERIES_PER_HOUR 0
    MAX_UPDATES_PER_HOUR 0
    MAX_CONNECTIONS_PER_HOUR 10
    MAX_USER_CONNECTIONS 2;

-- Grant only required privileges
GRANT SELECT, RELOAD, LOCK TABLES, REPLICATION CLIENT,
      SHOW VIEW, EVENT, TRIGGER, BACKUP_ADMIN
ON *.* TO 'backup'@'localhost';

-- For XtraBackup
GRANT PROCESS, SUPER ON *.* TO 'backup'@'localhost';
```

## Penetration Testing Considerations

### Safe Testing Queries

```sql
-- Test for SQL injection vulnerabilities (in test environment only)
-- These should NOT work if properly configured

-- Test: Can we enumerate users?
SELECT user FROM mysql.user;  -- Should fail for non-privileged users

-- Test: Can we read system files?
SELECT LOAD_FILE('/etc/passwd');  -- Should return NULL

-- Test: Can we write files?
SELECT 'test' INTO OUTFILE '/tmp/test.txt';  -- Should fail

-- Test: Information disclosure
SELECT @@version;  -- Consider hiding version info
SELECT @@datadir;  -- Consider restricting
```

### Security Configuration Verification

```sql
-- Check for dangerous settings
SELECT
    'secure_file_priv' AS setting,
    @@secure_file_priv AS value,
    CASE
        WHEN @@secure_file_priv IS NULL THEN 'DANGEROUS: File I/O unrestricted'
        WHEN @@secure_file_priv = '' THEN 'DANGEROUS: File I/O unrestricted'
        ELSE 'OK: Restricted to specific directory'
    END AS status

UNION ALL

SELECT
    'local_infile',
    @@local_infile,
    CASE WHEN @@local_infile = 0 THEN 'OK: Disabled' ELSE 'WARNING: Enabled' END

UNION ALL

SELECT
    'skip_show_database',
    @@skip_show_database,
    CASE WHEN @@skip_show_database = 1 THEN 'OK: Enabled' ELSE 'WARNING: Disabled' END

UNION ALL

SELECT
    'require_secure_transport',
    @@require_secure_transport,
    CASE WHEN @@require_secure_transport = 1 THEN 'OK: SSL Required' ELSE 'WARNING: SSL Optional' END;
```

## Password Management Tools

### Rotating Service Account Passwords

```bash
#!/bin/bash
# Password rotation script for service accounts

generate_password() {
    openssl rand -base64 32 | tr -dc 'a-zA-Z0-9!@#$%^&*' | head -c 24
}

rotate_password() {
    local user="$1"
    local host="$2"
    local new_pass=$(generate_password)

    echo "Rotating password for ${user}@${host}..."

    # Update MySQL
    mysql -e "ALTER USER '${user}'@'${host}' IDENTIFIED BY '${new_pass}';"

    # Store in secrets manager
    aws secretsmanager put-secret-value \
        --secret-id "mysql/${user}" \
        --secret-string "{\"username\":\"${user}\",\"password\":\"${new_pass}\"}"

    echo "Password rotated successfully"
}

# Rotate service account passwords
rotate_password "app_service" "%"
rotate_password "backup" "localhost"
rotate_password "monitoring" "10.0.0.%"
```

### AWS Secrets Manager Integration

```python
#!/usr/bin/env python3
# MySQL connection with Secrets Manager

import boto3
import json
import mysql.connector
from botocore.exceptions import ClientError

def get_secret(secret_name, region_name="us-east-1"):
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )

    try:
        response = client.get_secret_value(SecretId=secret_name)
        return json.loads(response['SecretString'])
    except ClientError as e:
        raise e

def get_db_connection(secret_name):
    secret = get_secret(secret_name)

    return mysql.connector.connect(
        host=secret['host'],
        user=secret['username'],
        password=secret['password'],
        database=secret.get('database', ''),
        ssl_ca='/path/to/ca-cert.pem'
    )

# Usage
if __name__ == "__main__":
    conn = get_db_connection("prod/mysql/app_service")
    cursor = conn.cursor()
    cursor.execute("SELECT 1")
    print(cursor.fetchone())
    conn.close()
```

## Additional Resources

- [MySQL 8.0 Security Guide](https://dev.mysql.com/doc/refman/8.0/en/security.html)
- [Aurora MySQL Security](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/UsingWithRDS.SSL.html)
- [CIS MySQL Benchmark](https://www.cisecurity.org/benchmark/mysql)
- [OWASP SQL Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)
- [MySQL Enterprise Security Features](https://www.mysql.com/products/enterprise/security.html)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
- [HashiCorp Vault MySQL Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/databases/mysql-maria)
