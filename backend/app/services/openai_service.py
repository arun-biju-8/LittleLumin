# backend/app/services/openai_service.py
import os
import json
import logging
import re
import traceback
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
                self.client = genai.GenerativeModel('models/gemini-3.6-flash')
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
            if "```json" in result_text:
                result_text = result_text.split("```json")[1].split("```")[0].strip()
            elif "```" in result_text:
                result_text = result_text.split("```")[1].split("```")[0].strip()
            
            # Try to find JSON object
            json_match = re.search(r'\{.*\}', result_text, re.DOTALL)
            if json_match:
                result_text = json_match.group(0)
            
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
        age_years: int = 4,
        theme: str = "adventure",
        moral: Optional[str] = None,
        topic_or_moral: Optional[str] = None,
        **kwargs
    ) -> Dict[str, Any]:
        """Generate a personalized children's story using Gemini"""
        
        if topic_or_moral and not moral:
            moral = topic_or_moral
            
        logger.info(f"📖 Story generation started for {child_name}, age {age_years}")
        
        if not self.client:
            logger.error("❌ Gemini client not initialized")
            return self._fallback_story(child_name, theme)
        
        try:
            # ✅ Simple, clear prompt
            prompt = f"""Write a short children's story for {child_name}, age {age_years}.
Theme: {theme}
Moral: {moral if moral else 'Be kind and helpful'}

Return ONLY valid JSON with exactly these fields:
{{
    "title": "Story title here",
    "story": "Full story text here",
    "characters": ["Character 1", "Character 2"],
    "moral": "The moral of the story"
}}
DO NOT include any other text or markdown formatting. Only the JSON."""
            
            logger.info(f"📝 Prompt sent to Gemini: {prompt[:200]}...")
            
            response = self.client.generate_content(prompt)
            
            logger.info(f"✅ Gemini response received")
            logger.info(f"📄 Raw response: {response.text[:300]}...")
            
            # Clean the response
            result_text = response.text.strip()
            
            # Remove markdown code blocks
            if "```json" in result_text:
                result_text = result_text.split("```json")[1].split("```")[0].strip()
            elif "```" in result_text:
                result_text = result_text.split("```")[1].split("```")[0].strip()
            
            # Find JSON object
            import re
            json_match = re.search(r'\{.*\}', result_text, re.DOTALL)
            if json_match:
                result_text = json_match.group(0)
            
            logger.info(f"🔍 Extracted JSON: {result_text[:200]}...")
            
            result = json.loads(result_text)
            
            logger.info(f"✅ Story parsed successfully: {result.get('title', 'No title')}")
            
            return {
                "success": True,
                "data": {
                    "title": result.get("title", f"{child_name}'s Adventure"),
                    "story": result.get("story", f"Once upon a time, {child_name} went on an adventure..."),
                    "characters": result.get("characters", [child_name]),
                    "moral": result.get("moral", "Be kind and helpful"),
                    "readingTime": "5-7 minutes"
                }
            }
            
        except json.JSONDecodeError as e:
            logger.error(f"❌ JSON decode error: {e}")
            logger.error(f"❌ Failed text: {result_text[:500] if 'result_text' in locals() else 'No text'}")
            return self._fallback_story(child_name, theme)
        except Exception as e:
            logger.error(f"❌ Story generation failed: {e}")
            logger.error(f"❌ Error type: {type(e).__name__}")
            import traceback
            logger.error(f"❌ Traceback: {traceback.format_exc()}")
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

    def generate_growth_message(
        self,
        child_age: int = 4,
        child_name: str = "Your child",
        current_level: int = 1,
        completed_activities_count: int = 0,
        assessed_domains_count: int = 0,
        mastered_domains_count: int = 0,
        total_domains_count: int = 6,
        learning_state: str = "learning_in_progress",
        domain_scores: Optional[Dict[str, float]] = None,
        mastered_domains: Optional[List[str]] = None,
        pending_domains: Optional[List[str]] = None,
        recommended_domain: Optional[str] = None,
        recommended_activity_title: Optional[str] = None
    ) -> Dict[str, Any]:
        """Generate a warm, parent-friendly, verified learning progression message using Gemini"""
        domain_scores = domain_scores or {}
        mastered_domains = mastered_domains or []
        pending_domains = pending_domains or []
        rec_domain = (recommended_domain or "cognitive").capitalize()
        name = child_name.strip() if child_name and child_name.strip() else "your child"

        if not self.client:
            logger.info("Gemini client not initialized, using verified state fallback message.")
            return self._fallback_growth_message(
                learning_state=learning_state,
                child_name=name,
                current_level=current_level,
                completed_activities_count=completed_activities_count,
                mastered_domains_count=mastered_domains_count,
                total_domains_count=total_domains_count,
                recommended_domain=rec_domain,
                recommended_activity_title=recommended_activity_title
            )

        try:
            prompt = self._build_growth_message_prompt(
                child_age=child_age,
                child_name=name,
                current_level=current_level,
                completed_activities_count=completed_activities_count,
                assessed_domains_count=assessed_domains_count,
                mastered_domains_count=mastered_domains_count,
                total_domains_count=total_domains_count,
                learning_state=learning_state,
                domain_scores=domain_scores,
                mastered_domains=mastered_domains,
                pending_domains=pending_domains,
                recommended_domain=rec_domain,
                recommended_activity_title=recommended_activity_title
            )

            response = self.client.generate_content(prompt)
            result_text = response.text.strip()

            if "```json" in result_text:
                result_text = result_text.split("```json")[1].split("```")[0].strip()
            elif "```" in result_text:
                result_text = result_text.split("```")[1].split("```")[0].strip()

            json_match = re.search(r'\{.*\}', result_text, re.DOTALL)
            if json_match:
                result_text = json_match.group(0)

            result = json.loads(result_text.strip())
            headline = result.get("headline", "").strip()
            message = result.get("message", "").strip()
            suggested_action = result.get("suggested_action", "Continue Practice").strip()

            # Clean duplicate headline from message if repeated by model
            if headline and message.lower().startswith(headline.lower()):
                message = message[len(headline):].lstrip(" :-–\n")

            # Ensure proper sentence termination without dangling words
            if message and not message.endswith(('.', '!', '?')):
                last_space = message.rfind(' ')
                if last_space > 0 and message[last_space+1:].lower() in ['and', 'the', 'with', 'to', 'for', 'in', 'on', 'a', 'their', 'of']:
                    message = message[:last_space].rstrip(' ,;:-') + '.'
                else:
                    message = message.rstrip(' ,;:-') + '.'

            # Validate that message is non-empty and within acceptable length
            if not headline or not message or len(message) < 20 or len(message) > 600:
                raise ValueError("Generated message did not meet length or quality constraints")

            return {
                "success": True,
                "data": {
                    "headline": headline,
                    "message": message,
                    "suggested_action": suggested_action,
                    "source": "gemini"
                }
            }
        except Exception as e:
            logger.warning(f"Gemini growth message generation failed: {e}. Falling back to verified state fallback.")
            return self._fallback_growth_message(
                learning_state=learning_state,
                child_name=name,
                current_level=current_level,
                completed_activities_count=completed_activities_count,
                mastered_domains_count=mastered_domains_count,
                total_domains_count=total_domains_count,
                recommended_domain=rec_domain,
                recommended_activity_title=recommended_activity_title
            )

    def _build_growth_message_prompt(
        self,
        child_age: int,
        child_name: str,
        current_level: int,
        completed_activities_count: int,
        assessed_domains_count: int,
        mastered_domains_count: int,
        total_domains_count: int,
        learning_state: str,
        domain_scores: Dict[str, float],
        mastered_domains: List[str],
        pending_domains: List[str],
        recommended_domain: str,
        recommended_activity_title: Optional[str]
    ) -> str:
        has_custom_name = bool(child_name and child_name.lower() not in ["your child", "child"])
        child_label = child_name if has_custom_name else "your child"
        naming_rule = f"Refer to the child naturally as '{child_name}'." if has_custom_name else "Refer to the child naturally as 'your child' or 'your little one' with correct grammar and capitalization (e.g. 'Your child is making wonderful progress...' or 'an activity for your child...')."

        return f"""You are a gentle, supportive child-development guide for parents using LittleLumin.
Write a short, warm, parent-friendly encouragement message based strictly on verified learning progress:

FACTS (DO NOT INVENT OTHER DATA):
- Child: {child_label} (age {child_age})
- Current Level: Level {current_level}
- Completed Activities: {completed_activities_count}
- Assessed Domains: {assessed_domains_count} of {total_domains_count}
- Mastered Domains: {mastered_domains_count} of {total_domains_count} (Mastery threshold is 70% in each of the 6 core domains)
- Mastered domains: {', '.join(mastered_domains) if mastered_domains else 'None yet'}
- Domains still practicing: {', '.join(pending_domains) if pending_domains else 'All in progress'}
- Recommended Practice Domain: {recommended_domain}
- Recommended Activity: {recommended_activity_title or 'Targeted Practice'}
- Learning State: {learning_state}

STRICT WRITING GUIDELINES:
1. Warm, natural, empathetic tone suitable for parents.
2. {naming_rule}
3. Acknowledge achievements first before explaining next steps.
4. If initial activities are done but mastery is in progress, celebrate the activity milestone and gently explain that mastery grows through practice. Reassure the parent that children learn at different rates.
5. If a domain needs practice, mention {recommended_domain} playfully without negative labels.
6. NEVER use words like "delay", "behind", "failing", "abnormal", "struggling", "diagnosed".
7. NEVER make clinical claims, psychological diagnoses, or screening statements.
8. NEVER recommend a doctor, clinic, or specialist based on app mastery scores.
9. Length: 2 to 3 sentences (40 to 75 words). Concise, readable on mobile.
10. NEVER repeat or duplicate the headline inside the message body. Do not end sentences abruptly or with dangling phrases.

Return ONLY valid JSON matching this schema:
{{
    "headline": "Short encouraging headline (e.g., Level 1 · Learning in Progress)",
    "message": "2-3 sentences of warm encouragement grounded in the progress facts.",
    "suggested_action": "Short action label (e.g., Continue Practice)"
}}"""

    def _fallback_growth_message(
        self,
        learning_state: str,
        child_name: str,
        current_level: int,
        completed_activities_count: int,
        mastered_domains_count: int,
        total_domains_count: int,
        recommended_domain: str,
        recommended_activity_title: Optional[str]
    ) -> Dict[str, Any]:
        """High-quality deterministic fallback messages corresponding to States A, B, C, D, E"""
        has_name = bool(child_name and child_name.lower() not in ["your child", "child"])
        sub_name = child_name if has_name else "Your child"
        obj_name = child_name if has_name else "your child"
        poss_name = f"{child_name}'s" if has_name else "their"

        if learning_state == "level_mastered" or mastered_domains_count >= total_domains_count:
            # State E: Level mastery achieved
            headline = f"Level {current_level} Mastered! 🏆"
            message = f"Incredible effort! {sub_name} has achieved mastery across all 6 developmental domains. Level {current_level + 1} is now unlocked and ready for new discoveries."
            action = f"Explore Level {current_level + 1}"
        elif learning_state == "initial_activities_completed_mastery_pending":
            # State A: Initial Level 1 activities completed, mastery still in progress
            headline = f"Level {current_level} · Learning in progress"
            message = f"The first set of activities is complete — a wonderful milestone! {sub_name} can continue building these skills through more practice. Let's explore the next activity in {poss_name} learning journey."
            action = "Continue Learning"
        elif learning_state == "domain_practice_needed":
            # State B: A particular domain needs more practice
            headline = f"Building {recommended_domain} Skills"
            message = f"{sub_name} is making great progress. A little extra playful practice in {recommended_domain} will help strengthen foundational confidence and achieve {poss_name} next milestone."
            action = "Start Practice"
        elif learning_state == "milestone_achieved":
            # State C: Meaningful achievement occurred
            headline = "Lovely Milestone Achieved! 🌟"
            message = f"Great work celebrating each learning step together. {sub_name} has demonstrated mastery in {mastered_domains_count} of {total_domains_count} core domains. Let's keep the momentum going!"
            action = "Next Activity"
        elif learning_state == "assessment_pending" or completed_activities_count == 0:
            # State D: Assessment pending or initial journey
            headline = f"Welcome to Level {current_level} Workspace"
            message = f"Every learning adventure begins with play. Choose an activity for {obj_name} to begin discovering new developmental strengths together."
            action = "Begin Activity"
        else:
            # Default Learning in progress
            headline = f"Level {current_level} · Learning in progress"
            message = f"{sub_name} is actively exploring Level {current_level}. With {completed_activities_count} activities completed and {mastered_domains_count} of {total_domains_count} domains mastered, playful practice is paving the way to Level {current_level + 1}."
            action = "Continue Practice"

        return {
            "success": True,
            "data": {
                "headline": headline,
                "message": message,
                "suggested_action": action,
                "source": "fallback"
            }
        }