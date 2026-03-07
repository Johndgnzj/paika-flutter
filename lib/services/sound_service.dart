// dart.library.js_interop = true on web (both WASM & JS build), false on native
import 'sound_player_stub.dart'
    if (dart.library.js_interop) 'sound_player_web.dart';

import '../models/player.dart';
import '../models/round.dart';
import '../models/settings.dart';
import 'calculation_service.dart';

/// 音效檔案路徑（Flutter Web URL = /assets/<key>，key 包含 assets/ 前綴）
class SoundEffects {
  static const String highTai    = 'assets/audios/result/effect-01.mp3'; // 6台以上
  static const String dealerCons = 'assets/audios/result/effect-02.mp3'; // 莊家連莊
  static const String multiWin   = 'assets/audios/result/effect-03.mp3'; // 一炮多響
  static const String selfDraw   = 'assets/audios/result/effect-04.mp3'; // 自摸
  static const String win        = 'assets/audios/result/effect-05.mp3'; // 胡牌
  static const String draw       = 'assets/audios/result/effect-06.mp3'; // 流局
}

/// 音效服務：依局結果選擇並播放對應音效
class SoundService {
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

        // 規則2：莊家連一以上且莊家是本局贏家
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
        return null;
    }
  }

  /// 播放對應局結果的音效
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
    await SoundPlayer.play(path, volume);
  }

  /// 試聽指定音效
  static Future<void> preview(String assetPath, double volume) async {
    await SoundPlayer.play(assetPath, volume);
  }

  static void stop() => SoundPlayer.stop();
}
