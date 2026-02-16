import '../models/game.dart';
import '../models/player.dart';

/// 語音記分解析結果
class VoiceScoringResult {
  final Player? winner;       // 贏家
  final Player? loser;        // 輸家（胡牌時）
  final bool isSelfDraw;      // 是否自摸
  final int? tai;             // 台數
  final String? error;        // 錯誤訊息
  final String recognizedText; // 辨識到的文字

  VoiceScoringResult({
    this.winner,
    this.loser,
    this.isSelfDraw = false,
    this.tai,
    this.error,
    required this.recognizedText,
  });

  bool get isValid => winner != null && tai != null && error == null;
}

/// 語音記分服務
class VoiceScoringService {
  /// 解析語音指令
  /// 
  /// 支援格式：
  /// - 胡牌：「{贏家}胡{輸家}{N}台」例如「小明胡阿華5台」「東家胡南家3台」
  /// - 自摸：「{贏家}自摸{N}台」例如「莊家自摸4台」「西家自摸8台」
  static VoiceScoringResult parse(String text, Game game) {
    // 移除空白
    final cleanText = text.replaceAll(RegExp(r'\s+'), '');

    // 檢測是否為自摸
    final isSelfDraw = cleanText.contains('自摸');

    if (isSelfDraw) {
      return _parseSelfDraw(cleanText, game);
    } else if (cleanText.contains('胡')) {
      return _parseWin(cleanText, game);
    } else {
      return VoiceScoringResult(
        recognizedText: text,
        error: '無法辨識指令格式。請說「某某胡某某幾台」或「某某自摸幾台」',
      );
    }
  }

  /// 解析自摸指令
  static VoiceScoringResult _parseSelfDraw(String text, Game game) {
    // 嘗試提取台數
    final tai = _extractTai(text);
    
    // 嘗試找到贏家（自摸者）
    // 格式：{贏家}自摸{N}台
    final selfDrawIndex = text.indexOf('自摸');
    if (selfDrawIndex == -1) {
      return VoiceScoringResult(
        recognizedText: text,
        error: '無法找到「自摸」關鍵字',
      );
    }

    final winnerText = text.substring(0, selfDrawIndex);
    final winner = _findPlayer(winnerText, game);

    if (winner == null) {
      return VoiceScoringResult(
        recognizedText: text,
        tai: tai,
        isSelfDraw: true,
        error: '無法辨識玩家「$winnerText」',
      );
    }

    return VoiceScoringResult(
      recognizedText: text,
      winner: winner,
      isSelfDraw: true,
      tai: tai,
    );
  }

  /// 解析胡牌指令
  static VoiceScoringResult _parseWin(String text, Game game) {
    // 嘗試提取台數
    final tai = _extractTai(text);

    // 嘗試找到贏家和輸家
    // 格式：{贏家}胡{輸家}{N}台
    final huIndex = text.indexOf('胡');
    if (huIndex == -1) {
      return VoiceScoringResult(
        recognizedText: text,
        error: '無法找到「胡」關鍵字',
      );
    }

    final winnerText = text.substring(0, huIndex);
    final afterHu = text.substring(huIndex + 1);

    // 從「胡」之後的文字中提取輸家（移除台數部分）
    var loserText = afterHu;
    final taiMatch = RegExp(r'\d+').firstMatch(afterHu);
    if (taiMatch != null) {
      loserText = afterHu.substring(0, taiMatch.start);
    }
    loserText = loserText.replaceAll('台', '').trim();

    final winner = _findPlayer(winnerText, game);
    final loser = _findPlayer(loserText, game);

    if (winner == null) {
      return VoiceScoringResult(
        recognizedText: text,
        tai: tai,
        loser: loser,
        error: '無法辨識贏家「$winnerText」',
      );
    }

    if (loser == null) {
      return VoiceScoringResult(
        recognizedText: text,
        winner: winner,
        tai: tai,
        error: '無法辨識輸家「$loserText」',
      );
    }

    return VoiceScoringResult(
      recognizedText: text,
      winner: winner,
      loser: loser,
      tai: tai,
    );
  }

  /// 提取台數
  static int? _extractTai(String text) {
    // 先嘗試阿拉伯數字
    final match = RegExp(r'\d+').firstMatch(text);
    if (match != null) {
      return int.tryParse(match.group(0)!);
    }

    // 嘗試中文數字
    return _chineseToNumber(text);
  }

  /// 中文數字轉阿拉伯數字
  static int? _chineseToNumber(String text) {
    final map = {
      '一': 1, '二': 2, '三': 3, '四': 4, '五': 5,
      '六': 6, '七': 7, '八': 8, '九': 9, '十': 10,
      '壹': 1, '貳': 2, '參': 3, '肆': 4, '伍': 5,
      '陸': 6, '柒': 7, '捌': 8, '玖': 9, '拾': 10,
    };

    // 簡單匹配（例如「三台」「五台」）
    for (final entry in map.entries) {
      if (text.contains(entry.key)) {
        return entry.value;
      }
    }

    // 處理「十幾」的情況（例如「十二台」）
    if (text.contains('十')) {
      final after = text.substring(text.indexOf('十') + 1);
      for (final entry in map.entries) {
        if (after.contains(entry.key) && entry.value < 10) {
          return 10 + entry.value;
        }
      }
      return 10; // 只有「十」
    }

    return null;
  }

  /// 根據名稱或風位找玩家
  static Player? _findPlayer(String identifier, Game game) {
    identifier = identifier.trim();
    if (identifier.isEmpty) return null;

    // 1. 檢查是否為風位
    final windMap = {
      '東': 0, '東家': 0,
      '南': 1, '南家': 1,
      '西': 2, '西家': 2,
      '北': 3, '北家': 3,
    };

    if (windMap.containsKey(identifier)) {
      final seatIndex = windMap[identifier]!;
      // players 的 index 就是座位
      if (seatIndex < game.players.length) {
        return game.players[seatIndex];
      }
    }

    // 2. 檢查是否為莊家
    if (identifier == '莊' || identifier == '莊家') {
      return game.dealer;
    }

    // 3. 模糊匹配玩家名稱
    for (final player in game.players) {
      // 完全匹配
      if (player.name == identifier) {
        return player;
      }
      // 部分匹配（玩家名稱包含輸入文字）
      if (player.name.contains(identifier)) {
        return player;
      }
      // 反向匹配（輸入文字包含玩家名稱）
      if (identifier.contains(player.name)) {
        return player;
      }
    }

    return null;
  }
}
