WITH high_value_inbound AS (
    SELECT 
        transaction_id AS inbound_tx_id,
        receiver_account_id AS account_id,
        transaction_timestamp AS inbound_time,
        amount_usd AS inbound_amount
    FROM transactions
    WHERE amount_usd >= 10000.00
      AND transaction_type IN ('Deposit', 'Wire')
),

immediate_outbound_drains AS (
    SELECT 
        h.account_id,
        h.inbound_tx_id,
        h.inbound_time,
        h.inbound_amount,
        t.transaction_id AS outbound_tx_id,
        t.transaction_timestamp AS outbound_time,
        t.amount_usd AS outbound_amount,
        ROUND(EXTRACT(EPOCH FROM (t.transaction_timestamp - h.inbound_time)) / 60.0, 1) AS minutes_after_deposit
    FROM high_value_inbound h
    JOIN transactions t 
      ON h.account_id = t.sender_account_id
     AND t.transaction_timestamp BETWEEN h.inbound_time AND (h.inbound_time + INTERVAL 60 MINUTE)
     AND t.transaction_type IN ('Transfer', 'Withdrawal')
),

mule_aggregations AS (
    SELECT 
        account_id,
        inbound_tx_id,
        inbound_time,
        inbound_amount,
        COUNT(outbound_tx_id) AS drain_tx_count,
        SUM(outbound_amount) AS total_drained_usd,
        ROUND((SUM(outbound_amount) / inbound_amount) * 100.0, 2) AS depletion_percentage,
        MAX(minutes_after_deposit) AS liquidation_window_minutes
    FROM immediate_outbound_drains
    GROUP BY account_id, inbound_tx_id, inbound_time, inbound_amount
)

SELECT 
    m.account_id AS flagged_mule_account,
    a.customer_name,
    a.risk_rating,
    m.inbound_time,
    ROUND(m.inbound_amount, 2) AS initial_inbound_usd,
    m.drain_tx_count AS outbound_split_count,
    ROUND(m.total_drained_usd, 2) AS drained_usd,
    m.depletion_percentage,
    m.liquidation_window_minutes,
    CASE 
        WHEN m.depletion_percentage >= 80.0 THEN 'CRITICAL: Mule Funneling & Immediate Dissipation'
        ELSE 'ELEVATED: High Velocity Outbound Transfer'
    END AS compliance_risk_verdict
FROM mule_aggregations m
JOIN accounts a ON m.account_id = a.account_id
WHERE m.depletion_percentage >= 50.0
ORDER BY m.depletion_percentage DESC;