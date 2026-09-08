# backend/app/services/openai_service.py
import os
import json
import logging
from typing import Dict, Any, List, Optional

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

import google.generativeai as genai

logger = logging.getLogger("openai_service")

class OpenAIService:
    def __init__(self):
        self.api_key = os.getenv("GEMINI_API_KEY", "").strip()
        self.client = None

        if self.api_key and self.api_key != "GEMINI_API_KEY":
            try:
                genai.configure(api_key=self.api_key)
                # self.client = genai.GenerativeModel('gemini-1.5-flash')
                self.client = genai.GenerativeModel('gemini-pro')
                logger.info("✅ Gemini client initialized successfully")
            except Exception as e:
                logger.warning(f"Failed to initialize Gemini client: {e}")

    def generate_activity(
        self,
        skill_domain: str,
        difficulty: str,
        age_years: int,
        child_name: str
    ) -> Dict[str, Any]:
        """Generate a screen-free activity using Gemini"""
        
        if not self.client:
            return self._fallback_activity(skill_domain, difficulty, age_years, child_name)
        
        try:
            prompt = self._build_activity_prompt(
                skill_domain, difficulty, age_years, child_name
            )
            
            response = self.client.generate_content(prompt)
            
            # Parse the response (Gemini returns text, we need to extract JSON)
            result_text = response.text.strip()
            # Remove markdown code blocks if present
            if result_text.startswith("```json"):
                result_text = result_text[7:]
            if result_text.endswith("```"):
                result_text = result_text[:-3]
            
            result = json.loads(result_text.strip())
            
            return {
                "success": True,
                "data": {
                    "title": result.get("title", "Fun Activity"),
                    "shortDescription": result.get("shortDescription", ""),
                    "instructions": result.get("instructions", ""),
                    "learningGoals": result.get("learningGoals", []),
                    "materials": result.get("materials", []),
                    "duration": result.get("duration", "10-15 minutes"),
                    "skillType": skill_domain,
                    "difficulty": difficulty,
                    "ageGroup": [age_years]
                }
            }
            
        except Exception as e:
            logger.error(f"Gemini activity generation failed: {e}")
            return self._fallback_activity(skill_domain, difficulty, age_years, child_name)

    def generate_story(
        self,
        child_name: str,
        age_years: int,
        theme: str = "adventure",
        moral: Optional[str] = None
    ) -> Dict[str, Any]:
        """Generate a personalized children's story using Gemini"""
        
        if not self.client:
            return self._fallback_story(child_name, theme)
        
        try:
            prompt = f"""Write a short children's story for {child_name}, age {age_years}.
            Theme: {theme}
            {f"Moral: {moral}" if moral else ""}
            
            Return JSON with: title, story, characters (list), moral.
            """
            
            response = self.client.generate_content(prompt)
            
            result_text = response.text.strip()
            if result_text.startswith("```json"):
                result_text = result_text[7:]
            if result_text.endswith("```"):
                result_text = result_text[:-3]
            
            result = json.loads(result_text.strip())
            
            return {
                "success": True,
                "data": {
                    "title": result.get("title", f"{child_name}'s Adventure"),
                    "story": result.get("story", ""),
                    "characters": result.get("characters", []),
                    "moral": result.get("moral", "Be kind and curious"),
                    "readingTime": "5-7 minutes"
                }
            }
            
        except Exception as e:
            logger.error(f"Gemini story generation failed: {e}")
            return self._fallback_story(child_name, theme)

    def _build_activity_prompt(self, skill_domain: str, difficulty: str, age_years: int, child_name: str) -> str:
        return f"""Create a {difficulty} difficulty activity for a {age_years}-year-old named {child_name}.
        Focus on developing {skill_domain} skills.
        
        Requirements:
        - Screen-free activity
        - Uses common household materials
        - Takes 10-20 minutes
        - Age-appropriate for age {age_years}
        
        Return ONLY valid JSON with no additional text:
        {{
            "title": "Activity name",
            "shortDescription": "Brief description",
            "instructions": "Step-by-step instructions",
            "learningGoals": ["Goal 1", "Goal 2", "Goal 3"],
            "materials": ["Item 1", "Item 2", "Item 3"],
            "duration": "X-Y minutes"
        }}
        """

    def _fallback_activity(self, skill_domain: str, difficulty: str, age_years: int, child_name: str) -> Dict[str, Any]:
        return {
            "success": False,
            "data": {
                "title": f"{child_name}'s {skill_domain.title()} Activity",
                "shortDescription": f"A fun {skill_domain} activity for {child_name}",
                "instructions": "1. Start the activity\n2. Complete it\n3. Have fun!",
                "learningGoals": [f"Develop {skill_domain} skills", "Have fun learning"],
                "materials": ["Paper", "Pencil", "Household items"],
                "duration": "10-15 minutes",
                "skillType": skill_domain,
                "difficulty": difficulty,
                "ageGroup": [age_years]
            }
        }

    def _fallback_story(self, child_name: str, theme: str) -> Dict[str, Any]:
        return {
            "success": False,
            "data": {
                "title": f"{child_name}'s {theme.title()}",
                "story": f"Once upon a time, {child_name} went on an adventure...",
                "characters": [child_name],
                "moral": "Every adventure teaches us something new",
                "readingTime": "5-7 minutes"
            }
        }