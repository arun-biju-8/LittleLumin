// lib/models/milestone_model.dart

class MilestoneModel {
  final String id;
  final String title;
  final String description;
  final String domain; // Communication, Daily Living, Socialization, Motor Skills
  final String icon; // Emoji or icon identifier
  final int targetAge; // 3, 4, 5, 6
  final double requiredScore; // Required percentage (e.g. 50.0 to 85.0)
  final String skillDomain; // Cognitive, Language, Motor, Social, Emotional, Creative

  const MilestoneModel({
    required this.id,
    required this.title,
    required this.description,
    required this.domain,
    required this.icon,
    required this.targetAge,
    required this.requiredScore,
    required this.skillDomain,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'domain': domain,
      'icon': icon,
      'targetAge': targetAge,
      'requiredScore': requiredScore,
      'skillDomain': skillDomain,
    };
  }

  factory MilestoneModel.fromMap(Map<String, dynamic> map) {
    return MilestoneModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      domain: map['domain'] ?? '',
      icon: map['icon'] ?? '🏅',
      targetAge: map['targetAge'] ?? 3,
      requiredScore: (map['requiredScore'] as num?)?.toDouble() ?? 50.0,
      skillDomain: map['skillDomain'] ?? 'Cognitive',
    );
  }
}
