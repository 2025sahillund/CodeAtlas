from database import get_db

def create_tables():
    db = get_db()
    cursor = db.cursor()

    # Create users table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        email TEXT UNIQUE,
        phone TEXT,
        password TEXT,
        age INTEGER,
        weight INTEGER,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)

    # Create medicines table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS medicines(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        medicine_name TEXT NOT NULL,
        dosage TEXT,
        time TEXT, -- Specific time for this reminder
        stock INTEGER DEFAULT 0,
        stock_threshold INTEGER DEFAULT 5,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id)
    )
    """)

    # Create medicine_logs table to track daily intake
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS medicine_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicine_id INTEGER,
        user_id INTEGER,
        date TEXT, -- YYYY-MM-DD
        status TEXT DEFAULT 'pending', -- pending, taken, missed
        taken_at TIMESTAMP,
        FOREIGN KEY (medicine_id) REFERENCES medicines(id),
        FOREIGN KEY (user_id) REFERENCES users(id)
    )
    """)

    # Create sugar_logs table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS sugar_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        sugar_level INTEGER,
        date TEXT,
        time TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)

    # Create emergency_contacts table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS emergency_contacts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        name TEXT,
        relation TEXT,
        phone TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)

    db.commit()
    db.close()
