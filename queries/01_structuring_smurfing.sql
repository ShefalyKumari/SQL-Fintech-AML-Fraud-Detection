WITH near_threshold_deposits AS (
    SELECT 
        transaction_id,
        receiver_account_id,
        sender_account_id,
        transaction_timestamp,
        amount_usd,
        -- Rolling 48-hour count of near-threshold transactions
        COUNT(*) OVER (
            PARTITION BY receiver_account_id 
            ORDER BY transaction_timestamp 
            RANGE BETWEEN INTERVAL 48 HOUR PRECEDING AND CURRENT ROW
        ) AS rolling_deposit_count_48h,
        -- Rolling 48-hour cumulative deposit value
        SUM(amount_usd) OVER (
            PARTITION BY receiver_account_id 
            ORDER BY transaction_timestamp 
            RANGE BETWEEN INTERVAL 48 HOUR PRECEDING AND CURRENT ROW
        ) AS rolling_deposit_volume_48h
    FROM transactions
    WHERE amount_usd BETWEEN 9000.00 AND 9999.99
)

SELECT 
    d.transaction_id,
    d.receiver_account_id AS beneficiary_account,
    a.customer_name AS beneficiary_name,
    a.risk_rating,
    d.transaction_timestamp,
    d.amount_usd AS deposit_amount,
    d.rolling_deposit_count_48h,
    d.rolling_deposit_volume_48h,
    CASE 
        WHEN d.rolling_deposit_count_48h >= 3 THEN 'CRITICAL: Confirmed Smurfing Ring'
        WHEN d.rolling_deposit_count_48h = 2 THEN 'HIGH: Suspected Structuring'
        ELSE 'MEDIUM: Near-Threshold Single Deposit'
    END AS aml_alert_severity
FROM near_threshold_deposits d
JOIN accounts a ON d.receiver_account_id = a.account_id
WHERE d.rolling_deposit_count_48h >= 2
ORDER BY d.rolling_deposit_volume_48h DESC, d.transaction_timestamp;