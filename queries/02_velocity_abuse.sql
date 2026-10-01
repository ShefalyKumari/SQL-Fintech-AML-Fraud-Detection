WITH velocity_window AS (
    SELECT 
        t.transaction_id,
        t.sender_account_id,
        t.receiver_account_id,
        t.device_id,
        d.ip_address,
        d.geo_country,
        t.transaction_timestamp,
        t.amount_usd,
        -- Rolling count of transactions in the last 15 minutes
        COUNT(*) OVER (
            PARTITION BY t.sender_account_id 
            ORDER BY t.transaction_timestamp 
            RANGE BETWEEN INTERVAL 15 MINUTE PRECEDING AND CURRENT ROW
        ) AS tx_count_15m,
        -- Rolling sum of outbound amount in the last 15 minutes
        SUM(t.amount_usd) OVER (
            PARTITION BY t.sender_account_id 
            ORDER BY t.transaction_timestamp 
            RANGE BETWEEN INTERVAL 15 MINUTE PRECEDING AND CURRENT ROW
        ) AS outbound_volume_15m,
        -- Prior transaction timestamp for latency calculation
        LAG(t.transaction_timestamp) OVER (
            PARTITION BY t.sender_account_id 
            ORDER BY t.transaction_timestamp
        ) AS previous_tx_time
    FROM transactions t
    JOIN devices d ON t.device_id = d.device_id
    WHERE t.transaction_type IN ('Transfer', 'Wire')
)

SELECT 
    v.transaction_id,
    v.sender_account_id AS source_account,
    a.customer_name,
    a.risk_rating,
    v.transaction_timestamp,
    v.device_id,
    v.ip_address,
    v.geo_country,
    v.tx_count_15m,
    ROUND(v.outbound_volume_15m, 2) AS total_15m_volume_usd,
    ROUND(EXTRACT(EPOCH FROM (v.transaction_timestamp - v.previous_tx_time)), 0) AS seconds_since_prior_tx,
    'CRITICAL: Velocity Abuse / Automated Drain' AS alert_reason
FROM velocity_window v
JOIN accounts a ON v.sender_account_id = a.account_id
WHERE v.tx_count_15m >= 4
ORDER BY v.sender_account_id, v.transaction_timestamp;