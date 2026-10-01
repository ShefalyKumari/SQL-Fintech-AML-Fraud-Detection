# FinTech Fraud & Real-Time AML (Anti-Money Laundering) Detection Suite

A production-grade SQL analytical detection engine modeling financial compliance, illicit flow typologies, and regulatory audit ledgers for digital payments and neobanking platforms.

---

## Relational Entity-Relationship Model (ERD)

```text
[accounts] 1 ────< [devices]
    │  │
    │  └─────────< [transactions (sender)] 1 ────< [audit_ledger]
    │                     │
    └────────────< [transactions (receiver)]