import os
import json
import PIL.Image
import google.generativeai as genai
import contextlib
from fastapi import FastAPI, UploadFile, File, HTTPException, Form, Depends
from sqlalchemy.orm import Session
from dotenv import load_dotenv
from io import BytesIO

from database import DBExpense, get_db, init_db

load_dotenv()
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

if not GEMINI_API_KEY:
    raise ValueError("Missing GEMINI_API_KEY in .env file")

genai.configure(api_key=GEMINI_API_KEY)
model = genai.GenerativeModel('gemini-2.5-flash')

@contextlib.asynccontextmanager
async def lifespan(app: FastAPI):
    print("Starting up: creating database tables...")
    init_db()
    
    yield
    
    print("Shutting down...")

app = FastAPI(lifespan=lifespan)

PROMPT = """
Analyze this receipt image. Extract the data into a raw JSON object.
Do not include markdown formatting, backticks, or any text other than the JSON.
Required keys:
- "store_name": string
- "date": string (YYYY-MM-DD)
- "total": float
- "category": Choose exactly one: "Groceries", "Transport", "Entertainment", "Bills", "Shopping", "Other"
"""

@app.get("/")
def health_check():
    return {"status": "Backend is running"}

@app.post("/process-receipt")
async def process_receipt(file: UploadFile = File(...), user_id: str = Form(...), db: Session = Depends(get_db)):
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")
    
    try:
        img_bytes = await file.read()
        img = PIL.Image.open(BytesIO(img_bytes))
        
        response = model.generate_content([PROMPT, img])
        
        clean_json = response.text.strip()
        receipt_data = json.loads(clean_json)
        
        new_expense = DBExpense(
            user_id=user_id,
            store_name=receipt_data.get("store_name", "Unknown"),
            amount=receipt_data.get("total", 0.0),
            date=receipt_data.get("date", "2004-09-17"),
            category=receipt_data.get("category", "Other"),
            is_synced=True
        )
        
        db.add(new_expense)
        db.commit()
        db.refresh(new_expense)
        
        return {
            "success": True,
            "message": "Saved to database",
            "data": receipt_data,
            "db_id": new_expense.id
        }
    except Exception as e:
        print(f"Error: {e}")
        raise HTTPException(status_code=500, detail="AI processing failed")
    
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

