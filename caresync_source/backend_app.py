from flask import Flask
from flask_cors import CORS
from routes.auth import auth
from routes.medicines import medicines
from routes.sugar import sugar
from routes.chatbot import chatbot

app = Flask(__name__)
CORS(app)  # Enable CORS for Flutter frontend

# Register blueprints
app.register_blueprint(auth, url_prefix='/auth')
app.register_blueprint(medicines, url_prefix='/medicines')
app.register_blueprint(sugar, url_prefix='/sugar')
app.register_blueprint(chatbot, url_prefix='/chatbot')

@app.route('/')
def home():
    return {"message": "CareSync Backend is running"}

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
