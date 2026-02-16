import 'package:flutter/material.dart';

/// 應用常數
class AppConstants {
  // 可選的玩家 emoji（共 32 個）
  // 第一排：十二生肖
  // 第二排：原有動物
  // 第三排～四排：其他有趣動物
  static const List<String> availableEmojis = [
    '🐭', '🐮', '🐯', '🐰', '🐉', '🐍', '🐴', '🐑', // 十二生肖
    '🐵', '🐔', '🐶', '🐷', '🦁', '🐱', '🐸', '🐼', // 十二生肖 + 原有
    '🐻', '🦊', '🦅', '🦉', '🐧', '🦆', '🦄', '🐺', // 原有 + 趣味
    '🦈', '🐬', '🦜', '🐙', '🦀', '🐝', '🦋', '🐳', // 趣味
  ];

  // 預設玩家 emoji（新遊戲時使用前四個）
  static const List<String> defaultEmojis = ['🦁', '🐱', '🐸', '🐼'];
  
  // 預設玩家名稱
  static const List<String> defaultNames = ['東家', '南家', '西家', '北家'];
  
  // 風位名稱
  static const List<String> windNames = ['東', '南', '西', '北'];
  
  // 常用台數
  static const List<int> commonTai = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 16];
  
  // 顏色
  static const Color primaryGold = Color(0xFFB8860B);
  static const Color tableGreen = Color(0xFF0B6623);
  static const Color winColor = Color(0xFF4CAF50);
  static const Color loseColor = Color(0xFFE57373);
  static const Color dealerColor = Color(0xFFFFC022);
  
  // 尺寸
  static const double playerCardWidth = 150.0;
  static const double playerCardBorderRadius = 16.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
}
