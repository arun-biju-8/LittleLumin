// lib/services/curated_packs_service.dart

class CuratedPacksService {
  static const Map<String, Map<String, dynamic>> packs = {
    '5_minute': {
      'name': '5-Minute Activities',
      'emoji': '🎨',
      'description': 'Quick wins for busy days',
      'filter': {'maxDuration': 5},
    },
    'bedtime': {
      'name': 'Bedtime Wind-Down',
      'emoji': '🌙',
      'description': 'Calming activities for bedtime',
      'filter': {'skillTypes': ['emotional', 'language']},
    },
    'rainy_day': {
      'name': 'Rainy Day Fun',
      'emoji': '🌧️',
      'description': 'Indoor activities for days at home',
      'filter': {'skillTypes': ['cognitive', 'creative']},
    },
    'school_prep': {
      'name': 'School Prep',
      'emoji': '🎒',
      'description': 'Prepare for school success',
      'filter': {'skillTypes': ['cognitive', 'language', 'social']},
    },
    'calming': {
      'name': 'Calming Activities',
      'emoji': '🧘',
      'description': 'Gentle moments to reset',
      'filter': {'skillTypes': ['emotional']},
    },
  };
}
