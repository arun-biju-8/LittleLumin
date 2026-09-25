"""
One-time migration: create baseline scoreEvents for existing children.
This is IDEMPOTENT — safe to re-run.
"""
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timezone

# Initialize Firebase Admin
cred = credentials.Certificate("firebase-admin-key.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

DOMAINS = ["cognitive", "language", "motor", "social", "emotional", "creative"]

def migrate():
    print("=" * 60)
    print("LittleLumin Score Migration")
    print("=" * 60)

    children = list(db.collection("children").stream())
    print(f"\nFound {len(children)} children\n")

    migrated = 0
    skipped = 0
    failed = 0

    for child in children:
        child_id = child.id
        child_data = child.to_dict() or {}
        child_name = child_data.get("name", "Unknown")

        print(f"→ {child_name} ({child_id})")

        # Get skill profile
        profile = db.collection("skillProfiles").document(child_id).get()
        if not profile.exists:
            print(f"   ⚠️  No skillProfile — skipping")
            skipped += 1
            continue

        profile_data = profile.to_dict() or {}

        # Skip if already migrated
        existing = list(
            db.collection("scoreEvents")
            .where("childId", "==", child_id)
            .where("activitySource", "==", "migration")
            .limit(1)
            .stream()
        )
        if existing:
            print(f"   ⏭️  Already migrated — skipping")
            skipped += 1
            continue

        try:
            for domain in DOMAINS:
                raw_value = profile_data.get(domain, 0)
                try:
                    score = float(raw_value)
                except (TypeError, ValueError):
                    score = 0.0

                db.collection("scoreEvents").add({
                    "childId": child_id,
                    "activityId": "migration_baseline",
                    "activityTitle": f"Baseline {domain} score",
                    "activitySource": "migration",
                    "skillDomain": domain,
                    "difficulty": "medium",
                    "levelAtTime": 1,
                    "feedback": {
                        "childResponse": "migration",
                        "engagement": "migration",
                        "difficulty": "migration",
                        "confidence": "migration",
                        "timeEstimate": "migration",
                        "notes": "Baseline created from existing skillProfiles data"
                    },
                    "rawScoreDelta": score,
                    "appliedScoreDelta": score,
                    "weightApplied": 1.0,
                    "scoreBefore": 0.0,
                    "scoreAfter": score,
                    "submittedByParentId": "system_migration",
                    "createdAt": firestore.SERVER_TIMESTAMP,
                    "isImmutable": True,
                })
                print(f"   ✅ {domain}: {score}")

            migrated += 1

        except Exception as e:
            print(f"   ❌ Error: {e}")
            failed += 1

    print("\n" + "=" * 60)
    print(f"✅ Migrated:  {migrated}")
    print(f"⏭️  Skipped:   {skipped}")
    print(f"❌ Failed:    {failed}")
    print("=" * 60)


if __name__ == "__main__":
    migrate()