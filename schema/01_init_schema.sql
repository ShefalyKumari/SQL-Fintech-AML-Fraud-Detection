DROP TABLE IF EXISTS audit_ledger;
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS devices;
DROP TABLE IF EXISTS accounts;

-- 1. Accounts Table (Entity)
CREATE TABLE accounts (
    account_id VARCHAR(16) PRIMARY KEY,
    customer_name VARCHAR(64) NOT NULL,
    account_type VARCHAR(24) NOT NULL CHECK (account_type IN ('Personal', 'Business', 'Merchant')),
    kyc_status VARCHAR(16) NOT NULL CHECK (kyc_status IN ('Verified', 'Tier_1', 'Pending')),
    risk_rating VARCHAR(16) NOT NULL CHECK (risk_rating IN ('Low', 'Medium', 'High')),
    created_at TIMESTAMP NOT NULL
);

-- 2. Devices Table (Access Entity)
CREATE TABLE devices (
    device_id VARCHAR(16) PRIMARY KEY,
    account_id VARCHAR(16) NOT NULL REFERENCES accounts(account_id),
    ip_address VARCHAR(45) NOT NULL,
    device_type VARCHAR(24) NOT NULL,
    geo_country VARCHAR(32) NOT NULL,
    first_seen TIMESTAMP NOT NULL
);

-- 3. Transactions Table (Core Financial Events)
CREATE TABLE transactions (
    transaction_id VARCHAR(16) PRIMARY KEY,
    sender_account_id VARCHAR(16) NOT NULL REFERENCES accounts(account_id),
    receiver_account_id VARCHAR(16) NOT NULL REFERENCES accounts(account_id),
    device_id VARCHAR(16) NOT NULL REFERENCES devices(device_id),
    transaction_timestamp TIMESTAMP NOT NULL,
    amount_usd NUMERIC(12, 2) NOT NULL CHECK (amount_usd > 0),
    transaction_type VARCHAR(24) NOT NULL CHECK (transaction_type IN ('Transfer', 'Deposit', 'Withdrawal', 'Wire')),
    channel VARCHAR(16) NOT NULL CHECK (channel IN ('Mobile', 'Web', 'API', 'ATM'))
);

-- 4. Audit Ledger Table (Regulatory Compliance)
CREATE TABLE audit_ledger (
    audit_id VARCHAR(16) PRIMARY KEY,
    transaction_id VARCHAR(16) NOT NULL REFERENCES transactions(transaction_id),
    rule_triggered VARCHAR(64) NOT NULL,
    severity VARCHAR(16) NOT NULL CHECK (severity IN ('LOW', 'MEDIUM', 'CRITICAL')),
    flagged_at TIMESTAMP NOT NULL,
    status VARCHAR(24) NOT NULL DEFAULT 'PENDING_REVIEW'
);