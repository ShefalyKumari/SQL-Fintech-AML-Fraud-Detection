-- 1. Insert Structuring/Smurfing Alerts into Audit Ledger
INSERT INTO audit_ledger (audit_id, transaction_id, rule_triggered, severity, flagged_at, status)
SELECT 
    'AUD-STR-' || SUBSTR(t.transaction_id, 4),
    t.transaction_id,
    'AML_RULE_STRUCTURING_SMURFING_48H',
    'CRITICAL',
    CURRENT_TIMESTAMP,
    'PENDING_SAR_FILING'
FROM transactions t
WHERE t.amount_usd BETWEEN 9000.00 AND 9999.99
  AND t.receiver_account_id IN (
      SELECT receiver_account_id 
      FROM transactions 
      WHERE amount_usd BETWEEN 9000.00 AND 9999.99
      GROUP BY receiver_account_id
      HAVING COUNT(*) >= 2
  );

-- 2. Inspect Audit Ledger Contents
SELECT 
    audit_id,
    transaction_id,
    rule_triggered,
    severity,
    status
FROM audit_ledger
ORDER BY audit_id;