import os
from dotenv import load_dotenv
import google.generativeai as genai

load_dotenv()

# Configure the Gemini API
api_key = os.getenv("GEMINI_API_KEY")
if not api_key:
    print("WARNING: GEMINI_API_KEY not found in environment variables.")

genai.configure(api_key=api_key)

# Using gemini-1.5-flash as it is the current stable lightweight model
model = genai.GenerativeModel("gemini-1.5-flash")

def get_ai_response(message):
    try:
        prompt = f"""
You are CareSync AI, a healthcare assistant.

Focus areas:
- Blood Pressure (BP)
- Tuberculosis (TB - lungs)
- Breast Cancer

Give simple, safe, helpful advice.
Always suggest consulting a doctor for serious issues.

User: {message}
"""

        response = model.generate_content(prompt)

        # Safer response handling
        if hasattr(response, "text") and response.text:
            return response.text
        else:
            return "I'm here to help! Please ask your health-related question."

    except Exception as e:
        print("AI ERROR:", str(e))
        return "Sorry, I'm having trouble responding right now. Please try again later."
