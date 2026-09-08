import 'dart:io';

import 'package:settle/core/director.dart';
import 'package:settle/core/piece.dart';
import 'package:settle/core/sim/bots.dart';
import 'package:settle/core/sim/smart_bot.dart';

const double assistFillMin = 0.30;
const double assistFillMax = 0.70;
const double bucketAPressure = 0.30;
const double bucketBPressure = 0.80;
const double assistRateMin = 0.35;
const double assistRateGap = 0.10;
const Map<String, List<int>> medianPlacementBands = {
  'random': [20, 45],
  'greedy': [90, 220],
  'smart': [90, 220],
};
const List<double> sweepOffsets = [1.0, 1.4, 1.8, 2.2, 2.6];
const List<List<int>> sizeClasses = [
  [1, 1],
  [2, 3],
  [4, 4],
  [5, 6],
  [9, 9],
];

Bot makeBot(String name) => switch (name) {
      'random' => const RandomBot(),
      'greedy' => const GreedyBot(),
      _ => SmartBot(),
    };

class Run {
  Run(this.placements, this.scores, this.rateA, this.nA, this.rateB, this.nB,
      this.censored, this.meanSets, this.elapsedMs);

  final List<int> placements;
  final List<int> scores;
  final double rateA;
  final int nA;
  final double rateB;
  final int nB;
  final int censored;
  final double meanSets;
  final int elapsedMs;

  int get medianPlacements => percentile(placements, 0.50);

  int get medianScore => percentile(scores, 0.50);
}

Run runBot(String botName, int games, double skill, int seed,
    {bool restricted = false, int maxPlacements = 1 << 30}) {
  final watch = Stopwatch()..start();
  final scores = <int>[];
  final placements = <int>[];
  var setsTotal = 0;
  var censored = 0;
  var aTotal = 0, aAssisted = 0, bTotal = 0, bAssisted = 0;
  for (var i = 0; i < games; i++) {
    final record = playGame(makeBot(botName), seed + i, skill,
        restricted: restricted, maxPlacements: maxPlacements);
    scores.add(record.score);
    placements.add(record.placements);
    setsTotal += record.setsGenerated;
    if (record.censored) censored++;
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
  return Run(
    placements,
    scores,
    aTotal == 0 ? 0.0 : aAssisted / aTotal,
    aTotal,
    bTotal == 0 ? 0.0 : bAssisted / bTotal,
    bTotal,
    censored,
    setsTotal / games,
    watch.elapsed.inMilliseconds,
  );
}

void main(List<String> args) {
  final opts = parseArgs(args);
  if (opts.containsKey('sweep')) {
    sweep(opts);
    return;
  }
  final botName = opts['bot'] ?? 'greedy';
  if (!medianPlacementBands.containsKey(botName)) {
    stderr.writeln('unknown bot: $botName');
    exit(2);
  }
  final games = int.parse(opts['games'] ?? '2000');
  final skill = double.parse(opts['skill'] ?? '0.5');
  final seed = int.parse(opts['seed'] ?? '1');
  final restricted = opts.containsKey('restricted');
  final maxPlacements = int.parse(opts['max-placements'] ?? '1073741824');
  if (opts.containsKey('offset')) {
    Director.sizeBiasOffset = double.parse(opts['offset']!);
  }

  final run = runBot(botName, games, skill, seed,
      restricted: restricted, maxPlacements: maxPlacements);
  final band = medianPlacementBands[botName]!;

  stdout.writeln('bot                $botName');
  stdout.writeln('games              $games');
  stdout.writeln('skill              $skill');
  stdout.writeln('seed               $seed');
  stdout.writeln('restricted         $restricted');
  stdout.writeln('sizeBiasOffset     ${Director.sizeBiasOffset}');
  stdout.writeln('placements p10/median/p90  '
      '${percentile(run.placements, 0.10)} / ${run.medianPlacements}'
      ' / ${percentile(run.placements, 0.90)}');
  stdout.writeln('score      p10/median/p90  '
      '${percentile(run.scores, 0.10)} / ${run.medianScore}'
      ' / ${percentile(run.scores, 0.90)}');
  stdout.writeln('mean sets generated        ${run.meanSets.toStringAsFixed(2)}');
  stdout.writeln('games hitting the cap      ${run.censored}');
  stdout.writeln('assist rate(A) p<=$bucketAPressure   '
      '${run.rateA.toStringAsFixed(4)}  (n=${run.nA})');
  stdout.writeln('assist rate(B) p>=$bucketBPressure   '
      '${run.rateB.toStringAsFixed(4)}  (n=${run.nB})');
  stdout.writeln('elapsed            ${run.elapsedMs} ms');

  final lengthOk =
      run.medianPlacements >= band[0] && run.medianPlacements <= band[1];
  // Design 5.6 measures the assist gate on the greedy bot; random games never
  // reach the pressures of bucket B.
  final assistGated = botName == 'greedy';
  final assistOk =
      run.rateA >= assistRateMin && run.rateA >= run.rateB + assistRateGap;
  final gates = <String>[
    'median placements ${run.medianPlacements} in ${band[0]}-${band[1]}: '
        '${lengthOk ? 'PASS' : 'FAIL'}',
    'rate(A) ${run.rateA.toStringAsFixed(4)} >= $assistRateMin and >= rate(B)+'
        '$assistRateGap (${(run.rateB + assistRateGap).toStringAsFixed(4)}): '
        '${!assistGated ? 'n/a' : assistOk ? 'PASS' : 'FAIL'}',
  ];
  final pass = lengthOk && (!assistGated || assistOk);
  stdout.writeln('${pass ? 'PASS' : 'FAIL'}  ${gates.join('  |  ')}');
}

void sweep(Map<String, String> opts) {
  final games = int.parse(opts['games'] ?? '2000');
  final smartGames = int.parse(opts['smart-games'] ?? '300');
  final skill = double.parse(opts['skill'] ?? '0.5');
  final seed = int.parse(opts['seed'] ?? '1');
  final cap = int.parse(opts['max-placements'] ?? '400');
  final offsets = opts.containsKey('offsets')
      ? [for (final o in opts['offsets']!.split(',')) double.parse(o)]
      : sweepOffsets;

  stdout.writeln('sweep: games=$games smartGames=$smartGames skill=$skill '
      'seed=$seed cap=$cap');
  stdout.writeln('offset | med placements rnd/grd/smt | med score rnd/grd/smt '
      '| rate(A) | rate(B) | smart capped | smart ms');
  final rows = <String>[];
  final bags = <String>[];
  for (final offset in offsets) {
    Director.sizeBiasOffset = offset;
    final random = runBot('random', games, skill, seed);
    final greedy = runBot('greedy', games, skill, seed);
    final smart =
        runBot('smart', smartGames, skill, seed, maxPlacements: cap);
    rows.add('${offset.toStringAsFixed(1).padLeft(6)} | '
        '${random.medianPlacements.toString().padLeft(5)}'
        '/${greedy.medianPlacements.toString().padLeft(4)}'
        '/${smart.medianPlacements.toString().padLeft(4)} | '
        '${random.medianScore.toString().padLeft(6)}'
        '/${greedy.medianScore.toString().padLeft(6)}'
        '/${smart.medianScore.toString().padLeft(7)} | '
        '${greedy.rateA.toStringAsFixed(3)} (n=${greedy.nA}) | '
        '${greedy.rateB.toStringAsFixed(3)} (n=${greedy.nB}) | '
        '${smart.censored}/$smartGames | ${smart.elapsedMs}');
    bags.add('${offset.toStringAsFixed(1).padLeft(6)} | '
        '${bagShares(0.5).map((v) => (v * 100).toStringAsFixed(1).padLeft(5)).join(' ')}');
    stdout.writeln(rows.last);
  }
  Director.sizeBiasOffset = Director.sizeBiasOffsetDefault;
  stdout.writeln('');
  stdout.writeln('bag composition at p=0.5, share of draws by piece size (%)');
  stdout.writeln('offset |     1   2-3     4   5-6     9');
  for (final line in bags) {
    stdout.writeln(line);
  }
}

List<double> bagShares(double p) {
  final weights = Director.weights(Piece.all, p);
  var total = 0.0;
  for (final w in weights) {
    total += w;
  }
  return [
    for (final range in sizeClasses)
      () {
        var sum = 0.0;
        for (var i = 0; i < Piece.all.length; i++) {
          final size = Piece.all[i].size;
          if (size >= range[0] && size <= range[1]) sum += weights[i];
        }
        return sum / total;
      }(),
  ];
}

int percentile(List<int> sorted, double q) {
  if (sorted.isEmpty) return 0;
  final i = ((sorted.length - 1) * q).round();
  return sorted[i];
}

Map<String, String> parseArgs(List<String> args) {
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
