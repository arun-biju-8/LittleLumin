// ignore_for_file: constant_identifier_names
// lib/services/llg_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LLGService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Submit a new LLG Guide application and create user credentials
  Future<UserCredential> submitLLGApplication({
    required String name,
    required String email,
    required String password,
    required String qualification,
    required String license,
    required String experience,
    required String specialization,
    required String organization,
    required String bio,
    required String region,
    required String languages,
    required String consultationMode,
    String? phone,
    String? qualificationCertificateLink,
    String? licenseCertificateLink,
    String? experienceCertificateLink,
    String? identityProofLink,
    String? professionalAssociationLink,
  }) async {
    if (name.trim().isEmpty) throw ArgumentError('Name cannot be empty');
    if (email.trim().isEmpty) throw ArgumentError('Email cannot be empty');
    if (password.isEmpty) throw ArgumentError('Password cannot be empty');
    if (qualification.trim().isEmpty) throw ArgumentError('Qualification cannot be empty');
    if (license.trim().isEmpty) throw ArgumentError('License cannot be empty');

    // 1. Create Firebase Auth account
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = userCredential.user!.uid;

    // 2. Update display name in Firebase Auth
    await userCredential.user!.updateDisplayName(name.trim());

    // 3. Create document in 'users' collection
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'phone': phone?.trim() ?? '',
      'userType': 'llg_pending',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'isVerified': false,
      'photoUrl': '',
      'qualification': qualification.trim(),
      'license': license.trim(),
      'experience': experience.trim(),
      'specialization': specialization.trim(),
      'organization': organization.trim(),
      'bio': bio.trim(),
      'languages': languages.trim(),
      'region': region.trim(),
      'consultationMode': consultationMode,
      'qualificationCertificateLink': qualificationCertificateLink?.trim() ?? '',
      'licenseCertificateLink': licenseCertificateLink?.trim() ?? '',
      'experienceCertificateLink': experienceCertificateLink?.trim() ?? '',
      'identityProofLink': identityProofLink?.trim() ?? '',
      'professionalAssociationLink': professionalAssociationLink?.trim() ?? '',
    });

    // 4. Create document in 'llgProfiles' collection
    await _firestore.collection('llgProfiles').doc(uid).set({
      'uid': uid,
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'phone': phone?.trim() ?? '',
      'qualification': qualification.trim(),
      'license': license.trim(),
      'experience': experience.trim(),
      'specialization': specialization.trim(),
      'organization': organization.trim(),
      'bio': bio.trim(),
      'region': region.trim(),
      'languages': languages.trim(),
      'consultationMode': consultationMode,
      'qualificationCertificateLink': qualificationCertificateLink?.trim() ?? '',
      'licenseCertificateLink': licenseCertificateLink?.trim() ?? '',
      'experienceCertificateLink': experienceCertificateLink?.trim() ?? '',
      'identityProofLink': identityProofLink?.trim() ?? '',
      'professionalAssociationLink': professionalAssociationLink?.trim() ?? '',
      'verificationStatus': 'pending',
      'isVerified': false,
      'submittedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'rejectionReason': '',
    });

    return userCredential;
  }

  /// Get all pending LLG applications as a Stream of maps
  Stream<List<Map<String, dynamic>>> getPendingLLGs() {
    return _firestore
        .collection('llgProfiles')
        .where('verificationStatus', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['uid'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Stream of all LLG profiles for Admin verification with optional status filtering
  Stream<QuerySnapshot<Map<String, dynamic>>> getAllLLGProfilesStream({String? statusFilter}) {
    if (statusFilter != null && statusFilter != 'all') {
      return _firestore
          .collection('llgProfiles')
          .where('verificationStatus', isEqualTo: statusFilter)
          .snapshots();
    }
    return _firestore.collection('llgProfiles').snapshots();
  }

  /// Get LLG profile data for a specific UID
  Future<Map<String, dynamic>?> getLLGProfile(String uid) async {
    try {
      final doc = await _firestore.collection('llgProfiles').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['uid'] = doc.id;
        return data;
      }
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        data['uid'] = userDoc.id;
        return data;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Approve an LLG Application (userType: 'llg'). Returns null on success or error string.
  Future<String?> approveLLG(String uid) async {
    if (uid.trim().isEmpty) throw ArgumentError('uid cannot be empty');
    try {
      final batch = _firestore.batch();

      // Update users collection
      final userRef = _firestore.collection('users').doc(uid);
      batch.update(userRef, {
        'userType': 'llg',
        'status': 'active',
        'isVerified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update llgProfiles collection
      final profileRef = _firestore.collection('llgProfiles').doc(uid);
      batch.update(profileRef, {
        'verificationStatus': 'approved',
        'isVerified': true,
        'approvedAt': FieldValue.serverTimestamp(),
        'verifiedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return null; // Success
    } catch (e) {
      return e.toString();
    }
  }

  /// Reject an LLG Application (userType: 'rejected'). Returns null on success or error string.
  Future<String?> rejectLLG(String uid, {String? reason}) async {
    if (uid.trim().isEmpty) throw ArgumentError('uid cannot be empty');
    if (reason != null && reason.trim().isEmpty) throw ArgumentError('Rejection reason cannot be blank');
    try {
      final batch = _firestore.batch();

      // Update users collection
      final userRef = _firestore.collection('users').doc(uid);
      batch.update(userRef, {
        'userType': 'rejected',
        'status': 'rejected',
        'isVerified': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update llgProfiles collection
      final profileRef = _firestore.collection('llgProfiles').doc(uid);
      batch.update(profileRef, {
        'verificationStatus': 'rejected',
        'isVerified': false,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectionReason': reason ?? 'Application did not meet verification criteria.',
      });

      await batch.commit();
      return null; // Success
    } catch (e) {
      return e.toString();
    }
  }

  /// Check if user is verified LLG
  Future<bool> isLLGVerified(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return false;
      return doc.data()?['userType'] == 'llg' && (doc.data()?['isVerified'] ?? false);
    } catch (_) {
      return false;
    }
  }

  /// Check if LLG completed onboarding / profile
  Future<bool> hqasCompletedOnboarding(String uid) async {
    try {
      final doc = await _firestore.collection('llgProfiles').doc(uid).get();
      return doc.exists;
    } catch (_) {
      return true;
    }
  }

  // =========================================================================
  // PER-CERTIFICATE VERIFICATION WORKFLOW (Section 8)
  // =========================================================================

  static const List<String> REQUIRED_CERT_TYPES = [
    'qualification',
    'license',
    'experience',
    'identity',
    'professional',
  ];

  /// Stream certificate verifications for an LLG
  Stream<QuerySnapshot<Map<String, dynamic>>> getCertificateVerificationsStream(String llgId) {
    return _firestore
        .collection('llgCertificateVerifications')
        .where('llgId', isEqualTo: llgId)
        .snapshots();
  }

  /// Verify a single certificate
  Future<void> verifyCertificate({
    required String llgId,
    required String certType,
    required String certUrl,
    required String adminId,
  }) async {
    if (llgId.trim().isEmpty) throw ArgumentError('llgId cannot be empty');
    if (certType.trim().isEmpty) throw ArgumentError('certType cannot be empty');
    if (certUrl.trim().isEmpty) throw ArgumentError('certUrl cannot be empty');

    final verifyId = '${llgId}_$certType';
    final verifyRef = _firestore.collection('llgCertificateVerifications').doc(verifyId);

    // 1. Record immutable certificate verification
    await verifyRef.set({
      'llgId': llgId,
      'certificateType': certType,
      'certificateUrl': certUrl,
      'verifiedByAdminId': adminId,
      'verifiedAt': FieldValue.serverTimestamp(),
      'status': 'verified',
      'rejectionReason': null,
      'isImmutable': true,
    }, SetOptions(merge: true));

    // 2. Log admin action
    await _firestore.collection('adminAuditLogs').add({
      'action': 'certificate_verified',
      'actorId': adminId,
      'actorType': 'admin',
      'targetId': llgId,
      'certType': certType,
      'timestamp': FieldValue.serverTimestamp(),
      'isImmutable': true,
    });

    // 3. Check if all required certificates are now verified
    await _checkAndPromoteIfAllVerified(llgId, adminId);
  }

  /// Reject a single certificate
  Future<void> rejectCertificate({
    required String llgId,
    required String certType,
    required String certUrl,
    required String adminId,
    required String reason,
  }) async {
    if (llgId.trim().isEmpty) throw ArgumentError('llgId cannot be empty');
    if (certType.trim().isEmpty) throw ArgumentError('certType cannot be empty');
    if (reason.trim().isEmpty) throw ArgumentError('Rejection reason cannot be empty');

    final verifyId = '${llgId}_$certType';
    final verifyRef = _firestore.collection('llgCertificateVerifications').doc(verifyId);

    await verifyRef.set({
      'llgId': llgId,
      'certificateType': certType,
      'certificateUrl': certUrl,
      'verifiedByAdminId': adminId,
      'verifiedAt': FieldValue.serverTimestamp(),
      'status': 'rejected',
      'rejectionReason': reason,
      'isImmutable': true,
    }, SetOptions(merge: true));

    // Update LLG profile rejection details
    await _firestore.collection('llgProfiles').doc(llgId).update({
      'verificationStatus': 'pending_reupload',
      'rejectionReason': 'Certificate ($certType) rejected: $reason',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Log admin action
    await _firestore.collection('adminAuditLogs').add({
      'action': 'certificate_rejected',
      'actorId': adminId,
      'actorType': 'admin',
      'targetId': llgId,
      'certType': certType,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
      'isImmutable': true,
    });
  }

  /// Check if all uploaded certificates for LLG are verified
  Future<bool> _checkAndPromoteIfAllVerified(String llgId, String adminId) async {
    final profileDoc = await _firestore.collection('llgProfiles').doc(llgId).get();
    if (!profileDoc.exists) return false;
    final profileData = profileDoc.data()!;

    final Map<String, String> certUrls = {
      'qualification': profileData['qualificationCertificateLink'] ?? '',
      'license': profileData['licenseCertificateLink'] ?? '',
      'experience': profileData['experienceCertificateLink'] ?? '',
      'identity': profileData['identityProofLink'] ?? '',
      'professional': profileData['professionalAssociationLink'] ?? '',
    };

    // Find all certificates that were provided
    final providedCerts = certUrls.entries.where((e) => e.value.trim().isNotEmpty).map((e) => e.key).toList();
    if (providedCerts.isEmpty) return false;

    // Check verification status of each provided certificate
    final verifSnap = await _firestore
        .collection('llgCertificateVerifications')
        .where('llgId', isEqualTo: llgId)
        .where('status', isEqualTo: 'verified')
        .get();

    final verifiedTypes = verifSnap.docs.map((d) => d.data()['certificateType'] as String).toSet();

    final allVerified = providedCerts.every((type) => verifiedTypes.contains(type));

    if (allVerified) {
      // Promote LLG user
      await approveLLG(llgId);

      await _firestore.collection('adminAuditLogs').add({
        'action': 'llg_fully_verified_and_promoted',
        'actorId': adminId,
        'actorType': 'admin',
        'targetId': llgId,
        'timestamp': FieldValue.serverTimestamp(),
        'isImmutable': true,
      });

      return true;
    }

    return false;
  }
}
