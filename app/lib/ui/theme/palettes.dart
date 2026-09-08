import 'dart:ui';

/// A theme's full colour set. Slot order is design 7.3; `blocks` is indexed by
/// `Piece.colourIndex`, so a theme change never affects the game sequence.
class ThemePalette {
  const ThemePalette({
    required this.id,
    required this.name,
    required this.ground,
    required this.well,
    required this.empty,
    required this.hairline,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.onAccent,
    required this.blocks,
    this.lightGround = false,
  });

  final String id;
  final String name;
  final Color ground;
  final Color well;
  final Color empty;
  final Color hairline;
  final Color ink;
  final Color muted;
  final Color faint;
  final Color accent;
  final Color onAccent;
  final List<Color> blocks;

  /// Bevel highlight and shade are inverted on a light ground so a tile still
  /// reads as lit from above.
  final bool lightGround;

  Color block(int colourIndex) => blocks[colourIndex];

  static const obsidian = ThemePalette(
    id: 'obsidian',
    name: 'Obsidian',
    ground: Color(0xFF0D1016),
    well: Color(0xFF090C12),
    empty: Color(0xFF1C2230),
    hairline: Color(0xFF1E2430),
    ink: Color(0xFFF2F4F8),
    muted: Color(0xFF8A93A6),
    faint: Color(0xFF5B6478),
    accent: Color(0xFFF0A03A),
    onAccent: Color(0xFF14100A),
    blocks: [
      Color(0xFFE8543F),
      Color(0xFFF0A03A),
      Color(0xFFA9C94E),
      Color(0xFF3EB98C),
      Color(0xFF3AA6DE),
      Color(0xFF7C7CEA),
      Color(0xFFC167D6),
      Color(0xFFEE7CA8),
    ],
  );

  static const dawn = ThemePalette(
    id: 'dawn',
    name: 'Dawn',
    ground: Color(0xFF141020),
    well: Color(0xFF0F0C19),
    empty: Color(0xFF262038),
    hairline: Color(0xFF2C2542),
    ink: Color(0xFFF6F1F6),
    muted: Color(0xFF9C93AE),
    faint: Color(0xFF6C6383),
    accent: Color(0xFFFFB07C),
    onAccent: Color(0xFF1A0E08),
    blocks: [
      Color(0xFFF4695E),
      Color(0xFFFFB07C),
      Color(0xFFF7D774),
      Color(0xFF7FD6B0),
      Color(0xFF6FB8F0),
      Color(0xFF9A8CF2),
      Color(0xFFD07FE0),
      Color(0xFFFF93B4),
    ],
  );

  static const meadow = ThemePalette(
    id: 'meadow',
    name: 'Meadow',
    ground: Color(0xFF0B1410),
    well: Color(0xFF07100C),
    empty: Color(0xFF17281F),
    hairline: Color(0xFF1D3126),
    ink: Color(0xFFF0F6F1),
    muted: Color(0xFF87A392),
    faint: Color(0xFF5A7566),
    accent: Color(0xFFE9C64C),
    onAccent: Color(0xFF12140A),
    blocks: [
      Color(0xFFE86A4B),
      Color(0xFFE9C64C),
      Color(0xFFB6D95A),
      Color(0xFF52C877),
      Color(0xFF46B6C4),
      Color(0xFF7E9DF0),
      Color(0xFFBE7BE0),
      Color(0xFFEF8BA0),
    ],
  );

  static const coral = ThemePalette(
    id: 'coral',
    name: 'Coral',
    ground: Color(0xFF17100F),
    well: Color(0xFF120B0A),
    empty: Color(0xFF2B1E1D),
    hairline: Color(0xFF352524),
    ink: Color(0xFFFAF0EC),
    muted: Color(0xFFAE9490),
    faint: Color(0xFF7A6360),
    accent: Color(0xFFFF7F5C),
    onAccent: Color(0xFF1C0B06),
    blocks: [
      Color(0xFFFF7F5C),
      Color(0xFFFFBE5C),
      Color(0xFFD9DC66),
      Color(0xFF63D6A6),
      Color(0xFF5DBBEA),
      Color(0xFF9C90F5),
      Color(0xFFDD79D2),
      Color(0xFFFF89A6),
    ],
  );

  static const glacier = ThemePalette(
    id: 'glacier',
    name: 'Glacier',
    ground: Color(0xFF0B1118),
    well: Color(0xFF070C13),
    empty: Color(0xFF19242F),
    hairline: Color(0xFF1F2C39),
    ink: Color(0xFFEEF6FA),
    muted: Color(0xFF8DA0AF),
    faint: Color(0xFF5F7181),
    accent: Color(0xFF5FD3E8),
    onAccent: Color(0xFF06171B),
    blocks: [
      Color(0xFFF06A70),
      Color(0xFFF3B15E),
      Color(0xFFCBE07A),
      Color(0xFF54D7B4),
      Color(0xFF5FD3E8),
      Color(0xFF7FA8F5),
      Color(0xFFB88BEE),
      Color(0xFFE894C6),
    ],
  );

  static const desert = ThemePalette(
    id: 'desert',
    name: 'Desert',
    ground: Color(0xFF161109),
    well: Color(0xFF110C06),
    empty: Color(0xFF2A2114),
    hairline: Color(0xFF34291A),
    ink: Color(0xFFF8F1E2),
    muted: Color(0xFFAD9C7F),
    faint: Color(0xFF7A6C55),
    accent: Color(0xFFEEA23C),
    onAccent: Color(0xFF1A1105),
    blocks: [
      Color(0xFFE05F3C),
      Color(0xFFEEA23C),
      Color(0xFFD9C558),
      Color(0xFF77C169),
      Color(0xFF4FAEC9),
      Color(0xFF9187E4),
      Color(0xFFC96FB6),
      Color(0xFFEE8878),
    ],
  );

  static const storm = ThemePalette(
    id: 'storm',
    name: 'Storm',
    ground: Color(0xFF101318),
    well: Color(0xFF0B0E13),
    empty: Color(0xFF212832),
    hairline: Color(0xFF29313D),
    ink: Color(0xFFEFF2F6),
    muted: Color(0xFF8E97A4),
    faint: Color(0xFF616A78),
    accent: Color(0xFFFFD25C),
    onAccent: Color(0xFF17130A),
    blocks: [
      Color(0xFFE06666),
      Color(0xFFFFD25C),
      Color(0xFFAFC08A),
      Color(0xFF6EC2AE),
      Color(0xFF6FA6D8),
      Color(0xFF8E92DC),
      Color(0xFFB584CE),
      Color(0xFFDD8FA6),
    ],
  );

  static const lavender = ThemePalette(
    id: 'lavender',
    name: 'Lavender',
    ground: Color(0xFF13111C),
    well: Color(0xFF0E0C16),
    empty: Color(0xFF241F33),
    hairline: Color(0xFF2C263E),
    ink: Color(0xFFF3F0FA),
    muted: Color(0xFF9992B4),
    faint: Color(0xFF6A6389),
    accent: Color(0xFFC8A6FF),
    onAccent: Color(0xFF140B22),
    blocks: [
      Color(0xFFF2647A),
      Color(0xFFF5B57A),
      Color(0xFFDCDD82),
      Color(0xFF74D5BC),
      Color(0xFF74B6F2),
      Color(0xFF8A83F5),
      Color(0xFFC87BF5),
      Color(0xFFED7BC0),
    ],
  );

  static const ember = ThemePalette(
    id: 'ember',
    name: 'Ember',
    ground: Color(0xFF120C0C),
    well: Color(0xFF0C0707),
    empty: Color(0xFF241819),
    hairline: Color(0xFF2E2020),
    ink: Color(0xFFF9EEEA),
    muted: Color(0xFFAB918C),
    faint: Color(0xFF77605C),
    accent: Color(0xFFFF7A2F),
    onAccent: Color(0xFF1A0A02),
    blocks: [
      Color(0xFFF44B3A),
      Color(0xFFFF7A2F),
      Color(0xFFF3C242),
      Color(0xFF5FC98D),
      Color(0xFF4FA9E8),
      Color(0xFF8F86F0),
      Color(0xFFCE68C4),
      Color(0xFFFF8095),
    ],
  );

  static const plum = ThemePalette(
    id: 'plum',
    name: 'Plum',
    ground: Color(0xFF160F17),
    well: Color(0xFF110A12),
    empty: Color(0xFF291D2B),
    hairline: Color(0xFF332435),
    ink: Color(0xFFF8EFF7),
    muted: Color(0xFFAB92AC),
    faint: Color(0xFF786279),
    accent: Color(0xFFE267B0),
    onAccent: Color(0xFF1B0713),
    blocks: [
      Color(0xFFE85A4F),
      Color(0xFFEFA95F),
      Color(0xFFCBD269),
      Color(0xFF5FCCA0),
      Color(0xFF5EA8E2),
      Color(0xFF7E86F0),
      Color(0xFFC462E2),
      Color(0xFFED74A6),
    ],
  );

  static const pearl = ThemePalette(
    id: 'pearl',
    name: 'Pearl',
    lightGround: true,
    ground: Color(0xFFE6E1D7),
    well: Color(0xFFD5CFC3),
    empty: Color(0xFFC6BFB1),
    hairline: Color(0xFFB4AC9C),
    ink: Color(0xFF191A1E),
    muted: Color(0xFF5C5A54),
    faint: Color(0xFF7C7970),
    accent: Color(0xFF9A5A12),
    onAccent: Color(0xFFFDF6EA),
    blocks: [
      Color(0xFF97281B),
      Color(0xFF6E4A04),
      Color(0xFF3B5407),
      Color(0xFF0A5D45),
      Color(0xFF0D4F78),
      Color(0xFF3A3A9C),
      Color(0xFF6B2588),
      Color(0xFF941F54),
    ],
  );

  static const lagoon = ThemePalette(
    id: 'lagoon',
    name: 'Lagoon',
    ground: Color(0xFF08151A),
    well: Color(0xFF041015),
    empty: Color(0xFF11262E),
    hairline: Color(0xFF173039),
    ink: Color(0xFFEBF7F8),
    muted: Color(0xFF83A2A8),
    faint: Color(0xFF587279),
    accent: Color(0xFF35D6C0),
    onAccent: Color(0xFF03190F),
    blocks: [
      Color(0xFFF2665F),
      Color(0xFFF5B14A),
      Color(0xFFB9D95E),
      Color(0xFF35D6C0),
      Color(0xFF3EA8E6),
      Color(0xFF8391F2),
      Color(0xFFBE73DE),
      Color(0xFFF285AE),
    ],
  );

  /// Design 7.3 slot order.
  static const List<ThemePalette> all = [
    obsidian,
    dawn,
    meadow,
    coral,
    glacier,
    desert,
    storm,
    lavender,
    ember,
    plum,
    pearl,
    lagoon,
  ];

  static ThemePalette byId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => obsidian);
}
