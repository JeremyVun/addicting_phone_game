import 'dart:io';

import 'package:settle/core/sim/bots.dart';

const double assistFillMin = 0.30;
const double assistFillMax = 0.70;
const double bucketAPressure = 0.30;
const double bucketBPressure = 0.80;
const double assistRateMin = 0.35;
const double assistRateGap = 0.10;
const Map<String, List<int>> medianPlacementBands = {
  'random': [20, 45],
  'greedy': [90, 220],
};

void main(List<String> args) {
  final opts = _parse(args);
  final botName = opts['bot'] ?? 'greedy';
  final bot = botName == 'random' ? const RandomBot() : const GreedyBot();
  if (botName != 'random' && botName != 'greedy') {
    stderr.writeln('unknown bot: $botName');
    exit(2);
  }
  final games = int.parse(opts['games'] ?? '2000');
  final skill = double.parse(opts['skill'] ?? '0.5');
  final seed = int.parse(opts['seed'] ?? '1');
  final restricted = opts.containsKey('restricted');

  final watch = Stopwatch()..start();
  final scores = <int>[];
  final placements = <int>[];
  var setsTotal = 0;
  var aTotal = 0, aAssisted = 0, bTotal = 0, bAssisted = 0;

  for (var i = 0; i < games; i++) {
    final record = playGame(bot, seed + i, skill, restricted: restricted);
    scores.add(record.score);
    placements.add(record.placements);
    setsTotal += record.setsGenerated;
    for (final set in record.sets) {
      if (set.fill < assistFillMin || set.fill >= assistFillMax) continue;
      if (set.pressure <= bucketAPressure) {
        aTotal++;
        if (set.assisted) aAssisted++;
      } else if (set.pressure >= bucketBPressure) {
        bTotal++;
        if (set.assisted) bAssisted++;
      }
    }
  }
  watch.stop();

  scores.sort();
  placements.sort();
  final rateA = aTotal == 0 ? 0.0 : aAssisted / aTotal;
  final rateB = bTotal == 0 ? 0.0 : bAssisted / bTotal;
  final medianPlacements = _pct(placements, 0.50);
  final band = medianPlacementBands[botName]!;

  stdout.writeln('bot                $botName');
  stdout.writeln('games              $games');
  stdout.writeln('skill              $skill');
  stdout.writeln('seed               $seed');
  stdout.writeln('restricted         $restricted');
  stdout.writeln('placements p10/median/p90  '
      '${_pct(placements, 0.10)} / $medianPlacements / ${_pct(placements, 0.90)}');
  stdout.writeln('score      p10/median/p90  '
      '${_pct(scores, 0.10)} / ${_pct(scores, 0.50)} / ${_pct(scores, 0.90)}');
  stdout.writeln('mean sets generated        '
      '${(setsTotal / games).toStringAsFixed(2)}');
  stdout.writeln('assist rate(A) p<=$bucketAPressure   '
      '${rateA.toStringAsFixed(4)}  (n=$aTotal)');
  stdout.writeln('assist rate(B) p>=$bucketBPressure   '
      '${rateB.toStringAsFixed(4)}  (n=$bTotal)');
  stdout.writeln('elapsed            ${watch.elapsed.inMilliseconds} ms');

  final lengthOk = medianPlacements >= band[0] && medianPlacements <= band[1];
  // Design 5.6 measures the assist gate on the greedy bot; random games never
  // reach the pressures of bucket B.
  final assistGated = botName == 'greedy';
  final assistOk = rateA >= assistRateMin && rateA >= rateB + assistRateGap;
  final gates = <String>[
    'median placements $medianPlacements in ${band[0]}-${band[1]}: '
        '${lengthOk ? 'PASS' : 'FAIL'}',
    'rate(A) ${rateA.toStringAsFixed(4)} >= $assistRateMin and >= rate(B)+'
        '$assistRateGap (${(rateB + assistRateGap).toStringAsFixed(4)}): '
        '${!assistGated ? 'n/a' : assistOk ? 'PASS' : 'FAIL'}',
  ];
  final pass = lengthOk && (!assistGated || assistOk);
  stdout.writeln('${pass ? 'PASS' : 'FAIL'}  ${gates.join('  |  ')}');
}

int _pct(List<int> sorted, double q) {
  if (sorted.isEmpty) return 0;
  final i = ((sorted.length - 1) * q).round();
  return sorted[i];
}

Map<String, String> _parse(List<String> args) {
  final out = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) continue;
    final key = arg.substring(2);
    if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
      out[key] = args[++i];
    } else {
      out[key] = 'true';
    }
  }
  return out;
}
