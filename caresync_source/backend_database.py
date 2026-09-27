import sqlite3
import os

# Standardized database name
DB_PATH = 'caresync.db'

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    from models import create_tables
    create_tables()
    print(f"Database {DB_PATH} initialized.")

def get_low_stock_medicines(user_id):
    db = get_db()
    cursor = db.cursor()
    cursor.execute("""
        SELECT id, medicine_name, dosage, time, stock, stock_threshold 
        FROM medicines 
        WHERE user_id = ? AND stock <= stock_threshold
    """, (user_id,))
    low_stock_medicines = cursor.fetchall()
    db.close()
    return low_stock_medicines
