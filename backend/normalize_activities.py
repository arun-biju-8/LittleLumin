"""
One-time migration: normalize skillType and difficulty to lowercase in the `activities` Firestore collection.
Idempotent — safe to re-run.
"""

import sys
import firebase_admin
from firebase_admin import credentials, firestore

if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

cred = credentials.Certificate("firebase-admin-key.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

VALID_SKILLS = {"cognitive", "language", "motor", "social", "emotional", "creative", "listening"}
VALID_DIFFICULTIES = {"easy", "medium", "hard"}

def normalize():
    print("=" * 60)
    print("Normalizing activities collection")
    print("=" * 60)

    activities = list(db.collection("activities").stream())
    print(f"\nFound {len(activities)} activities\n")

    updated = 0
    skipped = 0
    failed = 0

    for doc in activities:
        data = doc.to_dict() or {}
        changes = {}

        # Normalize skillType
        raw_skill = (data.get("skillType") or "").strip()
        normalized_skill = raw_skill.lower()
        if normalized_skill and normalized_skill in VALID_SKILLS:
            if raw_skill != normalized_skill:
                changes["skillType"] = normalized_skill
        elif normalized_skill:
            print(f"  ⚠️ Unknown skill in {doc.id}: {raw_skill}")

        # Normalize difficulty
        raw_diff = (data.get("difficulty") or "").strip()
        normalized_diff = raw_diff.lower()
        if normalized_diff and normalized_diff in VALID_DIFFICULTIES:
            if raw_diff != normalized_diff:
                changes["difficulty"] = normalized_diff
        elif normalized_diff:
            print(f"  ⚠️ Unknown difficulty in {doc.id}: {raw_diff}")

        if changes:
            try:
                db.collection("activities").document(doc.id).update(changes)
                print(f"  ✅ {doc.id}: {changes}")
                updated += 1
            except Exception as e:
                print(f"  ❌ {doc.id}: {e}")
                failed += 1
        else:
            skipped += 1

    print("\n" + "=" * 60)
    print(f"✅ Updated:  {updated}")
    print(f"⏭️ Skipped:  {skipped}")
    print(f"❌ Failed:   {failed}")
    print("=" * 60)

if __name__ == "__main__":
    normalize()
