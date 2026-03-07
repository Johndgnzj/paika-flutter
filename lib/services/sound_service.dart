import 'package:audioplayers/audioplayers.dart';
import '../models/player.dart';
import '../models/round.dart';
import '../models/settings.dart';
import 'calculation_service.dart';

/// 音效檔案路徑（ASCII only，避免 Flutter Web URL 編碼問題）
class SoundEffects {
  static const String highTai    = 'audios/result/effect-01.mp3'; // 6台以上
  static const String dealerCons = 'audios/result/effect-02.mp3'; // 莊家連莊
  static const String multiWin   = 'audios/result/effect-03.mp3'; // 一炮多響
  static const String selfDraw   = 'audios/result/effect-04.mp3'; // 自摸
  static const String win        = 'audios/result/effect-05.mp3'; // 胡牌
  static const String draw       = 'audios/result/effect-06.mp3'; // 流局
}

/// 音效服務：依局結果選擇並播放對應音效
class SoundService {
  static AudioPlayer? _player;

  /// 根據局結果選擇對應音效（回傳 asset 路徑，null = 不播）
  static String? selectEffect({
    required Round round,
    required GameSettings settings,
    required List<Player> players,
  }) {
    switch (round.type) {
      case RoundType.draw:
        return SoundEffects.draw;

      case RoundType.win:
      case RoundType.selfDraw:
      case RoundType.multiWin:
        // 規則1：有效台數 >= 6
        final eff = CalculationService.effectiveTaiFromRound(round, settings, players);
        if (eff >= 6) return SoundEffects.highTai;

        // 規則2：莊家連一以上且是本局贏家（限莊家自己）
        if (round.consecutiveWins >= 1 && round.dealerSeat < players.length) {
          final dealerPlayer = players[round.dealerSeat];
          final dealerWon = round.winnerId == dealerPlayer.id ||
              round.winnerIds.contains(dealerPlayer.id);
          if (dealerWon) return SoundEffects.dealerCons;
        }

        // 規則3：一炮多響
        if (round.type == RoundType.multiWin) return SoundEffects.multiWin;

        // 規則4：自摸
        if (round.type == RoundType.selfDraw) return SoundEffects.selfDraw;

        // 規則5：胡牌（放槍）
        if (round.type == RoundType.win) return SoundEffects.win;

        return null;

      case RoundType.falseWin:
        return null; // 詐胡不播音效
    }
  }

  /// 播放音效（需傳入 enabled 和 volume）
  static Future<void> playForRound({
    required Round round,
    required GameSettings settings,
    required List<Player> players,
    required bool enabled,
    required double volume,
  }) async {
    if (!enabled) return;
    final path = selectEffect(round: round, settings: settings, players: players);
    if (path == null) return;
    await play(path, volume);
  }

  /// 試聽指定音效
  static Future<void> preview(String assetPath, double volume) async {
    await play(assetPath, volume);
  }

  /// 底層播放（每次建新實例，避免 Web 靜態 AudioPlayer 重用問題）
  static Future<void> play(String assetPath, double volume) async {
    try {
      await _player?.stop();
      await _player?.dispose();
      _player = AudioPlayer();
      await _player!.setVolume(volume);
      await _player!.play(AssetSource(assetPath));
    } catch (e) {
      // Web 瀏覽器首次需要使用者互動才允許播放，靜默忽略
    }
  }

  static Future<void> stop() async {
    await _player?.stop();
  }
}
