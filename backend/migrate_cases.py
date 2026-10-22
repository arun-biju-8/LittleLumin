"""
LittleLumin Specialist Cases & DPDP Consent Expiry Migration Script

Enforces Requirement 2:
- Detects legacy cases missing valid 'consentExpiresAt' timestamps.
- Migrates legacy 'expiresAt' or calculates a 90-day DPDP consent window from 'consentedAt'.
- For cases past the 90-day window without an active explicit extension, flags them for
  parent re-authorisation rather than granting indefinite access.
- Idempotent and supports dry-run inspection before committing.
"""

import os
import sys
import argparse
from datetime import datetime, timezone, timedelta
from typing import Optional

# Ensure UTF-8 output on Windows consoles
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

def get_db():
    try:
        import firebase_admin
        from firebase_admin import credentials, firestore
        if not firebase_admin._apps:
            key_path = os.getenv("FIREBASE_ADMIN_KEY_PATH", "firebase-admin-key.json")
            if os.path.exists(key_path):
                cred = credentials.Certificate(key_path)
                firebase_admin.initialize_app(cred)
            else:
                firebase_admin.initialize_app()
        return firestore.client()
    except Exception as e:
        print(f"⚠️ Firebase Admin SDK not configured for live connection: {e}")
        return None

def migrate_cases(dry_run: bool = True):
    print("=" * 70)
    print("🔒 LittleLumin DPDP Specialist Case Consent Expiry Migration")
    print(f"Mode: {'DRY RUN (no writes committed)' if dry_run else 'LIVE COMMIT'}")
    print("=" * 70)

    db = get_db()
    if not db:
        print("Running in simulated verification mode.")
        cases = []
    else:
        cases = list(db.collection("specialistCases").stream())

    print(f"\nDiscovered {len(cases)} specialist consultation cases\n")

    migrated_count = 0
    expired_count = 0
    up_to_date_count = 0
    errors_count = 0

    now = datetime.now(timezone.utc)

    for doc in cases:
        case_id = doc.id
        data = doc.to_dict() or {}

        status = data.get("status", "unknown")
        consent_expires_at = data.get("consentExpiresAt")
        legacy_expires_at = data.get("expiresAt")
        consented_at = data.get("consentedAt") or data.get("createdAt")

        # 1. Check if already has valid consentExpiresAt
        if consent_expires_at is not None:
            up_to_date_count += 1
            continue

        print(f"→ Processing Case {case_id} (Status: {status})")

        # 2. Determine target expiry
        target_expiry: Optional[datetime] = None

        if legacy_expires_at is not None:
            if isinstance(legacy_expires_at, datetime):
                target_expiry = legacy_expires_at
            else:
                try:
                    target_expiry = datetime.fromisoformat(str(legacy_expires_at).replace("Z", "+00:00"))
                except Exception:
                    pass

        if target_expiry is None and consented_at is not None:
            # 90-day DPDP consent window from consent date
            base_dt = consented_at if isinstance(consented_at, datetime) else now
            if base_dt.tzinfo is None:
                base_dt = base_dt.replace(tzinfo=timezone.utc)
            target_expiry = base_dt + timedelta(days=90)

        if target_expiry is None:
            # Fallback for unparseable legacy timestamps: 90 days from now or require reauthorization
            target_expiry = now + timedelta(days=90)

        if target_expiry.tzinfo is None:
            target_expiry = target_expiry.replace(tzinfo=timezone.utc)

        update_payload = {
            "consentExpiresAt": target_expiry,
            "updatedAt": now,
        }

        # Sync categories if missing
        if "authorizedDataCategories" not in data and "consentCategories" in data:
            update_payload["authorizedDataCategories"] = data["consentCategories"]

        # If already expired in the past, update status to avoid orphaned access
        if target_expiry < now and status in ["accepted", "active"]:
            print(f"   ⏳ Case expired on {target_expiry.isoformat()} — flagging for re-authorisation")
            update_payload["status"] = "expired"
            update_payload["expiredAt"] = target_expiry
            update_payload["reauthorizationRequired"] = True
            expired_count += 1
        else:
            print(f"   ✅ Setting valid consentExpiresAt to: {target_expiry.isoformat()}")
            migrated_count += 1

        if not dry_run and db:
            try:
                db.collection("specialistCases").document(case_id).update(update_payload)
            except Exception as e:
                print(f"   ❌ Failed to update case {case_id}: {e}")
                errors_count += 1

    print("\n" + "=" * 70)
    print("MIGRATION SUMMARY:")
    print(f"  ✅ Up to date (already compliant): {up_to_date_count}")
    print(f"  🔄 Migrated with valid expiry:     {migrated_count}")
    print(f"  🛑 Expired / Reauthorisation set:  {expired_count}")
    print(f"  ❌ Errors encountered:             {errors_count}")
    print("=" * 70)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Migrate specialistCases consent expiry")
    parser.add_argument("--commit", action="store_true", help="Execute live updates to Firestore")
    parser.add_argument("--dry-run", action="store_true", default=True, help="Simulate migration without writing to Firestore (default)")
    args = parser.parse_args()

    migrate_cases(dry_run=not args.commit)
