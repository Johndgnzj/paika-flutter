import 'package:flutter/material.dart';

/// 應用常數
class AppConstants {
  // 預設玩家 emoji
  static const List<String> defaultEmojis = ['🦁', '🐱', '🐸', '🐼'];
  
  // 預設玩家名稱
  static const List<String> defaultNames = ['東家', '南家', '西家', '北家'];
  
  // 風位名稱
  static const List<String> windNames = ['東', '南', '西', '北'];
  
  // 常用台數
  static const List<int> commonTai = [2, 4, 6, 8, 10, 12, 16];
  
  // 顏色
  static const Color mahjongGreen = Color(0xFF0B6623);
  static const Color winColor = Color(0xFF4CAF50);
  static const Color loseColor = Color(0xFFE57373);
  static const Color dealerColor = Color(0xFFFF5722);
  
  // 尺寸
  static const double playerCardSize = 120.0;
  static const double playerCardBorderRadius = 16.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
}
