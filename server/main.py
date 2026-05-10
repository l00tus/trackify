import os
import json
import uuid
import PIL.Image
import google.generativeai as genai
import contextlib
from fastapi import FastAPI, WebSocket, UploadFile, File, HTTPException, Form, Depends
from typing import List
from sqlalchemy.orm import Session
from dotenv import load_dotenv
from io import BytesIO
from fastapi.middleware.cors import CORSMiddleware

from database import DBExpense, ExpenseSchema, PreferenceUpdate, TokenResponse, UserCreate, UserPreference, DBUser, get_db, init_db
from security import get_password_hash, generate_session_token, verify_password
from socket_manager import manager

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

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


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

# flow: image -> ai -> db
# use when user takes a new photo
# if offline, save photo locally and call this later when online
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
        new_id = str(uuid.uuid4())
        
        new_expense = DBExpense(
            id=new_id,
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
        
        # trigger socket update
        await manager.send_personal_message({
            "type": "RECEIPT_PROCESSED",
            "message": f"Successfully processed {receipt_data.get('store_name')}-{receipt_data.get('category')}",
            "id": new_id
        }, user_id)
        
        return {
            "success": True,
            "message": "Saved to database",
            "data": receipt_data,
            "db_id": new_expense.id
        }
    except Exception as e:
        print(f"Error: {e}")
        raise HTTPException(status_code=500, detail="AI processing failed")
    
# flow: cloud -> phone
# use for pulling history (login on a new device)
# populates the local sqlite with all previous cloud records
@app.get("/expenses/{user_id}")
async def get_all_user_expenses(user_id: str, db: Session = Depends(get_db)):
    # called when the user logs in on a new device (pulls everything from Neon to phone)
    expenses = db.query(DBExpense).filter(DBExpense.user_id == user_id).all()
    return {
        "success": True,
        "count": len(expenses),
        "data": expenses
    }

# flow: json -> db
# use for manual entries (no photo) and syncing edits made to existing receipts
@app.post("/sync-expenses")
async def sync_offline_expenses(expenses: List[ExpenseSchema], db: Session = Depends(get_db)):
    # app sends manual expenses or edits something offline
    synced_items = []
    for item in expenses:
        existing_item = None
        
        if item.id:
            existing_item = db.query(DBExpense).filter(DBExpense.id == item.id).first()
        
        if existing_item:
            for key, value in item.model_dump().items():
                setattr(existing_item, key, value)
            existing_item.is_synced = True
            synced_items.append(existing_item)
        else:
            new_id = item.id if item.id else str(uuid.uuid4())
            
            db_item = DBExpense(**item.model_dump(exclude={"id"}), id=new_id, is_synced=True)
        
            db.add(db_item)
            synced_items.append(db_item)

    try:
        db.commit()
        return {
            "success": True,
            "message": f"Successfully synced {len(synced_items)} expenses to Neon",
            "data": [ExpenseSchema.model_validate(item) for item in synced_items]
        }
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Sync failed: {str(e)}")
    
@app.get("/preferences/{user_id}")
def get_preferences(user_id: str, db: Session = Depends(get_db)):
    pref = db.query(UserPreference).filter(UserPreference.user_id == user_id).first()
    
    if not pref:
        raise HTTPException(
            status_code=404, 
            detail="User preferences not found. Please complete onboarding."
        )
        
    return {
        "succes": True,
        "currency": pref.currency.value
    }

@app.post("/preferences/{user_id}")
def set_preferences(user_id: str, prefs: PreferenceUpdate, db: Session = Depends(get_db)):
    # prefs.currency is validated by Pydantic
    pref = db.query(UserPreference).filter(UserPreference.user_id == user_id).first()
    
    if not pref:
        pref = UserPreference(user_id=user_id, currency=prefs.currency)
        db.add(pref)
    else:
        pref.currency = prefs.currency
        
    db.commit()
    return {
        "success": True, 
        "currency": pref.currency.value
    }
    
@app.post("/register", response_model=TokenResponse)
def register_user(user: UserCreate, db: Session = Depends(get_db)):
    existing_user = db.query(DBUser).filter(DBUser.email == user.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    hashed_pw = get_password_hash(user.password)
    token = generate_session_token()
    
    new_user = DBUser(
        email=user.email, 
        hashed_password=hashed_pw,
        session_token=token
    )
    
    db.add(new_user)
    
    db.flush() 
    
    new_prefs = UserPreference(
        user_id=new_user.id
    )
    db.add(new_prefs)
    
    db.commit()
    db.refresh(new_user)
    
    return {
        "access_token": token, 
        "token_type": "bearer", 
        "user_id": new_user.id
    }

@app.post("/login", response_model=TokenResponse)
def login_user(user: UserCreate, db: Session = Depends(get_db)):
    db_user = db.query(DBUser).filter(DBUser.email == user.email).first()
    
    if not db_user or not verify_password(user.password, db_user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    
    token = generate_session_token()
    db_user.session_token = token
    
    db.commit()
    
    return {
        "access_token": token, 
        "token_type": "bearer", 
        "user_id": db_user.id
    }
    
@app.websocket("/ws/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: str):
    print(f"Websocket for: {user_id}")
    await manager.connect(websocket, user_id)
    try:
        while True:
            # keeps the connection alive and waits for pings
            data = await websocket.receive_text()
    except Exception:
        manager.disconnect(websocket, user_id)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

