from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from app.services.openai_service import OpenAIService

router = APIRouter(prefix="/api/ai", tags=["AI Generation"])
openai_service = OpenAIService()

class GenerateActivityRequest(BaseModel):
    skill_domain: str = Field(default="Cognitive", description="Domain: Cognitive, Language, Motor, Social, Emotional, Creative")
    difficulty: str = Field(default="Medium", description="Difficulty: Easy, Medium, Hard")
    age_years: int = Field(default=4, ge=2, le=10, description="Target child age")
    child_name: Optional[str] = Field(default="", description="Optional child's name for personalization")

class GenerateStoryRequest(BaseModel):
    child_name: str = Field(default="Little Explorer", description="Child's name")
    topic_or_moral: Optional[str] = Field(default="Sharing and Kindness", description="Core theme or moral lesson")
    age_years: Optional[int] = Field(default=4, ge=2, le=10, description="Target child age")

@router.post("/generate-activity", status_code=status.HTTP_200_OK)
async def generate_activity(req: GenerateActivityRequest) -> Dict[str, Any]:
    """
    Generate an age-appropriate, screen-free activity using OpenAI.
    """
    try:
        res = openai_service.generate_activity(
            skill_domain=req.skill_domain,
            difficulty=req.difficulty,
            age_years=req.age_years,
            child_name=req.child_name or ""
        )
        if not res.get("success"):
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=res.get("error", "AI activity generation failed")
            )
        return {"status": "success", "data": res.get("data")}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate activity: {str(e)}"
        )

@router.post("/generate-story", status_code=status.HTTP_200_OK)
async def generate_story(req: GenerateStoryRequest) -> Dict[str, Any]:
    """
    Generate a personalized story with a moral lesson using OpenAI.
    """
    try:
        res = openai_service.generate_story(
            child_name=req.child_name or "Little Explorer",
            topic_or_moral=req.topic_or_moral or "Sharing and Kindness",
            moral=req.topic_or_moral or "Sharing and Kindness",
            age_years=req.age_years or 4
        )
        if not res.get("success"):
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=res.get("error", "AI story generation failed")
            )
        return {"status": "success", "data": res.get("data")}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate story: {str(e)}"
        )
