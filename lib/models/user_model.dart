// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  // ============================================
  // 1. IDENTITY & CONTACT
  // ============================================
  String uid;
  String name;
  String email;
  String userType; // 'parent', 'llg', 'admin', 'llg_pending', 'rejected'
  String status; // 'active', 'inactive', 'pending', 'rejected'
  DateTime createdAt;
  String phone;
  String photoUrl;

  // ============================================
  // 2. PROFESSIONAL CREDENTIALS (LLG Only)
  // ============================================
  String qualification;
  String license;
  String experience;
  String specialization;
  String organization;
  String associations;

  // ============================================
  // 3. BIO & PHILOSOPHY (LLG Only)
  // ============================================
  String bio;
  String philosophy;
  String languages;

  // ============================================
  // 4. LOCATION & AVAILABILITY (LLG Only)
  // ============================================
  String region;
  String availability;
  String consultationMode;

  // ============================================
  // 5. CERTIFICATE & PROOF LINKS (LLG Only)
  // ============================================
  String? qualificationCertificateLink;
  String? licenseCertificateLink;
  String? experienceCertificateLink;
  String? identityProofLink;
  String? professionalAssociationLink;

  // ============================================
  // 6. VERIFICATION STATUS
  // ============================================
  String? verificationStatus; // 'pending', 'approved', 'rejected'
  bool isVerified;
  String? rejectionReason;
  DateTime? submittedAt;
  DateTime? verifiedAt;

  // ============================================
  // 7. SOCIAL PROOF & TRANSPARENCY
  // ============================================
  String parentsSupported;
  String rating;
  String recommendationRate;
  String testimonials;
  DateTime? updatedAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.userType = 'parent',
    this.status = 'active',
    required this.createdAt,
    this.phone = '',
    this.photoUrl = '',
    this.qualification = '',
    this.license = '',
    this.experience = '',
    this.specialization = '',
    this.organization = '',
    this.associations = '',
    this.bio = '',
    this.philosophy = '',
    this.languages = '',
    this.region = '',
    this.availability = '',
    this.consultationMode = 'Online & In-Person',
    this.qualificationCertificateLink,
    this.licenseCertificateLink,
    this.experienceCertificateLink,
    this.identityProofLink,
    this.professionalAssociationLink,
    this.verificationStatus,
    this.isVerified = false,
    this.rejectionReason,
    this.submittedAt,
    this.verifiedAt,
    this.parentsSupported = '',
    this.rating = '',
    this.recommendationRate = '',
    this.testimonials = '',
    this.updatedAt,
  });

  // ============================================
  // TO MAP (Firestore)
  // ============================================
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'userType': userType,
      'status': status,
      'createdAt': createdAt,
      'phone': phone,
      'photoUrl': photoUrl,

      // Professional Credentials
      'qualification': qualification,
      'license': license,
      'experience': experience,
      'specialization': specialization,
      'organization': organization,
      'associations': associations,

      // Bio & Philosophy
      'bio': bio,
      'philosophy': philosophy,
      'languages': languages,

      // Location & Availability
      'region': region,
      'availability': availability,
      'consultationMode': consultationMode,

      // Certificate Links
      'qualificationCertificateLink': qualificationCertificateLink,
      'licenseCertificateLink': licenseCertificateLink,
      'experienceCertificateLink': experienceCertificateLink,
      'identityProofLink': identityProofLink,
      'professionalAssociationLink': professionalAssociationLink,

      // Verification Status
      'verificationStatus': verificationStatus,
      'isVerified': isVerified,
      'rejectionReason': rejectionReason,
      'submittedAt': submittedAt,
      'verifiedAt': verifiedAt,

      // Social Proof
      'parentsSupported': parentsSupported,
      'rating': rating,
      'recommendationRate': recommendationRate,
      'testimonials': testimonials,
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
    };
  }

  // ============================================
  // FROM MAP (Firestore)
  // ============================================
  factory UserModel.fromMap(dynamic first, [dynamic second]) {
    final Map<String, dynamic> data;
    final String uid;
    if (first is String && second is Map<String, dynamic>) {
      uid = first;
      data = second;
    } else if (first is Map<String, dynamic>) {
      data = first;
      uid = (second is String ? second : null) ?? data['uid'] ?? '';
    } else {
      data = {};
      uid = '';
    }
    return UserModel(
      uid: uid,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      userType: data['userType'] ?? 'parent',
      status: data['status'] ?? 'active',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      phone: data['phone'] ?? '',
      photoUrl: data['photoUrl'] ?? '',

      qualification: data['qualification'] ?? '',
      license: data['license'] ?? '',
      experience: data['experience'] ?? '',
      specialization: data['specialization'] ?? '',
      organization: data['organization'] ?? '',
      associations: data['associations'] ?? '',

      bio: data['bio'] ?? '',
      philosophy: data['philosophy'] ?? '',
      languages: data['languages'] ?? '',

      region: data['region'] ?? '',
      availability: data['availability'] ?? '',
      consultationMode: data['consultationMode'] ?? 'Online & In-Person',

      qualificationCertificateLink: data['qualificationCertificateLink'],
      licenseCertificateLink: data['licenseCertificateLink'],
      experienceCertificateLink: data['experienceCertificateLink'],
      identityProofLink: data['identityProofLink'],
      professionalAssociationLink: data['professionalAssociationLink'],

      verificationStatus: data['verificationStatus'],
      isVerified: data['isVerified'] ?? false,
      rejectionReason: data['rejectionReason'],
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
      verifiedAt: (data['verifiedAt'] as Timestamp?)?.toDate(),

      parentsSupported: data['parentsSupported'] ?? '',
      rating: data['rating'] ?? '',
      recommendationRate: data['recommendationRate'] ?? '',
      testimonials: data['testimonials'] ?? '',
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  // ============================================
  // HELPER METHODS
  // ============================================
  bool get isLLG => userType == 'llg';
  bool get isLLGPending => userType == 'llg_pending';
  bool get isRejected => userType == 'rejected';
  bool get isAdmin => userType == 'admin';
  bool get isParent => userType == 'parent';
  bool get isActive => status == 'active';
}