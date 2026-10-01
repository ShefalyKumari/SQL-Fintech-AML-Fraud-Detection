import duckdb
import pytest

DB_PATH = "fintech_aml.db"

@pytest.fixture
def db_conn():
    conn = duckdb.connect(DB_PATH)
    yield conn
    conn.close()

def test_transactions_table_not_empty(db_conn):
    tx_count = db_conn.execute("SELECT COUNT(*) FROM transactions").fetchone()[0]
    assert tx_count > 100, "Transactions table should have simulated volume"

def test_structuring_detects_target_account(db_conn):
    with open("queries/01_structuring_smurfing.sql", "r") as f:
        query = f.read()
    df = db_conn.execute(query).df()
    
    assert len(df) > 0, "Smurfing query must catch structured transactions"
    flagged_accounts = df["beneficiary_account"].unique()
    assert "ACC-0007" in flagged_accounts, "ACC-0007 must be flagged for structuring"

def test_velocity_abuse_detects_rapid_burst(db_conn):
    with open("queries/02_velocity_abuse.sql", "r") as f:
        query = f.read()
    df = db_conn.execute(query).df()
    
    assert len(df) > 0, "Velocity abuse query must catch rapid transfer bursts"
    assert "ACC-0013" in df["source_account"].values, "ACC-0013 must trigger velocity alert"

def test_rapid_depletion_catches_mule_ring(db_conn):
    with open("queries/03_rapid_depletion.sql", "r") as f:
        query = f.read()
    df = db_conn.execute(query).df()
    
    assert len(df) > 0, "Mule depletion query must return results"
    assert "ACC-0042" in df["flagged_mule_account"].values, "Mule account ACC-0042 must be detected"
    depletion_pct = df[df["flagged_mule_account"] == "ACC-0042"]["depletion_percentage"].iloc[0]
    assert depletion_pct >= 80.0, "Mule account should have liquidated >= 80% of funds"