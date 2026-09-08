import os
import json
import logging
from typing import Dict, Any, List, Optional

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

from openai import OpenAI

logger = logging.getLogger("openai_service")

class OpenAIService:
    def __init__(self):
        self.api_key = os.getenv("OPENAI_API_KEY", "").strip()
        self.client = None

        if self.api_key and self.api_key != "OPENAI_API_KEY":
            try:
                # ✅ MODERN OpenAI initialization (removed proxies)
                self.client = OpenAI(api_key=self.api_key)
                logger.info("✅ OpenAI client initialized successfully")
            except Exception as e:
                logger.warning(f"Failed to initialize OpenAI client: {e}")
        else:
            logger.warning("⚠️ OPENAI_API_KEY is not configured or holds a default placeholder.")

    def generate_activity(
        self,
        skill_domain: str,
        difficulty: str,
        age_years: int,
        child_name: str
    ) -> Dict[str, Any]:
        """Generate a screen-free activity using OpenAI"""
        logger.info(f"Generating activity request: domain={skill_domain}, diff={difficulty}, age={age_years}, child={child_name}")
        
        if not self.client:
            logger.error("OpenAI client not initialized (API key missing or invalid)")
            return {
                "success": False,
                "error": "OpenAI API key is missing or not configured on backend."
            }
        
        try:
            prompt = self._build_activity_prompt(
                skill_domain, difficulty, age_years, child_name
            )
            
            response = self.client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[
                    {
                        "role": "system",
                        "content": "You are an expert early childhood educator. Return valid JSON."
                    },
                    {"role": "user", "content": prompt}
                ],
                temperature=0.7,
                max_tokens=500,
                response_format={"type": "json_object"}
            )
            
            result = json.loads(response.choices[0].message.content)
            logger.info("✅ OpenAI activity generation succeeded")
            
            return {
                "success": True,
                "data": {
                    "title": result.get("title", "Fun Activity"),
                    "shortDescription": result.get("shortDescription", ""),
                    "instructions": result.get("instructions", []),
                    "learningGoals": result.get("learningGoals", []),
                    "materials": result.get("materials", []),
                    "duration": result.get("duration", 15),
                    "skillType": skill_domain,
                    "difficulty": difficulty,
                    "ageGroup": [age_years]
                }
            }
            
        except Exception as e:
            logger.error(f"OpenAI activity generation failed: {e}")
            return {
                "success": False,
                "error": f"OpenAI activity generation failed: {str(e)}"
            }

    def generate_story(
        self,
        child_name: str,
        age_years: int = 4,
        theme: str = "adventure",
        moral: Optional[str] = None,
        topic_or_moral: Optional[str] = None
    ) -> Dict[str, Any]:
        """Generate a personalized children's story using OpenAI"""
        effective_theme = topic_or_moral if (topic_or_moral and theme == "adventure") else theme
        logger.info(f"Generating story request: child={child_name}, age={age_years}, theme={effective_theme}")

        if not self.client:
            logger.error("OpenAI client not initialized (API key missing or invalid)")
            return {
                "success": False,
                "error": "OpenAI API key is missing or not configured on backend."
            }
        
        try:
            prompt = f"""Write a short children's story for {child_name}, age {age_years}.
            Theme/Moral: {effective_theme}
            {f"Moral: {moral}" if moral else ""}
            
            Return JSON with:
            - title: creative story title
            - childName: name of child
            - theme: theme of story
            - characters: list of character names
            - storyContent: story narrative (3-4 paragraphs)
            - moralLesson: short moral takeaway lesson
            - discussionQuestions: list of 2-3 questions for parent to ask child
            """
            
            response = self.client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[
                    {
                        "role": "system",
                        "content": "You are a children's story writer. Return valid JSON."
                    },
                    {"role": "user", "content": prompt}
                ],
                temperature=0.8,
                max_tokens=700,
                response_format={"type": "json_object"}
            )
            
            result = json.loads(response.choices[0].message.content)
            logger.info("✅ OpenAI story generation succeeded")
            
            return {
                "success": True,
                "data": {
                    "title": result.get("title", f"{child_name}'s Adventure"),
                    "childName": result.get("childName", child_name),
                    "theme": result.get("theme", effective_theme),
                    "characters": result.get("characters", [child_name]),
                    "storyContent": result.get("storyContent", result.get("story", "")),
                    "moralLesson": result.get("moralLesson", result.get("moral", "Be kind and curious")),
                    "discussionQuestions": result.get("discussionQuestions", []),
                    "readingTime": "5-7 minutes"
                }
            }
            
        except Exception as e:
            logger.error(f"OpenAI story generation failed: {e}")
            return {
                "success": False,
                "error": f"OpenAI story generation failed: {str(e)}"
            }

    def _build_activity_prompt(self, skill_domain: str, difficulty: str, age_years: int, child_name: str) -> str:
        child_str = f" named {child_name}" if child_name else ""
        return f"""Create a {difficulty} difficulty activity for a {age_years}-year-old{child_str}.
        Focus on developing {skill_domain} skills.
        
        Requirements:
        - Screen-free activity
        - Uses common household materials
        - Takes 10-20 minutes
        - Age-appropriate for age {age_years}
        
        Return JSON with:
        {{
            "title": "Activity name",
            "shortDescription": "Brief description",
            "instructions": ["Step 1", "Step 2", "Step 3"],
            "learningGoals": ["Goal 1", "Goal 2"],
            "materials": ["Item 1", "Item 2"],
            "duration": 15
        }}
        """
