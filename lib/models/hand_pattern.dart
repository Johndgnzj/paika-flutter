/// 特殊牌型
class HandPattern {
  final String id;
  final String name;        // 牌型名稱
  final int referenceTai;   // 參考台數（僅顯示用，不自動加台）
  final bool isSystem;      // true=系統預設，false=使用者自訂

  const HandPattern({
    required this.id,
    required this.name,
    required this.referenceTai,
    this.isSystem = false,
  });

  factory HandPattern.fromJson(Map<String, dynamic> json) {
    return HandPattern(
      id: json['id'] as String,
      name: json['name'] as String,
      referenceTai: json['referenceTai'] as int,
      isSystem: json['isSystem'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'referenceTai': referenceTai,
    'isSystem': isSystem,
  };

  HandPattern copyWith({String? id, String? name, int? referenceTai, bool? isSystem}) {
    return HandPattern(
      id: id ?? this.id,
      name: name ?? this.name,
      referenceTai: referenceTai ?? this.referenceTai,
      isSystem: isSystem ?? this.isSystem,
    );
  }

  // ===== 系統預設牌型 =====
  static const List<HandPattern> systemPatterns = [
    HandPattern(id: 'mengqing_zimo',   name: '門清自摸',  referenceTai: 3,  isSystem: true),
    HandPattern(id: 'miji',            name: '咪幾',      referenceTai: 8,  isSystem: true),
    HandPattern(id: 'dasixi',          name: '大四喜',    referenceTai: 16, isSystem: true),
    HandPattern(id: 'xiaosixi',        name: '小四喜',    referenceTai: 8,  isSystem: true),
    HandPattern(id: 'dasanyuan',       name: '大三元',    referenceTai: 8,  isSystem: true),
    HandPattern(id: 'xiaosanyuan',     name: '小三元',    referenceTai: 4,  isSystem: true),
    HandPattern(id: 'wuanke',          name: '五暗刻',    referenceTai: 8,  isSystem: true),
    HandPattern(id: 'sianke',          name: '四暗刻',    referenceTai: 5,  isSystem: true),
    HandPattern(id: 'sananke',         name: '三暗刻',    referenceTai: 2,  isSystem: true),
    HandPattern(id: 'ziyise',          name: '字一色',    referenceTai: 16, isSystem: true),
    HandPattern(id: 'qingyise',        name: '清一色',    referenceTai: 8,  isSystem: true),
    HandPattern(id: 'hunyise',         name: '混一色',    referenceTai: 4,  isSystem: true),
    HandPattern(id: 'pengpenghu',      name: '碰碰胡',    referenceTai: 4,  isSystem: true),
    HandPattern(id: 'baxianguohai',    name: '八仙過海',  referenceTai: 8,  isSystem: true),
    HandPattern(id: 'qiqiangyi',       name: '七搶一',    referenceTai: 8,  isSystem: true),
    HandPattern(id: 'qianggang',       name: '搶槓',      referenceTai: 1,  isSystem: true),
    HandPattern(id: 'haidilao',        name: '海底撈月',  referenceTai: 1,  isSystem: true),
    HandPattern(id: 'gangshangkaihua', name: '槓上開化',  referenceTai: 1,  isSystem: true),
    HandPattern(id: 'quanqiu',         name: '全求',      referenceTai: 2,  isSystem: true),
    HandPattern(id: 'pinghu',          name: '平胡',      referenceTai: 2,  isSystem: true),
  ];

  /// 取得所有可用牌型（系統 + 自訂）
  static List<HandPattern> allPatterns(List<HandPattern> customPatterns) {
    return [...systemPatterns, ...customPatterns];
  }

  /// 根據 ID 查找牌型名稱（找不到就回傳 ID）
  static String nameById(String id, List<HandPattern> customPatterns) {
    final all = allPatterns(customPatterns);
    try {
      return all.firstWhere((p) => p.id == id).name;
    } catch (_) {
      return id;
    }
  }
}
