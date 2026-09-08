/* Settle comps — shared fixture data. Classic script, no modules (file://).
   REAL: all numbers, labels and rules come from docs/backlog/v1/design.md
   (score 4,820 / best 12,460 / coins 1,240 / level 7 / streak 12 / +180 /
   Combo x4 / piece catalogue 2.2 / family->colour map 2.2).
   SYNTHETIC DELTAS (declared): (1) the four board fills are hand-authored,
   not director output — the director does not exist yet; (2) "coins earned
   +96" on the game-over sheet is score 4820/50 = 96 by the 7.1 formula
   applied by hand; (3) level 7 ring at 60% and XP 4,190/6,300 are picked to
   sit inside the 7.2 curve, not read from a save. */
window.SETTLE = (function () {
  var palette = {
    ground: '#0D1016', well: '#090C12', slab: '#161B26',
    empty: '#1C2230', lattice: '#262E3D', hair: '#232A38',
    ink: '#F4F6FA', mute: '#9AA4B8', faint: '#6E7889',
    accent: '#F0A03A',
    blocks: ['#E8543F','#F0A03A','#A9C94E','#3EB98C','#3AA6DE','#7C7CEA','#C167D6','#EE7CA8']
  };
  /* contrast vs ground #0D1016 / vs empty #1C2230 — see measure.js output */
  var contrast = {
    ground: [5.23,8.88,10.11,7.73,6.97,5.38,5.60,7.33],
    empty:  [4.27,7.25,8.26,6.31,5.69,4.39,4.58,5.99],
    worstPairDE2000: 16.5
  };
  var num = {
    score: '4,820', best: '12,460', coins: '1,240', level: '7',
    streak: '12', combo: 'Combo x4', pop: '+180',
    coinsEarned: '+96', xp: '4,190 / 6,300', ring: 0.60, ringNew: 0.03,
    newCoins: '0', newLevel: '1', newStreak: '0', zero: '0', wide: '1,284,600'
  };
  /* boards: 8 strings of 8 chars, '.' empty, 0-7 = block colour index */
  var boards = {
    empty: ['........','........','........','........','........','........','........','........'],
    mid:   ['..3..1..','.53..17.','.53.417.','..2.4...','6.22447.','6644..70','.6...0..','55.0.0..'],
    clear: ['....71..','.53..1..','.53.415.','12345670','6.2244..','66..1370','...5.0..','55...4..'],
    danger:['4433.1.7','445.311.','4453..11','2.53.766','66.3446.','6644337.','.6510055','55.00055']
  };
  /* p2: dragged i2 (colour 1) ghosting into row 5, cols 4-5 (completing row 5) */
  var drag = { piece: [[0,0],[0,1]], colour: 1, row: 5, col: 4, completes: [[5,4],[5,5]], lineRows: [5] };
  /* p3: row 4 and column 2 flashed out this frame */
  var cleared = { rows: [3], cols: [5], popAt: [3,5] };
  var pieces = {
    l4:  [[0,0],[1,0],[2,0],[2,1]],
    i3:  [[0,0],[0,1],[0,2]],
    o2:  [[0,0],[0,1],[1,0],[1,1]],
    t4:  [[0,0],[0,1],[0,2],[1,1]],
    o3:  [[0,0],[0,1],[0,2],[1,0],[1,1],[1,2],[2,0],[2,1],[2,2]],
    i2:  [[0,0],[0,1]],
    l3:  [[0,0],[1,0],[1,1]],
    i5:  [[0,0],[0,1],[0,2],[0,3],[0,4]]
  };
  var trays = {
    mid:    [{s:'l4',c:5},{s:'i2',c:1,dragging:true},{s:'t4',c:7}],
    first:  [{s:'o2',c:3},{s:'l3',c:5},{s:'i3',c:1}],
    clear:  [{s:'t4',c:7},{s:'l3',c:5},null],
    danger: [null,{s:'o3',c:4,nofit:true},null]
  };
  var copy = {
    play:'Play', daily:'Daily', shop:'Shop', themes:'Themes', settings:'Settings',
    score:'Score', best:'Best', combo:'Combo x4', pop:'+180',
    cont:'Continue', again:'Play again', home:'Home', newBest:'New best',
    dayStreak:'Day streak', coins:'Coins', level:'Level',
    hint1:'Drag a block onto the grid', hint2:'Fill a row or column to clear it'
  };
  function scenario() {
    var m = /scenario=([a-z0-9]+)/.exec(location.search);
    return m ? m[1] : 'p2';
  }
  return { palette:palette, contrast:contrast, num:num, boards:boards, drag:drag,
           cleared:cleared, pieces:pieces, trays:trays, copy:copy, scenario:scenario };
})();
