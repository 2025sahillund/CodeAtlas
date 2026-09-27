from flask import Blueprint, request, jsonify
from database import get_db

auth = Blueprint('auth', __name__)

@auth.route('/sync_user', methods=['POST'])
def sync_user():
    try:
        data = request.json
        uid = data.get('firebase_uid')
        email = data.get('email')
        name = data.get('name', 'User')

        if not uid:
            return jsonify({"error": "Missing UID"}), 400

        db = get_db()
        cursor = db.cursor()

        # Check if user exists
        user = cursor.execute("SELECT * FROM users WHERE firebase_uid = ?", (uid,)).fetchone()

        if not user:
            cursor.execute("""
                INSERT INTO users (firebase_uid, email, name)
                VALUES (?, ?, ?)
            """, (uid, email, name))
            db.commit()
            return jsonify({"message": "User created", "status": "new"}), 201
        
        return jsonify({"message": "User synchronized", "status": "existing"}), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@auth.route('/profile/<string:uid>', methods=['GET', 'POST'])
def profile(uid):
    db = get_db()
    cursor = db.cursor()

    if request.method == 'GET':
        user = cursor.execute("SELECT * FROM users WHERE firebase_uid = ?", (uid,)).fetchone()
        if user:
            return jsonify(dict(user)), 200
        return jsonify({"error": "User not found"}), 404

    if request.method == 'POST':
        data = request.json
        # senior update: Added all new comprehensive fields
        fields = [
            'name', 'phone', 'age', 'weight', 'height', 'blood_group', 
            'gender', 'emergency_contact_name', 'emergency_phone', 'allergies',
            'has_bp', 'has_tb', 'has_cancer', 'bp_medication', 
            'tb_status', 'tb_treatment_start_date', 'cancer_type', 
            'cancer_treatment_stage', 'family_cancer_history'
        ]
        
        update_parts = []
        params = []
        for field in fields:
            if field in data:
                update_parts.append(f"{field} = ?")
                params.append(data[field])
        
        if not update_parts:
            return jsonify({"message": "No changes"}), 200

        params.append(uid)
        query = f"UPDATE users SET {', '.join(update_parts)} WHERE firebase_uid = ?"
        cursor.execute(query, params)
        db.commit()
        
        return jsonify({"message": "Profile updated"}), 200
