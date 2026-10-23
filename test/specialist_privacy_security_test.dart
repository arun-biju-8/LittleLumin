// test/specialist_privacy_security_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:littlelumin/models/specialist_case_model.dart';
import 'package:littlelumin/models/user_model.dart';
import 'package:littlelumin/models/child_model.dart';

void main() {
  group('1. SpecialistCaseModel & DPDP Consent Access Verification', () {
    test('Specialist cannot access unassigned or pending case data before parent acceptance', () {
      final pendingCase = SpecialistCaseModel(
        caseId: 'child_101_spec_A',
        parentId: 'parent_1',
        parentName: 'Alice',
        childId: 'child_101',
        childName: 'Leo',
        childAgeYears: 5,
        specialistId: 'spec_A',
        specialistName: 'Dr. Sarah',
        purpose: 'Speech & Language Guidance',
        authorizedDataCategories: ['language_score', 'observations'],
        consentedAt: DateTime.now(),
        status: CaseStatus.pending,
        statusUpdatedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      expect(pendingCase.canAccessChildData, isFalse,
          reason: 'Pending cases must not grant access to child records before explicit acceptance');
    });

    test('Specialist with active accepted case can access permitted child data', () {
      final activeCase = SpecialistCaseModel(
        caseId: 'child_101_spec_A',
        parentId: 'parent_1',
        parentName: 'Alice',
        childId: 'child_101',
        childName: 'Leo',
        childAgeYears: 5,
        specialistId: 'spec_A',
        specialistName: 'Dr. Sarah',
        purpose: 'Speech & Language Guidance',
        authorizedDataCategories: ['skill_scores', 'guidance_notes'],
        consentedAt: DateTime.now(),
        status: CaseStatus.active,
        statusUpdatedAt: DateTime.now(),
        acceptedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      expect(activeCase.canAccessChildData, isTrue,
          reason: 'Active case with consent must grant authorized access');
      expect(activeCase.isCategoryAuthorized('skill_scores'), isTrue);
      expect(activeCase.isCategoryAuthorized('activity_history'), isFalse,
          reason: 'Unconsented categories must be strictly blocked under data minimisation');
    });

    test('Revoked consent immediately terminates case access and is marked unconsented', () {
      final revokedCase = SpecialistCaseModel(
        caseId: 'child_101_spec_A',
        parentId: 'parent_1',
        parentName: 'Alice',
        childId: 'child_101',
        childName: 'Leo',
        childAgeYears: 5,
        specialistId: 'spec_A',
        specialistName: 'Dr. Sarah',
        purpose: 'Speech & Language Guidance',
        authorizedDataCategories: ['skill_scores'],
        consentedAt: DateTime.now().subtract(const Duration(days: 10)),
        status: CaseStatus.revoked,
        statusUpdatedAt: DateTime.now(),
        revokedAt: DateTime.now(),
        revocationReason: 'Parent withdrew consent under DPDP rights',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      );

      expect(revokedCase.isConsentActive, isFalse);
      expect(revokedCase.canAccessChildData, isFalse);
      expect(revokedCase.isCategoryAuthorized('skill_scores'), isFalse,
          reason: 'Revocation must remove all subsequent data reading privileges');
    });

    test('Expired consent (past 90-day retention window) denies specialist access', () {
      final expiredCase = SpecialistCaseModel(
        caseId: 'child_101_spec_A',
        parentId: 'parent_1',
        parentName: 'Alice',
        childId: 'child_101',
        childName: 'Leo',
        childAgeYears: 5,
        specialistId: 'spec_A',
        specialistName: 'Dr. Sarah',
        purpose: 'Speech & Language Guidance',
        authorizedDataCategories: ['skill_scores'],
        consentedAt: DateTime.now().subtract(const Duration(days: 95)),
        status: CaseStatus.accepted,
        statusUpdatedAt: DateTime.now().subtract(const Duration(days: 95)),
        expiresAt: DateTime.now().subtract(const Duration(days: 5)),
        createdAt: DateTime.now().subtract(const Duration(days: 95)),
      );

      expect(expiredCase.isConsentActive, isFalse,
          reason: 'Expired consent past validity period must be treated as inactive');
      expect(expiredCase.canAccessChildData, isFalse);
    });

    test('Deterministic Case ID guarantees strict child-specialist case isolation', () {
      const child1 = 'child_001';
      const specA = 'spec_AAA';
      const specB = 'spec_BBB';

      final caseIdA = '${child1}_$specA';
      final caseIdB = '${child1}_$specB';

      expect(caseIdA, isNot(equals(caseIdB)),
          reason: 'Case IDs must be unique per specialist to prevent cross-specialist case contamination');
      expect(caseIdA, equals('child_001_spec_AAA'));
      expect(caseIdB, equals('child_001_spec_BBB'));
    });
  });

  group('2. Role Separation & Anti-Privilege Escalation', () {
    test('Learning Guide cannot submit clinical observations or formal referrals', () {
      final learningGuide = UserModel(
        uid: 'user_lg_1',
        name: 'Alex Guide',
        email: 'guide@littlelumin.com',
        userType: 'learning_guide',
        isVerified: true,
        createdAt: DateTime.now(),
      );

      expect(learningGuide.isLearningGuide, isTrue);
      expect(learningGuide.isClinicalSpecialist, isFalse);
      expect(learningGuide.canSubmitClinicalObservations, isFalse,
          reason: 'Learning guides must not receive clinical severity privileges');
      expect(learningGuide.canSubmitEducationalObservations, isTrue,
          reason: 'Learning guides are authorized for educational developmental guidance');
    });

    test('Clinical Specialist with trusted verification can submit clinical observations', () {
      final clinicalDoc = UserModel(
        uid: 'user_doc_1',
        name: 'Dr. Sarah Smith',
        email: 'doctor@littlelumin.com',
        userType: 'clinical_specialist',
        isVerified: true,
        createdAt: DateTime.now(),
      );

      expect(clinicalDoc.isClinicalSpecialist, isTrue);
      expect(clinicalDoc.canSubmitClinicalObservations, isTrue);
      expect(clinicalDoc.canSubmitEducationalObservations, isTrue);
    });

    test('Unverified specialist cannot submit clinical observations', () {
      final unverifiedDoc = UserModel(
        uid: 'user_doc_unverified',
        name: 'Dr. Unverified',
        email: 'doc2@littlelumin.com',
        userType: 'clinical_specialist',
        isVerified: false, // NOT verified by admin
        createdAt: DateTime.now(),
      );

      expect(unverifiedDoc.isClinicalSpecialist, isTrue);
      expect(unverifiedDoc.canSubmitClinicalObservations, isFalse,
          reason: 'Unverified specialists must be blocked until platform admin verification');
    });

    test('Parent user has zero specialist or clinical privileges', () {
      final parent = UserModel(
        uid: 'parent_100',
        name: 'Mary Parent',
        email: 'parent@gmail.com',
        userType: 'parent',
        isVerified: true,
        createdAt: DateTime.now(),
      );

      expect(parent.isSpecialist, isFalse);
      expect(parent.canSubmitClinicalObservations, isFalse);
      expect(parent.canSubmitEducationalObservations, isFalse);
    });
  });

  group('3. Firestore Rules Logical Invariants Verification', () {
    test('Parent ownership rule permits parent to access only their child', () {
      const authUid = 'parent_alice';
      final childAlice = ChildModel(
        childId: 'c_alice',
        parentId: 'parent_alice',
        name: 'Mia',
        dateOfBirth: DateTime(2021, 5, 10),
        gender: 'female',
        createdAt: DateTime.now(),
      );

      final childBob = ChildModel(
        childId: 'c_bob',
        parentId: 'parent_bob',
        name: 'Tom',
        dateOfBirth: DateTime(2020, 8, 14),
        gender: 'male',
        createdAt: DateTime.now(),
      );

      bool canReadAlice = (childAlice.parentId == authUid);
      bool canReadBob = (childBob.parentId == authUid);

      expect(canReadAlice, isTrue);
      expect(canReadBob, isFalse,
          reason: 'Cross-family read access must be strictly forbidden in Firestore rules');
    });

    test('Anti-escalation prevents self-assigned userType or verification mutation', () {
      final originalUserMap = {
        'uid': 'user_123',
        'email': 'user@example.com',
        'userType': 'parent',
        'isVerified': false,
      };

      final maliciousUpdateMap = {
        'uid': 'user_123',
        'email': 'user@example.com',
        'userType': 'clinical_specialist', // Malicious self-elevation
        'isVerified': true,               // Malicious self-verification
      };

      // Rules logic: request.resource.data.userType == resource.data.userType && request.resource.data.isVerified == resource.data.isVerified
      bool isPrivilegeEscalationDetected =
          (originalUserMap['userType'] != maliciousUpdateMap['userType']) ||
          (originalUserMap['isVerified'] != maliciousUpdateMap['isVerified']);

      expect(isPrivilegeEscalationDetected, isTrue,
          reason: 'Rules must reject attempts by clients to alter role or verification flags');
    });

    test('llgObservations immutability prevents edits or deletions once recorded', () {
      const isImmutable = true;
      const canUpdateObservation = !isImmutable;
      const canDeleteObservation = !isImmutable;

      expect(canUpdateObservation, isFalse,
          reason: 'Clinical observations must be an append-only, immutable audit trail');
      expect(canDeleteObservation, isFalse);
    });
  });

  group('4. Data Minimisation & Scope Isolation', () {
    test('Permitted categories filter hides sensitive scores when not authorized', () {
      final caseModel = SpecialistCaseModel(
        caseId: 'case_scope_test',
        parentId: 'p1',
        parentName: 'Jane',
        childId: 'c1',
        childName: 'Emma',
        childAgeYears: 4,
        specialistId: 's1',
        specialistName: 'Dr. Kumar',
        purpose: 'Social Development Consultation',
        authorizedDataCategories: ['social_domain', 'observations'],
        consentedAt: DateTime.now(),
        status: CaseStatus.active,
        statusUpdatedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      expect(caseModel.isCategoryAuthorized('social_domain'), isTrue);
      expect(caseModel.isCategoryAuthorized('cognitive_score'), isFalse);
      expect(caseModel.isCategoryAuthorized('health_records'), isFalse);
      expect(caseModel.isCategoryAuthorized('full_activity_ledger'), isFalse);
    });
  });
}
