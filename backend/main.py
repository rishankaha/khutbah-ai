# main.py
from fastapi import FastAPI
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
# NEW: Import the official Google Cloud Translation client
from google.cloud import translate_v2 as translate
import os
import asyncio # <-- Confirmed: This is what adds the delay capability

app = FastAPI()

# --- INITIALIZATION ---
try:
    translate_client = translate.Client()
except Exception as e:
    print(f"ERROR: Failed to initialize Google Translation Client: {e}")
    translate_client = None


# CORS so Flutter can access backend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- MODELS ---
class TextData(BaseModel):
    text: str

# --- ROUTES ---
@app.get("/")
def root():
    return {"message": "Backend running"}

# Test route for Flutter button
@app.post("/test")
def test_endpoint(data: TextData):
    return {"reply": f"Received: {data.text}"}

# Main translation route - NOW USING GOOGLE CLOUD
# 🚨 Function is ASYNC to support the delay
@app.post("/arabic-to-english")
async def translate_text(data: TextData):
    arabic_text = data.text
    
    # ⏱️ DELAY IS HERE: The server waits 0.5 seconds before processing 
    # and responding to the request, which forces the English text 
    # to appear later than the Arabic text.
    await asyncio.sleep(0.0) 
    
    if not translate_client:
        return {"arabic": arabic_text, "english": "Translation Service Not Authenticated. Check Server Logs."}
        
    try:
        # Call the official Google Cloud Translation API
        result = translate_client.translate(
            arabic_text,
            target_language='en',
            source_language='ar'
        )
        
        # The translated text is in the 'translatedText' key
        english_translation = result['translatedText']
        
    except Exception as e:
        # Catch any errors (API limits, network issues, etc.)
        print(f"Google Cloud Translation API Error: {e}")
        english_translation = f"Error translating: {e}"

    return {
        "arabic": arabic_text,
        "english": english_translation}