import random
from datetime import datetime, timedelta
import duckdb

DB_PATH = "fintech_aml.db"

def seed_database():
    conn = duckdb.connect(DB_PATH)
    
    with open("schema/01_init_schema.sql", "r") as f:
        schema_sql = f.read()
    conn.execute(schema_sql)
    print("AML Schema initialized successfully.")

    random.seed(101)
    base_time = datetime(2026, 1, 1, 8, 0, 0)

    # 1. Accounts (100 Accounts: Normal users + explicit Fraud rings)
    accounts = []
    account_types = ["Personal", "Business", "Merchant"]
    kyc_statuses = ["Verified", "Tier_1", "Pending"]
    risk_ratings = ["Low", "Medium", "High"]

    for i in range(1, 101):
        acc_id = f"ACC-{i:04d}"
        created = base_time - timedelta(days=random.randint(30, 400))
        risk = "High" if i in [7, 13, 42, 88] else random.choice(risk_ratings)
        accounts.append((acc_id, f"Customer_{i}", random.choice(account_types), random.choice(kyc_statuses), risk, created))
    
    conn.executemany("INSERT INTO accounts VALUES (?, ?, ?, ?, ?, ?)", accounts)

    # 2. Devices
    devices = []
    dev_counter = 1
    countries = ["United States", "United Kingdom", "Germany", "Nigeria", "Singapore", "Russia"]
    for acc in accounts:
        for _ in range(random.randint(1, 3)):
            dev_id = f"DEV-{dev_counter:04d}"
            dev_counter += 1
            ip = f"{random.randint(11, 199)}.{random.randint(0, 255)}.{random.randint(0, 255)}.{random.randint(1, 254)}"
            devices.append((dev_id, acc[0], ip, random.choice(["iOS", "Android", "Web_Chrome", "API_Client"]), random.choice(countries), acc[5] + timedelta(days=1)))
    
    conn.executemany("INSERT INTO devices VALUES (?, ?, ?, ?, ?, ?)", devices)

    # 3. Transactions Generator
    transactions = []
    tx_counter = 1

    # Typology A: Normal Background Activity (150 Transactions)
    for _ in range(150):
        tx_id = f"TX-{tx_counter:06d}"
        tx_counter += 1
        s_acc = random.choice(accounts)[0]
        r_acc = random.choice(accounts)[0]
        while r_acc == s_acc:
            r_acc = random.choice(accounts)[0]
        dev = random.choice([d for d in devices if d[1] == s_acc] or devices)[0]
        ts = base_time + timedelta(days=random.randint(1, 20), hours=random.randint(0, 23), minutes=random.randint(0, 59))
        amount = round(random.uniform(25.0, 1500.0), 2)
        transactions.append((tx_id, s_acc, r_acc, dev, ts, amount, "Transfer", random.choice(["Mobile", "Web"])))

    # Typology B: Structuring / Smurfing Ring (ACC-0007 receives multiple $9,000-$9,950 deposits in 48 hrs)
    target_acc = "ACC-0007"
    source_accs = ["ACC-0010", "ACC-0011", "ACC-0012", "ACC-0014"]
    target_dev = [d[0] for d in devices if d[1] == target_acc][0]
    smurf_time = base_time + timedelta(days=5, hours=10)
    for i, s_acc in enumerate(source_accs):
        tx_id = f"TX-{tx_counter:06d}"
        tx_counter += 1
        amount = round(random.uniform(9100.0, 9900.0), 2)
        transactions.append((tx_id, s_acc, target_acc, target_dev, smurf_time + timedelta(hours=i*6), amount, "Deposit", "Web"))

    # Typology C: Velocity Attack (ACC-0013 sends 6 transactions in 12 minutes across different IPs)
    velocity_acc = "ACC-0013"
    vel_time = base_time + timedelta(days=8, hours=14, minutes=0)
    for i in range(6):
        tx_id = f"TX-{tx_counter:06d}"
        tx_counter += 1
        r_acc = f"ACC-{random.randint(20, 30):04d}"
        rand_dev = random.choice(devices)[0]
        transactions.append((tx_id, velocity_acc, r_acc, rand_dev, vel_time + timedelta(minutes=i*2), 480.00, "Transfer", "API"))

    # Typology D: Rapid Balance Depletion / Mule Ring (ACC-0042 receives $45k via Wire, drains 98% in 30 mins)
    mule_acc = "ACC-0042"
    mule_time = base_time + timedelta(days=12, hours=9)
    mule_dev = [d[0] for d in devices if d[1] == mule_acc][0]
    # Inbound Wire
    tx_id_in = f"TX-{tx_counter:06d}"
    tx_counter += 1
    transactions.append((tx_id_in, "ACC-0001", mule_acc, mule_dev, mule_time, 45000.00, "Wire", "Web"))
    # Immediate Outbound Drains
    for i in range(3):
        tx_id_out = f"TX-{tx_counter:06d}"
        tx_counter += 1
        r_acc = f"ACC-{random.randint(60, 70):04d}"
        transactions.append((tx_id_out, mule_acc, r_acc, mule_dev, mule_time + timedelta(minutes=8 + (i*5)), 14500.00, "Transfer", "Mobile"))

    conn.executemany("INSERT INTO transactions VALUES (?, ?, ?, ?, ?, ?, ?, ?)", transactions)

    print(f"Data seeded successfully:")
    print(f" - Accounts:     {len(accounts)}")
    print(f" - Devices:      {len(devices)}")
    print(f" - Transactions: {len(transactions)}")
    conn.close()

if __name__ == "__main__":
    seed_database()