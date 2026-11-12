// Génère l'icône erase4me (PNG sans canal alpha, comme l'exige iOS) : node branding/make_icon.js
// Rasteriseur à bords lissés (distances signées) + encodeur PNG (zlib). Aucune dépendance.
const fs = require("fs"), zlib = require("zlib"), path = require("path");

const hex = h => [(h >> 16) & 255, (h >> 8) & 255, h & 255];
const INK = hex(0x0e0e0f), SHADOW = hex(0x050505), PAPER = hex(0xece9e2), GREY = hex(0xc9c5ba), BAR = hex(0x121213), ACCENT = hex(0xff6a3d);

// coordonnées sur une grille de 1024
const shapes = [
  { t: "rr", x: 206, y: 156, w: 612, h: 748, r: 26, c: SHADOW },       // ombre dure
  { t: "rr", x: 206, y: 138, w: 612, h: 748, r: 26, c: PAPER },        // feuille
  { t: "rr", x: 268, y: 214, w: 232, h: 16, r: 2, c: GREY },
  { t: "rr", x: 268, y: 268, w: 488, h: 12, r: 2, c: GREY },
  { t: "rr", x: 268, y: 304, w: 424, h: 12, r: 2, c: GREY },
  { t: "rr", x: 268, y: 392, w: 400, h: 46, r: 3, c: BAR },            // caviardages
  { t: "rr", x: 268, y: 466, w: 300, h: 46, r: 3, c: BAR },
  { t: "rr", x: 268, y: 540, w: 456, h: 46, r: 3, c: BAR },
  { t: "rr", x: 268, y: 630, w: 470, h: 12, r: 2, c: GREY },
  { t: "rr", x: 268, y: 666, w: 360, h: 12, r: 2, c: GREY },
  { t: "ring", cx: 668, cy: 742, r: 122, w: 30, c: ACCENT },            // sens interdit
  { t: "seg", x1: 582, y1: 656, x2: 754, y2: 828, w: 30, c: ACCENT },
];

function sdf(s, px, py) {
  if (s.t === "rr") {
    const cx = s.x + s.w / 2, cy = s.y + s.h / 2, hx = s.w / 2 - s.r, hy = s.h / 2 - s.r;
    const dx = Math.abs(px - cx) - hx, dy = Math.abs(py - cy) - hy;
    return Math.hypot(Math.max(dx, 0), Math.max(dy, 0)) + Math.min(Math.max(dx, dy), 0) - s.r;
  }
  if (s.t === "ring") return Math.abs(Math.hypot(px - s.cx, py - s.cy) - s.r) - s.w / 2;
  const vx = s.x2 - s.x1, vy = s.y2 - s.y1, wx = px - s.x1, wy = py - s.y1;
  const h = Math.max(0, Math.min(1, (wx * vx + wy * vy) / (vx * vx + vy * vy)));
  return Math.hypot(wx - vx * h, wy - vy * h) - s.w / 2;
}

function render(size) {
  const k = 1024 / size, buf = Buffer.alloc(size * (size * 3 + 1));
  for (let y = 0; y < size; y++) {
    const row = y * (size * 3 + 1); buf[row] = 0;
    for (let x = 0; x < size; x++) {
      const px = (x + 0.5) * k, py = (y + 0.5) * k;
      let col = INK;
      for (const s of shapes) {
        const cov = Math.max(0, Math.min(1, 0.5 - sdf(s, px, py) / k));
        if (cov > 0) col = col.map((v, i) => v * (1 - cov) + s.c[i] * cov);
      }
      const o = row + 1 + x * 3; buf[o] = Math.round(col[0]); buf[o + 1] = Math.round(col[1]); buf[o + 2] = Math.round(col[2]);
    }
  }
  return buf;
}

function crc32(b) {
  let c, crc = 0xffffffff;
  for (let n = 0; n < b.length; n++) { c = (crc ^ b[n]) & 255; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; crc = (crc >>> 8) ^ c; }
  return (crc ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type), data]); const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}
function png(size) {
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(size, 0); ihdr.writeUInt32BE(size, 4); ihdr[8] = 8; ihdr[9] = 2;   // 8 bits, RVB
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk("IHDR", ihdr), chunk("IDAT", zlib.deflateSync(render(size), { level: 9 })), chunk("IEND", Buffer.alloc(0))]);
}

const root = path.join(__dirname, "..");
const targets = [["App/Assets.xcassets/AppIcon.appiconset/icon-1024.png", 1024], ["branding/icon-512.png", 512], ["branding/icon-180.png", 180]];
for (const [rel, size] of targets) {
  const f = path.join(root, rel); fs.mkdirSync(path.dirname(f), { recursive: true });
  fs.writeFileSync(f, png(size)); console.log(rel, size + "px", fs.statSync(f).size + " octets");
}
