from flask import Blueprint, request, jsonify
from database import get_db

sugar = Blueprint('sugar', __name__)

@sugar.route('/log_sugar', methods=['POST'])
def log_sugar():
    try:
        data = request.json
        user_uid = data.get('user_uid')
        sugar_level = data.get('sugar_level')
        date = data.get('date')
        time = data.get('time')

        if not user_uid or not sugar_level:
            return jsonify({"error": "Missing required fields"}), 400

        db = get_db()
        cursor = db.cursor()

        cursor.execute("""
            INSERT INTO sugar_logs (user_uid, sugar_level, log_date, log_time)
            VALUES (?, ?, ?, ?)
        """, (user_uid, sugar_level, date, time))

        db.commit()
        return jsonify({"message": "Sugar logged successfully"}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@sugar.route('/history/<string:user_uid>', methods=['GET'])
def get_sugar_history(user_uid):
    try:
        db = get_db()
        logs = db.execute("""
            SELECT * FROM sugar_logs 
            WHERE user_uid = ? 
            ORDER BY log_date DESC, log_time DESC 
            LIMIT 50
        """, (user_uid,)).fetchall()
        
        return jsonify([dict(l) for l in logs]), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500
