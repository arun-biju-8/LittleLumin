// test/firestore_security_rules_test.js
/**
 * LittleLumin Firestore Security Rules Comprehensive Test Suite
 *
 * Runs against the local Firestore Emulator to verify all security requirements:
 * 1. Unauthenticated users (restricted access)
 * 2. Anti-privilege escalation (self-registration cannot assign admin/verified roles)
 * 3. Parent-child ownership and cross-parent isolation
 * 4. Specialist case assignment, DPDP lifecycle, expiry & revocation
 * 5. Consent scope enforcement: child_profile vs domain_scores vs activity_history vs observations
 * 6. Valid consent expiry requirement (denial if missing, malformed, expired, or revoked)
 * 7. Transition lockdown (specialist cannot alter consent categories, purpose, expiry, or IDs)
 * 8. Learning Guide vs Clinical Specialist observation rules
 * 9. Authoritative score event validation, bounded profile scores & progression protection
 * 10. Audit trail protection (non-admin client writes forbidden)
 * 11. Notification spoofing prevention & adminUsers collection lockdown
 * 12. Query behavior, cross-tenant isolation and unfiltered scan prevention
 */

const PORT = 8080;
const PROJECT_ID = 'demo-littlelumin';
const BASE_URL = `http://127.0.0.1:${PORT}/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

// Helper: create JWT for the emulator
function makeToken(uid, customClaims = {}) {
  const header = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(JSON.stringify({
    sub: uid,
    user_id: uid,
    aud: PROJECT_ID,
    iss: `https://securetoken.google.com/${PROJECT_ID}`,
    auth_time: Math.floor(Date.now() / 1000),
    ...customClaims
  })).toString('base64url');
  return `${header}.${payload}.`;
}

// Convert JS value to Firestore REST Value
function toFirestoreValue(val) {
  if (val === null || val === undefined) return { nullValue: null };
  if (typeof val === 'boolean') return { booleanValue: val };
  if (typeof val === 'number') {
    if (Number.isInteger(val)) return { integerValue: val.toString() };
    return { doubleValue: val };
  }
  if (typeof val === 'string') return { stringValue: val };
  if (val instanceof Date) return { timestampValue: val.toISOString() };
  if (Array.isArray(val)) {
    return { arrayValue: { values: val.map(toFirestoreValue) } };
  }
  if (typeof val === 'object') {
    const fields = {};
    for (const [k, v] of Object.entries(val)) {
      fields[k] = toFirestoreValue(v);
    }
    return { mapValue: { fields } };
  }
  return { stringValue: String(val) };
}

function toFirestoreFields(obj) {
  const fields = {};
  for (const [k, v] of Object.entries(obj)) {
    fields[k] = toFirestoreValue(v);
  }
  return fields;
}

// REST request helpers
async function docGet(path, token = null) {
  const headers = {};
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(`${BASE_URL}/${path}`, { headers });
  return { status: res.status, ok: res.ok, data: res.ok ? await res.json() : null };
}

async function docSet(path, data, token = null) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(`${BASE_URL}/${path}`, {
    method: 'PATCH',
    headers,
    body: JSON.stringify({ fields: toFirestoreFields(data) })
  });
  return { status: res.status, ok: res.ok, data: res.ok ? await res.json() : null };
}

async function docUpdate(path, data, token = null) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const fieldPaths = Object.keys(data).map(k => `updateMask.fieldPaths=${encodeURIComponent(k)}`).join('&');
  const res = await fetch(`${BASE_URL}/${path}?${fieldPaths}`, {
    method: 'PATCH',
    headers,
    body: JSON.stringify({ fields: toFirestoreFields(data) })
  });
  return { status: res.status, ok: res.ok, data: res.ok ? await res.json() : null };
}

async function docCreateInCollection(colPath, data, token = null) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(`${BASE_URL}/${colPath}`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ fields: toFirestoreFields(data) })
  });
  return { status: res.status, ok: res.ok, data: res.ok ? await res.json() : null };
}

async function docDelete(path, token = null) {
  const headers = {};
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(`${BASE_URL}/${path}`, { method: 'DELETE', headers });
  return { status: res.status, ok: res.ok };
}

async function queryCollection(colId, filterField, filterValue, token = null) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(`${BASE_URL}:runQuery`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: colId }],
        where: {
          fieldFilter: {
            field: { fieldPath: filterField },
            op: 'EQUAL',
            value: toFirestoreValue(filterValue)
          }
        }
      }
    })
  });
  return { status: res.status, ok: res.ok, data: res.ok ? await res.json() : null };
}

// Test Runner Framework
let passedCount = 0;
let failedCount = 0;

async function assertAllowed(name, promise) {
  try {
    const res = await promise;
    if (res.ok || (res.status >= 200 && res.status < 300)) {
      console.log(`  ✅ PASS: ${name}`);
      passedCount++;
    } else {
      console.error(`  ❌ FAIL: ${name} (Expected ALLOW, got HTTP ${res.status})`);
      failedCount++;
    }
  } catch (err) {
    console.error(`  ❌ FAIL: ${name} (Unexpected error: ${err.message})`);
    failedCount++;
  }
}

async function assertDenied(name, promise) {
  try {
    const res = await promise;
    if (res.status === 403 || res.status === 401) {
      console.log(`  ✅ PASS: ${name} (Denied with HTTP ${res.status})`);
      passedCount++;
    } else {
      console.error(`  ❌ FAIL: ${name} (Expected DENIED (403), got HTTP ${res.status})`);
      failedCount++;
    }
  } catch (err) {
    console.error(`  ❌ FAIL: ${name} (Unexpected error: ${err.message})`);
    failedCount++;
  }
}

async function runAllTests() {
  console.log('\n===============================================================');
  console.log('🧪 Starting LittleLumin Firestore Security Rules Test Suite');
  console.log('===============================================================\n');

  // Test Tokens
  const tokenAdmin = makeToken('admin_user', { admin: true, role: 'admin' });
  const tokenParent1 = makeToken('parent_1');
  const tokenParent2 = makeToken('parent_2');
  const tokenGuide = makeToken('guide_specialist');
  const tokenClinical = makeToken('clinical_specialist');
  const tokenUnassigned = makeToken('unassigned_specialist');
  const tokenPendingSpec = makeToken('pending_spec');
  const tokenBypass = 'owner';

  // -----------------------------------------------------------------
  // 0. Seed Baseline Directory & User Data (as Admin)
  // -----------------------------------------------------------------
  console.log('--- 0. Seeding Baseline Directory & User Data (as Admin) ---');
  await assertAllowed('Admin seeds adminUsers record',
    docSet('adminUsers/admin_user', { role: 'admin', active: true }, tokenAdmin));

  await assertAllowed('Admin seeds Guide user doc',
    docSet('users/guide_specialist', { userType: 'llg', isVerified: true, name: 'Guide Gary' }, tokenAdmin));
  await assertAllowed('Admin seeds Guide profile',
    docSet('llgProfiles/guide_specialist', { isVerified: true, name: 'Guide Gary', role: 'llg' }, tokenAdmin));

  await assertAllowed('Admin seeds Clinical user doc',
    docSet('users/clinical_specialist', { userType: 'clinical_specialist', isVerified: true, name: 'Dr. Clara' }, tokenAdmin));
  await assertAllowed('Admin seeds Clinical profile',
    docSet('llgProfiles/clinical_specialist', { isVerified: true, name: 'Dr. Clara', role: 'clinical_specialist' }, tokenAdmin));

  await assertAllowed('Admin seeds Unassigned Specialist user doc',
    docSet('users/unassigned_specialist', { userType: 'specialist', isVerified: true, name: 'Dr. John' }, tokenAdmin));
  await assertAllowed('Admin seeds Unassigned Specialist profile',
    docSet('llgProfiles/unassigned_specialist', { isVerified: true, name: 'Dr. John', role: 'specialist' }, tokenAdmin));

  await assertAllowed('Admin seeds public parenting tip',
    docSet('tips/tip_1', { message: 'Encourage exploration!', createdAt: new Date() }, tokenAdmin));

  await assertAllowed('Admin seeds unverified specialist profile',
    docSet('llgProfiles/pending_spec', { isVerified: false, name: 'Pending Pete' }, tokenAdmin));
  await assertAllowed('Admin seeds unverified specialist user doc',
    docSet('users/pending_spec', { userType: 'specialist', isVerified: false, name: 'Pending Pete' }, tokenAdmin));

  await assertAllowed('Admin seeds pending specialist certificate',
    docSet('llgCertificateVerifications/cert_1', { llgId: 'pending_spec', certUrl: 'https://secrets.com/cert.pdf' }, tokenAdmin));

  // -----------------------------------------------------------------
  // 1. Unauthenticated Access Tests
  // -----------------------------------------------------------------
  console.log('\n--- 1. Testing Unauthenticated Access ---');
  await assertDenied('Unauth CANNOT read tips (requires authentication)', docGet('tips/tip_1', null));
  await assertDenied('Unauth CANNOT read verified specialist profile (requires auth)', docGet('llgProfiles/guide_specialist', null));
  await assertDenied('Unauth CANNOT read unverified specialist profile', docGet('llgProfiles/pending_spec', null));
  await assertDenied('Unauth CANNOT read private user doc', docGet('users/guide_specialist', null));
  await assertDenied('Unauth CANNOT read children collection', docGet('children/child_1', null));
  await assertDenied('Unauth CANNOT read specialistCases', docGet('specialistCases/child_1_guide_specialist', null));
  await assertDenied('Unauth CANNOT read observations', docGet('llgObservations/obs_1', null));
  await assertDenied('Unauth CANNOT read scoreEvents', docGet('scoreEvents/event_1', null));
  await assertDenied('Unauth CANNOT create flag', docCreateInCollection('flags', { childId: 'child_1' }, null));
  await assertDenied('Unauth CANNOT write certificate verification',
    docSet('llgCertificateVerifications/cert_new', { llgId: 'hacker' }, null));

  // -----------------------------------------------------------------
  // 2. Anti-Privilege Escalation Tests
  // -----------------------------------------------------------------
  console.log('\n--- 2. Testing Anti-Privilege Escalation ---');
  await assertDenied('User cannot self-register with userType: "admin"',
    docSet('users/attacker_1', { name: 'Attacker', userType: 'admin', isVerified: false }, makeToken('attacker_1')));

  await assertDenied('User cannot self-register with isVerified: true',
    docSet('users/attacker_2', { name: 'Attacker', userType: 'parent', isVerified: true }, makeToken('attacker_2')));

  await assertDenied('User cannot self-register with verificationStatus: "verified"',
    docSet('users/attacker_3', { name: 'Attacker', userType: 'parent', isVerified: false, verificationStatus: 'verified' }, makeToken('attacker_3')));

  await assertDenied('User cannot self-register with custom claim role: "admin"',
    docSet('users/attacker_4', { name: 'Attacker', userType: 'parent', role: 'admin' }, makeToken('attacker_4')));

  await assertDenied('User cannot write to adminUsers collection',
    docSet('adminUsers/parent_1', { role: 'admin' }, tokenParent1));

  // Lockdown: Non-admin users CANNOT read adminUsers collection (Requirement 6)
  await assertDenied('Non-admin CANNOT read adminUsers collection',
    docGet('adminUsers/admin_user', tokenParent1));
  await assertAllowed('Admin CAN read adminUsers collection',
    docGet('adminUsers/admin_user', tokenAdmin));

  await assertAllowed('Parent 1 can self-register safely as standard parent',
    docSet('users/parent_1', { name: 'Alice Parent', userType: 'parent', isVerified: false }, tokenParent1));

  await assertAllowed('Parent 2 can self-register safely as standard parent',
    docSet('users/parent_2', { name: 'Bob Parent', userType: 'parent', isVerified: false }, tokenParent2));

  await assertDenied('Parent 1 cannot escalate to admin via update',
    docSet('users/parent_1', { name: 'Alice Parent', userType: 'admin', isVerified: false }, tokenParent1));

  await assertDenied('Parent 1 cannot self-verify via update',
    docSet('users/parent_1', { name: 'Alice Parent', userType: 'parent', isVerified: true }, tokenParent1));

  // Scoped subcollections under users/{uid}
  await assertAllowed('User can access own nested activities subcollection',
    docSet('users/parent_1/activities/act_nested', { title: 'My Activity' }, tokenParent1));
  await assertDenied('User CANNOT access another user nested activities',
    docSet('users/parent_1/activities/act_nested', { title: 'Hacked' }, tokenParent2));

  // -----------------------------------------------------------------
  // 3. User Privacy Tests
  // -----------------------------------------------------------------
  console.log('\n--- 3. Testing User Profile Privacy ---');
  await assertAllowed('Parent 1 can read own user doc', docGet('users/parent_1', tokenParent1));
  await assertDenied('Parent 2 cannot read Parent 1 private user doc', docGet('users/parent_1', tokenParent2));
  await assertAllowed('Admin can read Parent 1 private user doc', docGet('users/parent_1', tokenAdmin));

  // -----------------------------------------------------------------
  // 4. Child Ownership & Cross-Parent Isolation
  // -----------------------------------------------------------------
  console.log('\n--- 4. Testing Child Ownership & Cross-Parent Isolation ---');
  await assertDenied('Parent 1 cannot create child with parentId of Parent 2',
    docSet('children/child_1', { name: 'Charlie', parentId: 'parent_2' }, tokenParent1));

  await assertAllowed('Parent 1 can create own child_1',
    docSet('children/child_1', { name: 'Charlie', parentId: 'parent_1' }, tokenParent1));

  await assertAllowed('Parent 2 can create own child_2',
    docSet('children/child_2', { name: 'David', parentId: 'parent_2' }, tokenParent2));

  await assertAllowed('Parent 1 can read own child_1', docGet('children/child_1', tokenParent1));
  await assertDenied('Parent 2 cannot read Parent 1 child_1', docGet('children/child_1', tokenParent2));

  await assertDenied('Parent 1 cannot transfer child_1 to Parent 2',
    docSet('children/child_1', { name: 'Charlie', parentId: 'parent_2' }, tokenParent1));

  // Child-related collections (skillProfiles, journeyProgress, rewards)
  // Requirement 1 & 7: Authoritative Growth Data - Deny direct client writes
  await assertDenied('Parent 1 CANNOT write skillProfiles directly (deny client fabrication)',
    docSet('skillProfiles/child_1', { childId: 'child_1', cognitive: 75.0, language: 60.0 }, tokenParent1));
  await assertDenied('Parent 1 CANNOT write journeyProgress directly (deny client progression tampering)',
    docSet('journeyProgress/child_1', { childId: 'child_1', currentLevel: 1, unlockedLevels: [1] }, tokenParent1));
  await assertDenied('Parent 1 CANNOT write scoreLedger directly',
    docSet('scoreLedger/child_1', { childId: 'child_1' }, tokenParent1));
  await assertDenied('Parent 1 CANNOT write scoreLedger events subcollection',
    docSet('scoreLedger/child_1/events/evt_1', { childId: 'child_1' }, tokenParent1));

  // Seed authoritative data via Admin SDK / owner bypass for read verification
  await assertAllowed('Admin SDK seeds skillProfiles for child_1',
    docSet('skillProfiles/child_1', { childId: 'child_1', cognitive: 75.0, language: 60.0 }, tokenBypass));
  await assertAllowed('Admin SDK seeds journeyProgress for child_1',
    docSet('journeyProgress/child_1', { childId: 'child_1', currentLevel: 1, unlockedLevels: [1] }, tokenBypass));

  await assertAllowed('Parent 1 can read own child_1 skillProfiles',
    docGet('skillProfiles/child_1', tokenParent1));
  await assertDenied('Parent 2 cannot read skillProfiles for child_1',
    docGet('skillProfiles/child_1', tokenParent2));

  await assertAllowed('Parent 1 can read own child_1 journeyProgress',
    docGet('journeyProgress/child_1', tokenParent1));
  await assertDenied('Parent 2 cannot read journeyProgress for child_1',
    docGet('journeyProgress/child_1', tokenParent2));

  await assertAllowed('Parent 1 can update rewards for child_1',
    docSet('rewards/child_1', { childId: 'child_1', stars: 10 }, tokenParent1));
  await assertDenied('Parent 2 cannot read rewards for child_1',
    docGet('rewards/child_1', tokenParent2));

  // -----------------------------------------------------------------
  // 5. Specialist Case Lifecycle & Consent Validation
  // -----------------------------------------------------------------
  console.log('\n--- 5. Testing Specialist Case Lifecycle & Consent Validation ---');
  const caseId1 = 'child_1_guide_specialist';

  await assertDenied('Parent 2 cannot create case for Parent 1 child_1',
    docSet(`specialistCases/${caseId1}`, {
      childId: 'child_1',
      parentId: 'parent_1',
      specialistId: 'guide_specialist',
      status: 'pending',
      purpose: 'Speech and language consultation',
      consentNoticeVersion: 'v1.0-dpdp',
      authorizedDataCategories: ['milestones', 'observations'],
      consentExpiresAt: new Date(Date.now() + 86400000 * 30)
    }, tokenParent2));

  await assertDenied('Parent 1 cannot create case with status: "accepted" directly (no self-approval)',
    docSet(`specialistCases/${caseId1}`, {
      childId: 'child_1',
      parentId: 'parent_1',
      specialistId: 'guide_specialist',
      status: 'accepted',
      purpose: 'Speech and language consultation',
      consentNoticeVersion: 'v1.0-dpdp',
      authorizedDataCategories: ['milestones', 'observations'],
      consentExpiresAt: new Date(Date.now() + 86400000 * 30)
    }, tokenParent1));

  await assertDenied('Parent cannot assign self as specialist and self-approve',
    docSet('specialistCases/child_1_parent_1', {
      childId: 'child_1',
      parentId: 'parent_1',
      specialistId: 'parent_1', // Parent assigning self!
      status: 'pending',
      purpose: 'Self consultation',
      consentNoticeVersion: 'v1.0-dpdp',
      authorizedDataCategories: ['milestones', 'observations'],
      consentExpiresAt: new Date(Date.now() + 86400000 * 30)
    }, tokenParent1));

  // Requirement 2: Case created WITHOUT consentExpiresAt is rejected!
  await assertDenied('Case creation WITHOUT consentExpiresAt is strictly rejected',
    docSet(`specialistCases/${caseId1}`, {
      childId: 'child_1',
      parentId: 'parent_1',
      specialistId: 'guide_specialist',
      status: 'pending',
      purpose: 'Speech guidance',
      consentNoticeVersion: 'v1.0-dpdp',
      authorizedDataCategories: ['milestones', 'observations'],
      createdAt: new Date()
    }, tokenParent1));

  // Requirement 2: Case created with past consentExpiresAt is rejected!
  await assertDenied('Case creation with expired consentExpiresAt is strictly rejected',
    docSet(`specialistCases/${caseId1}`, {
      childId: 'child_1',
      parentId: 'parent_1',
      specialistId: 'guide_specialist',
      status: 'pending',
      purpose: 'Speech guidance',
      consentNoticeVersion: 'v1.0-dpdp',
      authorizedDataCategories: ['milestones', 'observations'],
      consentExpiresAt: new Date(Date.now() - 3600000), // In past
      createdAt: new Date()
    }, tokenParent1));

  await assertDenied('Parent 1 cannot create case for non-existent specialist',
    docSet('specialistCases/child_1_fake_specialist', {
      childId: 'child_1',
      parentId: 'parent_1',
      specialistId: 'fake_specialist_xyz',
      status: 'pending',
      purpose: 'Speech guidance',
      consentNoticeVersion: 'v1.0-dpdp',
      authorizedDataCategories: ['milestones', 'observations'],
      consentExpiresAt: new Date(Date.now() + 86400000 * 30)
    }, tokenParent1));

  // Requirement 3 & 7: Case creation with unverified specialist is strictly DENIED
  const unverifiedCaseId = 'child_1_pending_spec';
  await assertDenied('Parent 1 CANNOT create case for unverified specialist (pending_spec)',
    docSet(`specialistCases/${unverifiedCaseId}`, {
      childId: 'child_1',
      parentId: 'parent_1',
      specialistId: 'pending_spec',
      status: 'pending',
      purpose: 'Speech consultation',
      consentNoticeVersion: 'v1.0-dpdp',
      authorizedDataCategories: ['domain_scores'],
      consentExpiresAt: new Date(Date.now() + 86400000 * 30),
      createdAt: new Date()
    }, tokenParent1));

  // Consent Category Schema Validation (Requirement 3 & 7)
  await assertDenied('Case creation with unwhitelisted consent category fails',
    docSet('specialistCases/child_1_guide_specialist_badcat', {
      childId: 'child_1',
      parentId: 'parent_1',
      specialistId: 'guide_specialist',
      status: 'pending',
      purpose: 'Valid purpose for consultation',
      consentNoticeVersion: 'v1.0-dpdp',
      authorizedDataCategories: ['unauthorized_telemetry_category'],
      consentExpiresAt: new Date(Date.now() + 86400000 * 30),
      createdAt: new Date()
    }, tokenParent1));

  await assertDenied('Case creation with empty consent categories fails',
    docSet('specialistCases/child_1_guide_specialist_emptycat', {
      childId: 'child_1',
      parentId: 'parent_1',
      specialistId: 'guide_specialist',
      status: 'pending',
      purpose: 'Valid purpose for consultation',
      consentNoticeVersion: 'v1.0-dpdp',
      authorizedDataCategories: [],
      consentExpiresAt: new Date(Date.now() + 86400000 * 30),
      createdAt: new Date()
    }, tokenParent1));

  await assertDenied('Case creation with too short purpose (< 3 chars) fails',
    docSet('specialistCases/child_1_guide_specialist_shortpurp', {
      childId: 'child_1',
      parentId: 'parent_1',
      specialistId: 'guide_specialist',
      status: 'pending',
      purpose: 'Hi',
      consentNoticeVersion: 'v1.0-dpdp',
      authorizedDataCategories: ['domain_scores'],
      consentExpiresAt: new Date(Date.now() + 86400000 * 30),
      createdAt: new Date()
    }, tokenParent1));

  await assertDenied('Case creation with empty consent notice version fails',
    docSet('specialistCases/child_1_guide_specialist_nonotice', {
      childId: 'child_1',
      parentId: 'parent_1',
      specialistId: 'guide_specialist',
      status: 'pending',
      purpose: 'Valid purpose for consultation',
      consentNoticeVersion: '',
      authorizedDataCategories: ['domain_scores'],
      consentExpiresAt: new Date(Date.now() + 86400000 * 30),
      createdAt: new Date()
    }, tokenParent1));

  // Valid creation: parent assigns verified specialist with scope, expiry, purpose and notice version
  await assertAllowed('Parent 1 creates valid pending case for guide_specialist',
    docSet(`specialistCases/${caseId1}`, {
      childId: 'child_1',
      parentId: 'parent_1',
      specialistId: 'guide_specialist',
      status: 'pending',
      purpose: 'Developmental guidance for speech and language',
      consentNoticeVersion: 'v1.0-dpdp',
      authorizedDataCategories: ['milestones', 'observations'],
      consentExpiresAt: new Date(Date.now() + 86400000 * 30), // +30 days
      createdAt: new Date()
    }, tokenParent1));

  // Unassigned specialist cannot accept case of guide_specialist
  await assertDenied('Unassigned specialist cannot accept another specialist case',
    docUpdate(`specialistCases/${caseId1}`, {
      status: 'accepted'
    }, tokenUnassigned));

  // Seed pending case for unverified specialist via Admin SDK to test transition lockdown
  await assertAllowed('Admin SDK seeds pending case for unverified specialist',
    docSet(`specialistCases/${unverifiedCaseId}`, {
      childId: 'child_1',
      parentId: 'parent_1',
      specialistId: 'pending_spec',
      status: 'pending',
      purpose: 'General consultation',
      consentNoticeVersion: 'v1.0-dpdp',
      authorizedDataCategories: ['domain_scores'],
      consentExpiresAt: new Date(Date.now() + 86400000 * 30),
      createdAt: new Date()
    }, tokenBypass));

  await assertDenied('Unverified specialist CANNOT accept pending case (transition lockdown)',
    docUpdate(`specialistCases/${unverifiedCaseId}`, {
      status: 'accepted'
    }, tokenPendingSpec));

  // Assigned verified guide accepts the case
  await assertAllowed('Assigned verified guide accepts the pending case',
    docUpdate(`specialistCases/${caseId1}`, {
      status: 'accepted',
      acceptedAt: new Date()
    }, tokenGuide));

  // Requirement 3: Specialist CANNOT modify immutable fields or broaden consent
  await assertDenied('Specialist cannot change childId on case',
    docUpdate(`specialistCases/${caseId1}`, {
      childId: 'child_2'
    }, tokenGuide));

  await assertDenied('Specialist CANNOT extend consent expiry date (transition lockdown)',
    docUpdate(`specialistCases/${caseId1}`, {
      consentExpiresAt: new Date(Date.now() + 86400000 * 365)
    }, tokenGuide));

  await assertDenied('Specialist CANNOT expand authorized consent categories',
    docUpdate(`specialistCases/${caseId1}`, {
      authorizedDataCategories: ['all']
    }, tokenGuide));

  await assertDenied('Specialist CANNOT alter consultation purpose',
    docUpdate(`specialistCases/${caseId1}`, {
      purpose: 'Full Diagnostic Audit'
    }, tokenGuide));

  // -----------------------------------------------------------------
  // 6. Enforce Consent Data Scope & Expiry (Requirements 1, 2, 8)
  // -----------------------------------------------------------------
  console.log('\n--- 6. Testing Scope-Gated Access & Expiry Lockdown ---');
  // Case 1 only granted ['milestones', 'observations']
  // Requirement 1 & 8: Specialist CANNOT read full child document when only limited categories authorised!
  await assertDenied('Specialist with only milestone consent CANNOT read full child_1 document',
    docGet('children/child_1', tokenGuide));

  // Specialist CAN read skillProfiles because 'milestones' is authorized
  await assertAllowed('Active assigned guide can read child_1 skillProfiles (authorized category)',
    docGet('skillProfiles/child_1', tokenGuide));

  // Specialist CANNOT read journeyProgress because 'activity_history' is not authorized
  await assertDenied('Specialist CANNOT read journeyProgress when activity_history is unauthorized',
    docGet('journeyProgress/child_1', tokenGuide));

  // Now admin grants full child_profile and activity_history on caseId1
  await assertAllowed('Admin updates caseId1 to add child_profile and activity_history',
    docUpdate(`specialistCases/${caseId1}`, {
      authorizedDataCategories: ['child_profile', 'activity_history', 'milestones', 'observations']
    }, tokenAdmin));

  // Now guide specialist CAN read child_1 full document
  await assertAllowed('Specialist WITH child_profile consent CAN read child_1 document',
    docGet('children/child_1', tokenGuide));

  // And CAN read journeyProgress
  await assertAllowed('Specialist WITH activity_history consent CAN read journeyProgress',
    docGet('journeyProgress/child_1', tokenGuide));

  await assertDenied('Unassigned specialist CANNOT read child_1',
    docGet('children/child_1', tokenUnassigned));

  await assertDenied('Unassigned specialist CANNOT read child_1 skillProfiles',
    docGet('skillProfiles/child_1', tokenUnassigned));

  // -----------------------------------------------------------------
  // 6b. Missing & Expired Consent Denials (Requirement 2 & 8)
  // -----------------------------------------------------------------
  console.log('\n--- 6b. Testing Missing & Expired Consent Denials ---');
  const missingExpiryCaseId = 'child_1_unassigned_specialist';
  await assertAllowed('Admin seeds case with MISSING consentExpiresAt',
    docSet(`specialistCases/${missingExpiryCaseId}`, {
      childId: 'child_1',
      parentId: 'parent_1',
      specialistId: 'unassigned_specialist',
      status: 'accepted',
      authorizedDataCategories: ['child_profile', 'observations'],
      createdAt: new Date()
      // consentExpiresAt is missing!
    }, tokenAdmin));

  await assertDenied('Specialist with MISSING consent expiry CANNOT access child document',
    docGet('children/child_1', tokenUnassigned));

  // Test Expired Case Access
  const expiredCaseId = 'child_2_unassigned_specialist';
  await assertAllowed('Admin seeds case with past expiration date',
    docSet(`specialistCases/${expiredCaseId}`, {
      childId: 'child_2',
      parentId: 'parent_2',
      specialistId: 'unassigned_specialist',
      status: 'accepted',
      authorizedDataCategories: ['child_profile', 'observations'],
      consentExpiresAt: new Date(Date.now() - 3600000), // 1 hour in the past!
      createdAt: new Date()
    }, tokenAdmin));

  await assertDenied('Specialist with EXPIRED consent CANNOT read child_2',
    docGet('children/child_2', tokenUnassigned));

  // -----------------------------------------------------------------
  // 6c. Parent Consent Revocation
  // -----------------------------------------------------------------
  console.log('\n--- 6c. Testing Parent Consent Revocation ---');
  await assertAllowed('Parent 1 revokes case consent',
    docUpdate(`specialistCases/${caseId1}`, {
      status: 'revoked',
      revokedAt: new Date()
    }, tokenParent1));

  await assertDenied('Guide specialist cannot un-revoke case',
    docUpdate(`specialistCases/${caseId1}`, {
      status: 'accepted',
      revokedAt: null
    }, tokenGuide));

  // Once revoked, guide specialist loses access IMMEDIATELY
  await assertDenied('Revoked guide specialist CANNOT read child_1 anymore',
    docGet('children/child_1', tokenGuide));

  await assertDenied('Revoked guide specialist CANNOT read child_1 skillProfiles anymore',
    docGet('skillProfiles/child_1', tokenGuide));

  // -----------------------------------------------------------------
  // 7. Clinical vs Learning Guide Observation Controls
  // -----------------------------------------------------------------
  console.log('\n--- 7. Testing Clinical vs Learning Guide Observation Controls ---');
  // Seed active case for Clinical Specialist on child_1 with observations consent
  const clinicalCaseId = 'child_1_clinical_specialist';
  await assertAllowed('Admin creates active case for clinical specialist with observations category',
    docSet(`specialistCases/${clinicalCaseId}`, {
      childId: 'child_1',
      parentId: 'parent_1',
      specialistId: 'clinical_specialist',
      status: 'active',
      authorizedDataCategories: ['observations', 'domain_scores'],
      consentExpiresAt: new Date(Date.now() + 86400000),
      createdAt: new Date()
    }, tokenAdmin));

  // Seed active case for Learning Guide on child_2 with observations consent
  const guideCaseId2 = 'child_2_guide_specialist';
  await assertAllowed('Admin creates active case for guide specialist on child_2 with observations category',
    docSet(`specialistCases/${guideCaseId2}`, {
      childId: 'child_2',
      parentId: 'parent_2',
      specialistId: 'guide_specialist',
      status: 'active',
      authorizedDataCategories: ['observations', 'activity_history'],
      consentExpiresAt: new Date(Date.now() + 86400000),
      createdAt: new Date()
    }, tokenAdmin));

  // Learning Guide tests on child_2
  await assertAllowed('Learning Guide can submit educational guidance observation',
    docCreateInCollection('llgObservations', {
      childId: 'child_2',
      llgId: 'guide_specialist',
      llgName: 'Guide Gary',
      authorRole: 'llg',
      isClinicalGrade: false,
      flagEventId: 'flag_1',
      observation: 'Child shows good focus during block building.',
      recommendations: ['Practice counting with blocks'],
      severity: 'guidance',
      referralNeeded: false,
      recordedAt: new Date(),
      isImmutable: true
    }, tokenGuide));

  await assertDenied('Learning Guide CANNOT submit "critical" severity observation',
    docCreateInCollection('llgObservations', {
      childId: 'child_2',
      llgId: 'guide_specialist',
      llgName: 'Guide Gary',
      authorRole: 'llg',
      isClinicalGrade: false,
      observation: 'Critical concern',
      recommendations: ['Immediate clinic'],
      severity: 'critical', // FORBIDDEN for non-clinical
      referralNeeded: false,
      recordedAt: new Date(),
      isImmutable: true
    }, tokenGuide));

  await assertDenied('Learning Guide CANNOT submit referralNeeded: true',
    docCreateInCollection('llgObservations', {
      childId: 'child_2',
      llgId: 'guide_specialist',
      llgName: 'Guide Gary',
      authorRole: 'llg',
      isClinicalGrade: false,
      observation: 'Medical referral test',
      recommendations: ['See a neurologist'],
      severity: 'guidance',
      referralNeeded: true, // FORBIDDEN for non-clinical
      recordedAt: new Date(),
      isImmutable: true
    }, tokenGuide));

  await assertDenied('Observation with unwhitelisted extra field is rejected',
    docCreateInCollection('llgObservations', {
      childId: 'child_2',
      llgId: 'guide_specialist',
      llgName: 'Guide Gary',
      authorRole: 'llg',
      isClinicalGrade: false,
      observation: 'Good progress',
      recommendations: ['Continue reading'],
      severity: 'guidance',
      referralNeeded: false,
      hackedField: 'malicious payload', // Not whitelisted!
      recordedAt: new Date(),
      isImmutable: true
    }, tokenGuide));

  // Clinical Specialist tests on child_1
  await assertAllowed('Clinical Specialist CAN submit "critical" severity and referralNeeded: true',
    docCreateInCollection('llgObservations', {
      childId: 'child_1',
      llgId: 'clinical_specialist',
      llgName: 'Dr. Clara',
      authorRole: 'clinical_specialist',
      isClinicalGrade: true,
      flagEventId: 'flag_2',
      observation: 'Observed significant developmental regression.',
      recommendations: ['Formal pediatric evaluation recommended'],
      severity: 'critical',
      referralNeeded: true,
      recordedAt: new Date(),
      isImmutable: true
    }, tokenClinical));

  // Observations are immutable
  await assertDenied('Observations cannot be modified (immutable audit trail)',
    docSet('llgObservations/any_obs', { observation: 'Tampered' }, tokenClinical));
  await assertDenied('Observations cannot be deleted',
    docDelete('llgObservations/any_obs', tokenClinical));

  // -----------------------------------------------------------------
  // -----------------------------------------------------------------
  // 8. Authoritative Growth Data & Progression Protection (Requirements 1 & 7)
  // -----------------------------------------------------------------
  console.log('\n--- 8. Testing Authoritative Growth Data & Progression Protection ---');
  // Client write to scoreEvents is strictly DENIED to prevent parent fabrication of scores
  await assertDenied('Parent 1 CANNOT create scoreEvents directly (deny client fabrication)',
    docCreateInCollection('scoreEvents', {
      childId: 'child_1',
      submittedByParentId: 'parent_1',
      activityId: 'act_101',
      activityTitle: 'Shape Sorter',
      scoreBefore: 50.0,
      scoreAfter: 55.0,
      appliedScoreDelta: 5.0,
      createdAt: new Date(),
      isImmutable: true
    }, tokenParent1));

  await assertDenied('Parent 2 CANNOT submit score event for Parent 1 child_1',
    docCreateInCollection('scoreEvents', {
      childId: 'child_1',
      submittedByParentId: 'parent_2',
      activityId: 'act_101',
      scoreBefore: 50.0,
      scoreAfter: 55.0,
      appliedScoreDelta: 5.0
    }, tokenParent2));

  // Admin SDK bypass can seed authoritative score event for read verification
  await assertAllowed('Admin SDK seeds scoreEvents for child_1',
    docSet('scoreEvents/evt_seed_1', {
      childId: 'child_1',
      activityId: 'act_101',
      scoreBefore: 50.0,
      scoreAfter: 55.0,
      appliedScoreDelta: 5.0,
      createdAt: new Date()
    }, tokenBypass));

  await assertAllowed('Parent 1 can read authoritative score event for child_1',
    docGet('scoreEvents/evt_seed_1', tokenParent1));
  await assertDenied('Parent 2 CANNOT read score event for Parent 1 child_1',
    docGet('scoreEvents/evt_seed_1', tokenParent2));

  await assertDenied('Score events cannot be updated by client SDK',
    docSet('scoreEvents/evt_seed_1', { scoreAfter: 100.0 }, tokenParent1));
  await assertDenied('Score events cannot be deleted by client SDK',
    docDelete('scoreEvents/evt_seed_1', tokenParent1));

  // Direct client writes to skillProfiles are DENIED
  await assertDenied('Parent 1 CANNOT write arbitrary score (> 100.0) in skillProfiles',
    docSet('skillProfiles/child_1', { cognitive: 250.0, language: 70.0 }, tokenParent1));
  await assertDenied('Parent 1 CANNOT write negative score in skillProfiles',
    docSet('skillProfiles/child_1', { cognitive: -15.0, language: 70.0 }, tokenParent1));
  await assertDenied('Parent 1 CANNOT write valid range score directly in skillProfiles (backend authority required)',
    docSet('skillProfiles/child_1', { cognitive: 75.0, language: 70.0 }, tokenParent1));

  // Direct client writes to journeyProgress are DENIED
  await assertDenied('Parent 1 CANNOT jump levels arbitrarily in journeyProgress (currentLevel not unlocked)',
    docSet('journeyProgress/child_1', { currentLevel: 4, unlockedLevels: [1] }, tokenParent1));
  await assertDenied('Parent 1 CANNOT write valid level progression directly in journeyProgress (backend authority required)',
    docSet('journeyProgress/child_1', { currentLevel: 2, unlockedLevels: [1, 2] }, tokenParent1));
  await assertDenied('Parent 1 CANNOT write scoreLedger directly',
    docSet('scoreLedger/child_1', { childId: 'child_1' }, tokenParent1));

  // -----------------------------------------------------------------
  // 9. Flags, Notifications & Audit Trail Anti-Forgery (Requirements 2, 5 & 7)
  // -----------------------------------------------------------------
  console.log('\n--- 9. Testing Flags, Notifications & Audit Log Protections ---');
  await assertAllowed('Parent 1 can create flag for own child_1',
    docCreateInCollection('flags', {
      childId: 'child_1',
      domain: 'motor',
      parentResponse: 'approved',
      isImmutable: true,
      createdAt: new Date()
    }, tokenParent1));

  await assertDenied('Parent 2 CANNOT fabricate flag for Parent 1 child_1',
    docCreateInCollection('flags', {
      childId: 'child_1',
      domain: 'motor',
      parentResponse: 'approved'
    }, tokenParent2));

  await assertDenied('Flags cannot be deleted or updated (immutable)',
    docDelete('flags/any_flag', tokenParent1));

  // Requirement 2: ALL client applications cannot create, update, or delete adminAuditLogs, INCLUDING administrator clients!
  await assertDenied('Parent 1 client CANNOT write directly to adminAuditLogs',
    docCreateInCollection('adminAuditLogs', {
      actorId: 'parent_1',
      action: 'parent_responded_flag',
      targetId: 'child_1',
      createdAt: new Date()
    }, tokenParent1));

  await assertDenied('Specialist client CANNOT write directly to adminAuditLogs',
    docCreateInCollection('adminAuditLogs', {
      actorId: 'guide_specialist',
      action: 'specialist_reviewed',
      targetId: 'child_1'
    }, tokenGuide));

  await assertDenied('Administrator client SDK CANNOT write directly to adminAuditLogs (must route via trusted backend)',
    docSet('adminAuditLogs/audit_sample', { actorId: 'admin_user', action: 'system_check' }, tokenAdmin));

  await assertDenied('Administrator client SDK CANNOT create in adminAuditLogs collection',
    docCreateInCollection('adminAuditLogs', {
      actorId: 'admin_user',
      action: 'security_audit_checkpoint',
      targetId: 'child_1',
      createdAt: new Date()
    }, tokenAdmin));

  // Authoritative seeding via Admin SDK / owner bypass for audit log read verification
  await assertAllowed('Admin SDK seeds audit log entry via trusted backend bypass',
    docSet('adminAuditLogs/audit_sample', { actorId: 'admin_user', action: 'system_check' }, tokenBypass));

  await assertDenied('Audit logs CANNOT be read by non-admins (parents)',
    docGet('adminAuditLogs/audit_sample', tokenParent1));
  await assertDenied('Audit logs CANNOT be read by non-admins (specialists)',
    docGet('adminAuditLogs/audit_sample', tokenGuide));
  await assertAllowed('Audit logs CAN be read by admins',
    docGet('adminAuditLogs/audit_sample', tokenAdmin));

  // Notifications Anti-Spoofing & Case Lifecycle Verification (Requirements 5 & 7)
  await assertAllowed('Admin SDK seeds notification for parent 1',
    docSet('notifications/notif_parent1', { userId: 'parent_1', title: 'Hello' }, tokenBypass));
  await assertAllowed('Parent 1 reads own notification',
    docGet('notifications/notif_parent1', tokenParent1));
  await assertDenied('Parent 2 CANNOT read Parent 1 notification',
    docGet('notifications/notif_parent1', tokenParent2));

  // Parent 1 notifying assigned specialist for valid consultation
  await assertAllowed('Parent 1 can send case notification to assigned specialist (clinical_specialist)',
    docCreateInCollection('notifications', {
      userId: 'clinical_specialist',
      childId: 'child_1',
      title: 'Consultation Request'
    }, tokenParent1));

  // Spoofed notification: Parent 1 tries to send notification to unrelated Parent 2
  await assertDenied('Parent 1 CANNOT fabricate notification for unrelated Parent 2 (spoofing blocked)',
    docCreateInCollection('notifications', {
      userId: 'parent_2',
      childId: 'child_1',
      title: 'Spoofed Notification'
    }, tokenParent1));

  // Disallowed fields payload test
  await assertDenied('Notification with disallowed arbitrary fields is rejected',
    docCreateInCollection('notifications', {
      userId: 'clinical_specialist',
      childId: 'child_1',
      title: 'Valid title',
      maliciousField: 'exploit_data'
    }, tokenParent1));

  // Notification through revoked case is rejected
  // Recall: caseId1 ('child_1_guide_specialist') was revoked in Section 6c!
  await assertDenied('Parent 1 CANNOT send notification through REVOKED consultation case',
    docCreateInCollection('notifications', {
      userId: 'guide_specialist',
      childId: 'child_1',
      title: 'Revoked contact attempt'
    }, tokenParent1));

  // Notification through expired case is rejected
  // Recall: expiredCaseId ('child_2_unassigned_specialist') has consentExpiresAt in past
  await assertDenied('Parent 2 CANNOT send notification through EXPIRED consultation case',
    docCreateInCollection('notifications', {
      userId: 'unassigned_specialist',
      childId: 'child_2',
      title: 'Expired contact attempt'
    }, tokenParent2));

  // User notifying self
  await assertAllowed('User can create notification for themselves',
    docCreateInCollection('notifications', {
      userId: 'parent_1',
      title: 'Self reminder'
    }, tokenParent1));

  // -----------------------------------------------------------------
  // 10. Saved Activities, Stories & Feedback
  // -----------------------------------------------------------------
  console.log('\n--- 10. Testing Saved Activities, Stories & Feedback ---');
  await assertAllowed('Parent 1 saves activity for own child_1',
    docCreateInCollection('savedActivities', {
      userId: 'parent_1',
      childId: 'child_1',
      title: 'Fun with Shapes',
      savedAt: new Date()
    }, tokenParent1));

  await assertDenied('Parent 2 CANNOT save activity for Parent 1 child_1',
    docCreateInCollection('savedActivities', {
      userId: 'parent_2',
      childId: 'child_1', // Not parent_2's child!
      title: 'Fun with Shapes'
    }, tokenParent2));

  await assertAllowed('Parent 1 submits feedback for own child_1',
    docCreateInCollection('feedback', {
      childId: 'child_1',
      parentId: 'parent_1',
      activityId: 'act_101',
      childResponse: 'loved',
      createdAt: new Date()
    }, tokenParent1));

  await assertDenied('Parent 2 CANNOT submit feedback for Parent 1 child_1',
    docCreateInCollection('feedback', {
      childId: 'child_1',
      parentId: 'parent_2',
      activityId: 'act_101'
    }, tokenParent2));

  // -----------------------------------------------------------------
  // 10b. Global Activity Publishing & Specialist Profile Isolation (Requirements 4, 6 & 7)
  // -----------------------------------------------------------------
  console.log('\n--- 10b. Testing Global Activity Publishing & Specialist Isolation ---');
  // Global activity publishing: restricted to admin only
  await assertDenied('Specialist CANNOT publish global activity',
    docSet('activities/act_global_1', { title: 'Global Math', createdBy: 'guide_specialist' }, tokenGuide));
  await assertDenied('Parent CANNOT publish global activity',
    docSet('activities/act_global_1', { title: 'Global Math', createdBy: 'parent_1' }, tokenParent1));
  await assertAllowed('Admin CAN publish global activity',
    docSet('activities/act_global_1', { title: 'Global Math', createdBy: 'admin_user' }, tokenAdmin));

  // Specialist Certificate & Profile Privacy Isolation
  await assertDenied('Parent CANNOT read sensitive specialist certificate verifications',
    docGet('llgCertificateVerifications/cert_1', tokenParent1));
  await assertDenied('Unassigned specialist CANNOT read other specialist certificate verifications',
    docGet('llgCertificateVerifications/cert_1', tokenUnassigned));
  await assertAllowed('Specialist CAN read own certificate verification',
    docGet('llgCertificateVerifications/cert_1', tokenPendingSpec));
  await assertAllowed('Admin CAN read specialist certificate verification',
    docGet('llgCertificateVerifications/cert_1', tokenAdmin));

  // Specialist Private User Profile Document
  await assertDenied('Parent CANNOT read private specialist user document',
    docGet('users/guide_specialist', tokenParent1));
  await assertAllowed('Specialist CAN read own user document',
    docGet('users/guide_specialist', tokenGuide));

  // Unverified specialist profile isolation
  await assertDenied('Parent CANNOT read unverified specialist profile',
    docGet('llgProfiles/pending_spec', tokenParent1));
  await assertAllowed('Specialist CAN read own unverified profile',
    docGet('llgProfiles/pending_spec', tokenPendingSpec));
  await assertAllowed('Parent CAN read verified specialist public directory profile',
    docGet('llgProfiles/guide_specialist', tokenParent1));

  // -----------------------------------------------------------------
  // 11. Query Behavior & Cross-Tenant Isolation (Requirement 8)
  // -----------------------------------------------------------------
  console.log('\n--- 11. Testing Query Behavior & Cross-Tenant Isolation ---');
  await assertAllowed('Specialist can query their own assigned cases',
    queryCollection('specialistCases', 'specialistId', 'guide_specialist', tokenGuide));

  await assertDenied('Specialist CANNOT query other specialists cases',
    queryCollection('specialistCases', 'specialistId', 'clinical_specialist', tokenGuide));

  await assertAllowed('Parent can query their own consultation requests',
    queryCollection('specialistCases', 'parentId', 'parent_1', tokenParent1));

  await assertDenied('Parent CANNOT query other parents consultation requests',
    queryCollection('specialistCases', 'parentId', 'parent_2', tokenParent1));

  await assertDenied('Specialist CANNOT perform unfiltered collection scan on specialistCases',
    docGet('specialistCases', tokenGuide));

  await assertDenied('Parent CANNOT perform unfiltered collection scan on specialistCases',
    docGet('specialistCases', tokenParent1));

  // Summary
  console.log('\n===============================================================');
  console.log(`📊 Test Results: ${passedCount} PASSED, ${failedCount} FAILED`);
  console.log('===============================================================\n');

  if (failedCount > 0) {
    process.exit(1);
  }
}

runAllTests().catch((err) => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
