import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart' as csv_lib;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/game.dart';
import '../models/round.dart';
import 'calculation_service.dart';

/// 匯出報表服務
class ExportService {
  /// 匯出單場牌局為 JSON
  static String exportGameToJson(Game game) {
    return const JsonEncoder.withIndent('  ').convert(game.toJson());
  }

  /// 匯出所有牌局為 JSON
  static String exportAllGamesToJson(List<Game> games) {
    final data = games.map((g) => g.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// 匯出單場牌局為 CSV
  static String exportGameToCsv(Game game) {
    final rows = <List<dynamic>>[];

    // 表頭
    rows.add([
      '局號',
      '風位',
      '類型',
      ...game.players.map((p) => '${p.emoji} ${p.name}'),
    ]);

    // 每局資料
    for (int i = 0; i < game.rounds.length; i++) {
      final round = game.rounds[i];
      rows.add([
        i + 1,
        round.windDisplay,
        _roundTypeText(round.type),
        ...game.players.map((p) {
          final change = round.scoreChanges[p.id] ?? 0;
          return change;
        }),
      ]);
    }

    // 總計
    final scores = game.currentScores;
    rows.add([
      '',
      '',
      '總計',
      ...game.players.map((p) => scores[p.id] ?? 0),
    ]);

    return const csv_lib.CsvEncoder().convert(rows);
  }

  /// 匯出單場牌局為 PDF
  static Future<Uint8List> exportGameToPdf(Game game) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final scores = game.currentScores;

    // 排名
    final sortedPlayers = List.from(game.players);
    sortedPlayers.sort((a, b) {
      final scoreA = scores[a.id] ?? 0;
      final scoreB = scores[b.id] ?? 0;
      return scoreB.compareTo(scoreA);
    });

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          // 標題
          pw.Header(
            level: 0,
            child: pw.Text(
              'Paika - ${game.name ?? dateFormat.format(game.createdAt)}',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),

          // 牌局資訊
          pw.Paragraph(text: 'Date: ${dateFormat.format(game.createdAt)}'),
          pw.Paragraph(text: 'Base: ${game.settings.baseScore} / Per Tai: ${game.settings.perTai}'),
          pw.Paragraph(text: 'Rounds: ${game.rounds.length}'),
          pw.SizedBox(height: 16),

          // 排名表
          pw.Header(level: 1, text: 'Final Ranking'),
          pw.Table.fromTextArray(
            headers: ['Rank', 'Player', 'Score'],
            data: sortedPlayers.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final player = entry.value;
              final score = scores[player.id] ?? 0;
              return [
                '#$rank',
                '${player.emoji} ${player.name}',
                CalculationService.formatScore(score),
              ];
            }).toList(),
          ),

          pw.SizedBox(height: 24),

          // 局數明細
          pw.Header(level: 1, text: 'Round Details'),
          pw.Table.fromTextArray(
            headers: [
              '#',
              'Wind',
              'Type',
              ...game.players.map((p) => p.name),
            ],
            data: game.rounds.asMap().entries.map((entry) {
              final i = entry.key;
              final round = entry.value;
              return [
                '${i + 1}',
                round.windDisplay,
                _roundTypeText(round.type),
                ...game.players.map((p) {
                  final change = round.scoreChanges[p.id] ?? 0;
                  return change == 0 ? '-' : CalculationService.formatScore(change);
                }),
              ];
            }).toList(),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// 分享文字內容
  static Future<void> shareText(String content, String filename) async {
    await Share.share(content, subject: filename);
  }

  /// 分享檔案
  static Future<void> shareFile(Uint8List bytes, String filename, String mimeType) async {
    await Share.shareXFiles(
      [XFile.fromData(bytes, mimeType: mimeType, name: filename)],
    );
  }

  static String _roundTypeText(RoundType type) {
    switch (type) {
      case RoundType.win:
        return 'Win';
      case RoundType.selfDraw:
        return 'Self-Draw';
      case RoundType.falseWin:
        return 'False Win';
      case RoundType.multiWin:
        return 'Multi-Win';
      case RoundType.draw:
        return 'Draw';
    }
  }
}
