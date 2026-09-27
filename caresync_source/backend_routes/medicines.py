from flask import Blueprint, request, jsonify
from database import get_db
from datetime import datetime, timedelta

medicines = Blueprint('medicines', __name__)

@medicines.route('/add', methods=['POST'])
def add_medicine():
    try:
        data = request.json
        user_uid = data.get('user_uid')
        name = data.get('medicine_name')
        dosage = data.get('dosage')
        stock = data.get('stock', 20)
        times = data.get('times', [])

        if not user_uid or not name:
            return jsonify({"error": "Missing required fields"}), 400

        db = get_db()
        cursor = db.cursor()
        cursor.execute("INSERT INTO medicines (user_uid, medicine_name, dosage, total_stock) VALUES (?, ?, ?, ?)", 
                       (user_uid, name, dosage, stock))
        medicine_id = cursor.lastrowid

        for t in times:
            cursor.execute("INSERT INTO medicine_reminders (medicine_id, reminder_time) VALUES (?, ?)", (medicine_id, t))

        db.commit()
        return jsonify({"message": "Medicine added", "id": medicine_id}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@medicines.route('/today/<string:user_uid>', methods=['GET'])
def get_today_schedule(user_uid):
    db = get_db()
    today = datetime.now().strftime('%Y-%m-%d')
    query = """
        SELECT r.id as reminder_id, m.medicine_name, m.dosage, r.reminder_time, l.status as log_status
        FROM medicine_reminders r
        JOIN medicines m ON r.medicine_id = m.id
        LEFT JOIN medicine_logs l ON r.id = l.reminder_id AND l.log_date = ?
        WHERE m.user_uid = ?
        ORDER BY r.reminder_time ASC
    """
    rows = db.execute(query, (today, user_uid)).fetchall()
    schedule = []
    for row in rows:
        d = dict(row)
        d['is_taken'] = d['log_status'] == 'taken'
        try:
            t = datetime.strptime(d['reminder_time'], "%H:%M")
            d['notification_time'] = (t - timedelta(minutes=15)).strftime("%H:%M")
        except: d['notification_time'] = d['reminder_time']
        schedule.append(d)
    return jsonify(schedule)

@medicines.route('/stats/<string:user_uid>', methods=['GET'])
def get_stats(user_uid):
    db = get_db()
    # Adherence = (Taken Doses / Total Scheduled Doses)
    total = db.execute("SELECT COUNT(*) as count FROM medicine_logs l JOIN medicine_reminders r ON l.reminder_id = r.id JOIN medicines m ON r.medicine_id = m.id WHERE m.user_uid = ?", (user_uid,)).fetchone()['count']
    taken = db.execute("SELECT COUNT(*) as count FROM medicine_logs l JOIN medicine_reminders r ON l.reminder_id = r.id JOIN medicines m ON r.medicine_id = m.id WHERE m.user_uid = ? AND l.status = 'taken'", (user_uid,)).fetchone()['count']
    
    rate = (taken / total * 100) if total > 0 else 0
    return jsonify({"adherence_rate": round(rate), "total_logs": total})

@medicines.route('/list/<string:user_uid>', methods=['GET'])
def get_inventory(user_uid):
    db = get_db()
    query = "SELECT m.*, GROUP_CONCAT(r.reminder_time) as timings FROM medicines m LEFT JOIN medicine_reminders r ON m.id = r.medicine_id WHERE m.user_uid = ? GROUP BY m.id"
    rows = db.execute(query, (user_uid,)).fetchall()
    return jsonify([dict(r) for r in rows])

@medicines.route('/take/<int:reminder_id>', methods=['POST'])
def take_dose(reminder_id):
    db = get_db()
    today = datetime.now().strftime('%Y-%m-%d')
    db.execute("UPDATE medicines SET total_stock = total_stock - 1 WHERE id = (SELECT medicine_id FROM medicine_reminders WHERE id = ?)", (reminder_id,))
    db.execute("INSERT OR REPLACE INTO medicine_logs (reminder_id, log_date, status, taken_at) VALUES (?, ?, 'taken', CURRENT_TIMESTAMP)", (reminder_id, today))
    db.commit()
    return jsonify({"message": "Taken"})

@medicines.route('/refill/<int:medicine_id>', methods=['POST'])
def refill(medicine_id):
    amount = request.json.get('amount', 10)
    db = get_db()
    db.execute("UPDATE medicines SET total_stock = total_stock + ? WHERE id = ?", (amount, medicine_id))
    db.commit()
    return jsonify({"message": "Refilled"})

@medicines.route('/delete/<int:medicine_id>', methods=['DELETE'])
def delete(medicine_id):
    db = get_db()
    db.execute("DELETE FROM medicines WHERE id = ?", (medicine_id,))
    db.commit()
    return jsonify({"message": "Deleted"})
