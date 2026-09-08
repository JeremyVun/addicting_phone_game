/* Shared render primitives. Classic script. Concepts supply their own CSS. */
(function () {
  var S = window.SETTLE;
  function el(tag, cls, text) {
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text != null) n.textContent = text;
    return n;
  }
  function inShape(shape, r, c) {
    for (var i = 0; i < shape.length; i++) if (shape[i][0] === r && shape[i][1] === c) return true;
    return false;
  }
  /* board: array of 8 strings. opts:
     ghost {shape,colour,row,col}, completes [[r,c]], clearedRows, clearedCols */
  function grid(board, opts) {
    opts = opts || {};
    var g = el('div', 'grid');
    var comp = {};
    (opts.completes || []).forEach(function (p) { comp[p[0] + ',' + p[1]] = 1; });
    var gh = {};
    if (opts.ghost) opts.ghost.shape.forEach(function (o) {
      gh[(opts.ghost.row + o[0]) + ',' + (opts.ghost.col + o[1])] = 1;
    });
    for (var r = 0; r < 8; r++) for (var c = 0; c < 8; c++) {
      var ch = board[r][c];
      var cell = el('div', 'cell');
      cell.dataset.rc = r + ',' + c;
      if (ch !== '.') {
        cell.classList.add('filled', 'k' + ch);
        cell.style.setProperty('--k', S.palette.blocks[+ch]);
      }
      if (gh[r + ',' + c]) {
        cell.classList.add('ghost');
        cell.style.setProperty('--k', S.palette.blocks[opts.ghost.colour]);
      }
      if (comp[r + ',' + c]) cell.classList.add('completes');
      if (opts.lineRows && opts.lineRows.indexOf(r) >= 0) cell.classList.add('inline');
      if (opts.lineCols && opts.lineCols.indexOf(c) >= 0) cell.classList.add('inline');
      if (opts.clearedRows && opts.clearedRows.indexOf(r) >= 0) cell.classList.add('flash');
      if (opts.clearedCols && opts.clearedCols.indexOf(c) >= 0) cell.classList.add('flash');
      g.appendChild(cell);
    }
    return g;
  }
  /* a piece rendered as its own mini-grid of cells */
  function piece(shapeName, colourIdx, extraCls) {
    var shape = S.pieces[shapeName];
    var rows = 0, cols = 0;
    shape.forEach(function (o) { rows = Math.max(rows, o[0] + 1); cols = Math.max(cols, o[1] + 1); });
    var p = el('div', 'piece' + (extraCls ? ' ' + extraCls : ''));
    p.style.setProperty('--pr', rows);
    p.style.setProperty('--pc', cols);
    for (var r = 0; r < rows; r++) for (var c = 0; c < cols; c++) {
      var on = inShape(shape, r, c);
      var cell = el('div', 'pcell' + (on ? ' filled' : ''));
      if (on) cell.style.setProperty('--k', S.palette.blocks[colourIdx]);
      p.appendChild(cell);
    }
    return p;
  }
  function ring(pct, size, stroke, track, colour) {
    var ns = 'http://www.w3.org/2000/svg';
    var svg = document.createElementNS(ns, 'svg');
    svg.setAttribute('width', size); svg.setAttribute('height', size);
    svg.setAttribute('viewBox', '0 0 ' + size + ' ' + size);
    svg.setAttribute('class', 'ring');
    var r = (size - stroke) / 2, cx = size / 2;
    var circ = 2 * Math.PI * r;
    function c(col, dash) {
      var e = document.createElementNS(ns, 'circle');
      e.setAttribute('cx', cx); e.setAttribute('cy', cx); e.setAttribute('r', r);
      e.setAttribute('fill', 'none'); e.setAttribute('stroke', col);
      e.setAttribute('stroke-width', stroke); e.setAttribute('stroke-linecap', 'round');
      if (dash) { e.setAttribute('stroke-dasharray', circ); e.setAttribute('stroke-dashoffset', circ * (1 - pct)); }
      return e;
    }
    svg.appendChild(c(track));
    var arc = c(colour, true);
    arc.setAttribute('transform', 'rotate(-90 ' + cx + ' ' + cx + ')');
    svg.appendChild(arc);
    return svg;
  }
  function playIcon(size, colour) {
    var ns = 'http://www.w3.org/2000/svg';
    var svg = document.createElementNS(ns, 'svg');
    svg.setAttribute('width', size); svg.setAttribute('height', size);
    svg.setAttribute('viewBox', '0 0 24 24'); svg.setAttribute('class', 'ico');
    var p = document.createElementNS(ns, 'path');
    p.setAttribute('d', 'M8 5.5v13l11-6.5z'); p.setAttribute('fill', colour || 'currentColor');
    svg.appendChild(p);
    return svg;
  }
  function coinIcon(size, colour) {
    var ns = 'http://www.w3.org/2000/svg';
    var svg = document.createElementNS(ns, 'svg');
    svg.setAttribute('width', size); svg.setAttribute('height', size);
    svg.setAttribute('viewBox', '0 0 24 24'); svg.setAttribute('class', 'ico');
    var c1 = document.createElementNS(ns, 'circle');
    c1.setAttribute('cx', 12); c1.setAttribute('cy', 12); c1.setAttribute('r', 8);
    c1.setAttribute('fill', 'none'); c1.setAttribute('stroke', colour || 'currentColor');
    c1.setAttribute('stroke-width', 2);
    var c2 = document.createElementNS(ns, 'circle');
    c2.setAttribute('cx', 12); c2.setAttribute('cy', 12); c2.setAttribute('r', 3);
    c2.setAttribute('fill', colour || 'currentColor');
    svg.appendChild(c1); svg.appendChild(c2);
    return svg;
  }
  function gearIcon(size, colour) {
    var ns = 'http://www.w3.org/2000/svg';
    var svg = document.createElementNS(ns, 'svg');
    svg.setAttribute('width', size); svg.setAttribute('height', size);
    svg.setAttribute('viewBox', '0 0 24 24'); svg.setAttribute('class', 'ico');
    var g = document.createElementNS(ns, 'g');
    g.setAttribute('stroke', colour || 'currentColor'); g.setAttribute('stroke-width', 1.6);
    g.setAttribute('fill', 'none'); g.setAttribute('stroke-linecap', 'round');
    var c = document.createElementNS(ns, 'circle');
    c.setAttribute('cx', 12); c.setAttribute('cy', 12); c.setAttribute('r', 3.2);
    g.appendChild(c);
    for (var i = 0; i < 6; i++) {
      var a = i * Math.PI / 3, l = document.createElementNS(ns, 'line');
      l.setAttribute('x1', 12 + Math.cos(a) * 6); l.setAttribute('y1', 12 + Math.sin(a) * 6);
      l.setAttribute('x2', 12 + Math.cos(a) * 8.4); l.setAttribute('y2', 12 + Math.sin(a) * 8.4);
      g.appendChild(l);
    }
    svg.appendChild(g);
    return svg;
  }
  /* emptiest rows x cols window on the board; returns {r,c} top-left */
  function quiet(board, h, w, avoidRows, avoidCols, rowMin, rowMax) {
    var best = null, bestN = 999;
    rowMin = rowMin || 0; rowMax = (rowMax == null ? 8 : rowMax);
    for (var r = rowMin; r <= Math.min(rowMax, 8) - h; r++) for (var c = 0; c <= 8 - w; c++) {
      var n = 0;
      for (var i = 0; i < h; i++) for (var j = 0; j < w; j++) {
        if (board[r + i][c + j] !== '.') n++;
        if (avoidRows && avoidRows.indexOf(r + i) >= 0) n += 2;
        if (avoidCols && avoidCols.indexOf(c + j) >= 0) n += 2;
      }
      if (n < bestN) { bestN = n; best = { r: r, c: c, n: n }; }
    }
    return best;
  }
  window.R = { quiet: quiet, el: el, grid: grid, piece: piece, ring: ring, playIcon: playIcon, coinIcon: coinIcon, gearIcon: gearIcon };
})();
