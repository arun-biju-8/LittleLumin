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
    Generate an age-appropriate, screen-free activity using OpenAI/Gemini.
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
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="AI activity generation service is temporarily busy. Please try again in a moment."
            )
        return {"status": "success", "data": res.get("data")}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Failed to generate activity: {str(e)}"
        )

@router.post("/generate-story", status_code=status.HTTP_200_OK)
async def generate_story(req: GenerateStoryRequest) -> Dict[str, Any]:
    """
    Generate a personalized story with a moral lesson using OpenAI/Gemini.
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
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="AI story generation service is temporarily busy. Please try again in a moment."
            )
        return {"status": "success", "data": res.get("data")}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Failed to generate story: {str(e)}"
        )

class GenerateGrowthMessageRequest(BaseModel):
    child_age: int = Field(default=4, ge=1, le=12, description="Target child age")
    child_name: Optional[str] = Field(default="Your child", description="First name or generic reference")
    current_level: int = Field(default=1, ge=1, le=4, description="Current journey level")
    completed_activities_count: int = Field(default=0, ge=0, description="Completed activity count")
    assessed_domains_count: int = Field(default=0, ge=0, le=6, description="Number of domains with assessments")
    mastered_domains_count: int = Field(default=0, ge=0, le=6, description="Number of domains with score >= 70")
    total_domains_count: int = Field(default=6, ge=1, le=6, description="Total domains (6)")
    learning_state: str = Field(
        default="learning_in_progress",
        description="State identifier: learning_in_progress, initial_activities_completed_mastery_pending, domain_practice_needed, milestone_achieved, assessment_pending, level_mastered"
    )
    domain_scores: Optional[Dict[str, float]] = Field(default_factory=dict, description="Verified domain scores")
    mastered_domains: Optional[List[str]] = Field(default_factory=list, description="Mastered domain names")
    pending_domains: Optional[List[str]] = Field(default_factory=list, description="Pending domain names")
    recommended_domain: Optional[str] = Field(default=None, description="Recommended practice domain")
    recommended_activity_title: Optional[str] = Field(default=None, description="Recommended activity title")

@router.post("/generate-growth-message", status_code=status.HTTP_200_OK)
async def generate_growth_message(req: GenerateGrowthMessageRequest) -> Dict[str, Any]:
    """
    Generate an AI-powered personalized encouragement message grounded strictly in verified learning progress.
    """
    try:
        res = openai_service.generate_growth_message(
            child_age=req.child_age,
            child_name=req.child_name or "Your child",
            current_level=req.current_level,
            completed_activities_count=req.completed_activities_count,
            assessed_domains_count=req.assessed_domains_count,
            mastered_domains_count=req.mastered_domains_count,
            total_domains_count=req.total_domains_count,
            learning_state=req.learning_state,
            domain_scores=req.domain_scores or {},
            mastered_domains=req.mastered_domains or [],
            pending_domains=req.pending_domains or [],
            recommended_domain=req.recommended_domain,
            recommended_activity_title=req.recommended_activity_title
        )
        if not res.get("success") and not res.get("data"):
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="AI message generation service is temporarily busy. Please try again in a moment."
            )
        return {"status": "success", "data": res.get("data")}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Failed to generate growth message: {str(e)}"
        )
