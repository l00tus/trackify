import os
import uuid
from sqlalchemy import create_engine, Column, Integer, String, Float, Boolean, Enum as SQLEnum, ForeignKey
from sqlalchemy.orm import sessionmaker, declarative_base
from pydantic import BaseModel, EmailStr
from enum import Enum
from dotenv import load_dotenv

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")

if DATABASE_URL is None:
    raise ValueError("DATABASE_URL is not set")

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# database model 
class DBExpense(Base):
    __tablename__ = "expenses"
    
    id = Column(String, primary_key=True, index=True)
    user_id = Column(String, index=True) # to know whose receipt this is
    store_name = Column(String)
    amount = Column(Float)
    date = Column(String)
    category = Column(String)
    is_synced = Column(Boolean, default=True) # always true on the server side

# api schema
class ExpenseSchema(BaseModel):
    id: str | None = None
    user_id: str
    store_name: str
    amount: float
    date: str
    category: str

    class Config:
        from_attributes = True
        
class AllowedCurrencies(str, Enum):
    USD = "USD"
    EUR = "EUR"
    GBP = "GBP"
    RON = "RON"
    CHF = "CHF"
    CNY = "CNY"
    JPY = "JPY"
    ILS = "ILS"
    RUB = "RUB"
    HUF = "HUF"
    PLN = "PLN"
    
    # ^^
    DEM = "DEM"   # Deutsche Mark (obsolete)
    GRD = "GRD"   # Greek Drachma (obsolete)
    ITL = "ITL"   # Italian Lira (obsolete)
    FRF = "FRF"   # French Franc (obsolete)
    ESP = "ESP"   # Spanish Peseta (obsolete)
    ATS = "ATS"   # Austrian Schilling (obsolete)
    
class PreferenceUpdate(BaseModel):
    currency: AllowedCurrencies

class UserPreference(Base):
    __tablename__ = "user_preferences"
    user_id = Column(String, ForeignKey("users.id"), primary_key=True, index=True)
    currency = Column(SQLEnum(AllowedCurrencies), default=AllowedCurrencies.RON, nullable=False)

class DBUser(Base):
    __tablename__ = "users"
    
    id = Column(String, primary_key=True, index=True, default=lambda: str(uuid.uuid4()))
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    
    session_token = Column(String, unique=True, index=True, nullable=True)
   
class UserCreate(BaseModel):
    email: EmailStr
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    

def init_db():
    Base.metadata.create_all(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()