/**
 * Gegenstände, prozedural gezeichnet - für die grosse Ansicht auf dem
 * Kontrolltisch. Jedes Icon wird in ein Quadrat der Kantenlänge `s` gezeichnet,
 * Ursprung oben links.
 */

import { PAL, withAlpha } from './palette.js';
import { roundRect } from './sprites.js';

const METAL = '#b7c0cd';
const METAL_DARK = '#7d8794';
const PLASTIC = '#2b323d';

export function drawItemIcon(ctx, id, s) {
  ctx.save();
  ctx.lineJoin = 'round';
  ctx.lineCap = 'round';
  (DRAW[id] ?? drawUnknown)(ctx, s);
  ctx.restore();
}

const DRAW = {
  /* ---------------- harmlos ---------------- */

  gum(ctx, s) {
    ctx.fillStyle = '#e7eef7';
    roundRect(ctx, s * 0.24, s * 0.2, s * 0.52, s * 0.6, s * 0.06); ctx.fill();
    ctx.fillStyle = '#5fc9d8';
    roundRect(ctx, s * 0.24, s * 0.34, s * 0.52, s * 0.2, 2); ctx.fill();
    ctx.strokeStyle = METAL_DARK; ctx.lineWidth = 1.5;
    roundRect(ctx, s * 0.24, s * 0.2, s * 0.52, s * 0.6, s * 0.06); ctx.stroke();
  },

  phone(ctx, s) {
    ctx.fillStyle = PLASTIC;
    roundRect(ctx, s * 0.28, s * 0.14, s * 0.44, s * 0.72, s * 0.07); ctx.fill();
    ctx.fillStyle = '#5d7f9c';
    roundRect(ctx, s * 0.33, s * 0.21, s * 0.34, s * 0.54, s * 0.03); ctx.fill();
    ctx.fillStyle = withAlpha('#ffffff', 0.18);
    roundRect(ctx, s * 0.35, s * 0.23, s * 0.12, s * 0.5, 2); ctx.fill();
  },

  keys(ctx, s) {
    ctx.strokeStyle = METAL; ctx.lineWidth = s * 0.05;
    ctx.beginPath(); ctx.arc(s * 0.36, s * 0.32, s * 0.14, 0, Math.PI * 2); ctx.stroke();
    for (const [dx, len] of [[0.1, 0.34], [-0.02, 0.28]]) {
      ctx.strokeStyle = METAL; ctx.lineWidth = s * 0.07;
      ctx.beginPath();
      ctx.moveTo(s * (0.46 + dx), s * 0.4);
      ctx.lineTo(s * (0.5 + dx), s * (0.4 + len));
      ctx.stroke();
      ctx.lineWidth = s * 0.03;
      ctx.beginPath();
      ctx.moveTo(s * (0.5 + dx), s * (0.34 + len));
      ctx.lineTo(s * (0.58 + dx), s * (0.34 + len));
      ctx.stroke();
    }
  },

  lighter(ctx, s) {
    ctx.fillStyle = '#c8402f';
    roundRect(ctx, s * 0.34, s * 0.3, s * 0.32, s * 0.52, s * 0.05); ctx.fill();
    ctx.fillStyle = METAL;
    roundRect(ctx, s * 0.36, s * 0.2, s * 0.28, s * 0.12, 2); ctx.fill();
    ctx.fillStyle = withAlpha(PAL.amber, 0.9);
    ctx.beginPath();
    ctx.ellipse(s * 0.5, s * 0.16, s * 0.05, s * 0.09, 0, 0, Math.PI * 2);
    ctx.fill();
  },

  smokes(ctx, s) {
    ctx.fillStyle = '#e9edf3';
    roundRect(ctx, s * 0.28, s * 0.24, s * 0.44, s * 0.56, s * 0.04); ctx.fill();
    ctx.fillStyle = '#c1262c';
    ctx.fillRect(s * 0.28, s * 0.24, s * 0.44, s * 0.14);
    ctx.strokeStyle = METAL_DARK; ctx.lineWidth = 1.4;
    roundRect(ctx, s * 0.28, s * 0.24, s * 0.44, s * 0.56, s * 0.04); ctx.stroke();
  },

  wallet(ctx, s) {
    ctx.fillStyle = '#6b4a33';
    roundRect(ctx, s * 0.2, s * 0.3, s * 0.6, s * 0.42, s * 0.05); ctx.fill();
    ctx.fillStyle = '#563a28';
    roundRect(ctx, s * 0.2, s * 0.44, s * 0.6, s * 0.28, s * 0.05); ctx.fill();
    ctx.fillStyle = METAL;
    roundRect(ctx, s * 0.44, s * 0.42, s * 0.12, s * 0.1, 2); ctx.fill();
  },

  earbuds(ctx, s) {
    ctx.fillStyle = '#eef2f7';
    ctx.beginPath(); ctx.arc(s * 0.35, s * 0.32, s * 0.1, 0, Math.PI * 2); ctx.fill();
    ctx.beginPath(); ctx.arc(s * 0.65, s * 0.32, s * 0.1, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = '#dfe5ee'; ctx.lineWidth = s * 0.035;
    ctx.beginPath();
    ctx.moveTo(s * 0.35, s * 0.42);
    ctx.quadraticCurveTo(s * 0.5, s * 0.82, s * 0.65, s * 0.42);
    ctx.stroke();
  },

  coins(ctx, s) {
    for (const [x, y, r] of [[0.38, 0.6, 0.15], [0.6, 0.52, 0.13], [0.5, 0.38, 0.12]]) {
      ctx.fillStyle = PAL.amber;
      ctx.beginPath(); ctx.arc(s * x, s * y, s * r, 0, Math.PI * 2); ctx.fill();
      ctx.strokeStyle = '#a97b1f'; ctx.lineWidth = 1.4; ctx.stroke();
    }
  },

  tissues(ctx, s) {
    ctx.fillStyle = '#dfe6f0';
    roundRect(ctx, s * 0.22, s * 0.34, s * 0.56, s * 0.38, s * 0.05); ctx.fill();
    ctx.fillStyle = '#fff';
    ctx.beginPath();
    ctx.moveTo(s * 0.44, s * 0.36); ctx.lineTo(s * 0.5, s * 0.18);
    ctx.lineTo(s * 0.58, s * 0.36); ctx.closePath(); ctx.fill();
    ctx.strokeStyle = '#9aa6b6'; ctx.lineWidth = 1.3;
    roundRect(ctx, s * 0.22, s * 0.34, s * 0.56, s * 0.38, s * 0.05); ctx.stroke();
  },

  balm(ctx, s) {
    ctx.fillStyle = '#d2568a';
    roundRect(ctx, s * 0.4, s * 0.28, s * 0.2, s * 0.5, s * 0.05); ctx.fill();
    ctx.fillStyle = '#f0f3f8';
    roundRect(ctx, s * 0.4, s * 0.2, s * 0.2, s * 0.12, s * 0.03); ctx.fill();
  },

  mints(ctx, s) {
    ctx.fillStyle = '#cfe9f2';
    roundRect(ctx, s * 0.3, s * 0.3, s * 0.4, s * 0.44, s * 0.12); ctx.fill();
    ctx.strokeStyle = '#7fa9bb'; ctx.lineWidth = 1.4;
    roundRect(ctx, s * 0.3, s * 0.3, s * 0.4, s * 0.44, s * 0.12); ctx.stroke();
    ctx.fillStyle = '#7fa9bb';
    ctx.beginPath(); ctx.arc(s * 0.5, s * 0.52, s * 0.07, 0, Math.PI * 2); ctx.fill();
  },

  charger(ctx, s) {
    ctx.strokeStyle = '#e6ebf2'; ctx.lineWidth = s * 0.045;
    ctx.beginPath();
    ctx.moveTo(s * 0.24, s * 0.3);
    ctx.bezierCurveTo(s * 0.7, s * 0.3, s * 0.3, s * 0.72, s * 0.76, s * 0.72);
    ctx.stroke();
    ctx.fillStyle = METAL;
    roundRect(ctx, s * 0.18, s * 0.24, s * 0.12, s * 0.12, 2); ctx.fill();
    roundRect(ctx, s * 0.72, s * 0.66, s * 0.12, s * 0.12, 2); ctx.fill();
  },

  bottle(ctx, s) {
    ctx.fillStyle = withAlpha('#9fd8e8', 0.65);
    roundRect(ctx, s * 0.36, s * 0.26, s * 0.28, s * 0.54, s * 0.06); ctx.fill();
    ctx.fillStyle = '#8fb9c9';
    roundRect(ctx, s * 0.42, s * 0.14, s * 0.16, s * 0.14, 2); ctx.fill();
    ctx.fillStyle = '#4c7f92';
    ctx.fillRect(s * 0.36, s * 0.48, s * 0.28, s * 0.12);
  },

  book(ctx, s) {
    ctx.fillStyle = '#2f3a4c';
    roundRect(ctx, s * 0.26, s * 0.22, s * 0.48, s * 0.58, s * 0.03); ctx.fill();
    ctx.fillStyle = '#e7ecf3';
    ctx.fillRect(s * 0.3, s * 0.26, s * 0.4, s * 0.5);
    ctx.strokeStyle = '#b9c3d0'; ctx.lineWidth = 1;
    for (let i = 0; i < 5; i++) {
      ctx.beginPath();
      ctx.moveTo(s * 0.34, s * (0.34 + i * 0.08));
      ctx.lineTo(s * 0.66, s * (0.34 + i * 0.08));
      ctx.stroke();
    }
  },

  powerbank(ctx, s) {
    ctx.fillStyle = '#39414f';
    roundRect(ctx, s * 0.26, s * 0.28, s * 0.48, s * 0.44, s * 0.06); ctx.fill();
    ctx.strokeStyle = METAL_DARK; ctx.lineWidth = 1.4;
    roundRect(ctx, s * 0.26, s * 0.28, s * 0.48, s * 0.44, s * 0.06); ctx.stroke();
    for (let i = 0; i < 3; i++) {
      ctx.fillStyle = i < 2 ? PAL.green : '#2b3a33';
      ctx.fillRect(s * (0.32 + i * 0.1), s * 0.62, s * 0.06, s * 0.04);
    }
    ctx.fillStyle = METAL;
    roundRect(ctx, s * 0.44, s * 0.36, s * 0.12, s * 0.1, 2); ctx.fill();
  },

  shades(ctx, s) {
    ctx.fillStyle = '#1b202a';
    roundRect(ctx, s * 0.18, s * 0.42, s * 0.26, s * 0.18, s * 0.08); ctx.fill();
    roundRect(ctx, s * 0.56, s * 0.42, s * 0.26, s * 0.18, s * 0.08); ctx.fill();
    ctx.strokeStyle = METAL_DARK; ctx.lineWidth = s * 0.035;
    ctx.beginPath(); ctx.moveTo(s * 0.44, s * 0.48); ctx.lineTo(s * 0.56, s * 0.48); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(s * 0.18, s * 0.46); ctx.lineTo(s * 0.1, s * 0.4); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(s * 0.82, s * 0.46); ctx.lineTo(s * 0.9, s * 0.4); ctx.stroke();
  },

  meds(ctx, s) {
    // Blister mit aufgedruckter Beschriftung - das unterscheidet ihn vom Doeschen.
    ctx.fillStyle = '#dfe6f0';
    roundRect(ctx, s * 0.22, s * 0.3, s * 0.56, s * 0.4, s * 0.04); ctx.fill();
    ctx.strokeStyle = '#98a3b2'; ctx.lineWidth = 1.3;
    roundRect(ctx, s * 0.22, s * 0.3, s * 0.56, s * 0.4, s * 0.04); ctx.stroke();
    ctx.fillStyle = '#b9c3d0';
    for (let i = 0; i < 3; i++) {
      for (let j = 0; j < 2; j++) {
        ctx.beginPath();
        ctx.arc(s * (0.33 + i * 0.17), s * (0.42 + j * 0.16), s * 0.05, 0, Math.PI * 2);
        ctx.fill();
      }
    }
    ctx.fillStyle = '#4a5464';
    ctx.fillRect(s * 0.26, s * 0.72, s * 0.34, s * 0.03);
  },

  deo(ctx, s) {
    ctx.fillStyle = '#4a7fb5';
    roundRect(ctx, s * 0.38, s * 0.3, s * 0.24, s * 0.48, s * 0.08); ctx.fill();
    ctx.fillStyle = '#e7eef7';
    ctx.beginPath(); ctx.ellipse(s * 0.5, s * 0.3, s * 0.12, s * 0.06, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = withAlpha('#ffffff', 0.25);
    ctx.fillRect(s * 0.42, s * 0.4, s * 0.04, s * 0.3);
  },

  selfie(ctx, s) {
    ctx.strokeStyle = METAL; ctx.lineWidth = s * 0.05;
    ctx.beginPath(); ctx.moveTo(s * 0.24, s * 0.76); ctx.lineTo(s * 0.7, s * 0.3); ctx.stroke();
    ctx.fillStyle = PLASTIC;
    roundRect(ctx, s * 0.62, s * 0.18, s * 0.2, s * 0.16, s * 0.04); ctx.fill();
    ctx.strokeStyle = PLASTIC; ctx.lineWidth = s * 0.08;
    ctx.beginPath(); ctx.moveTo(s * 0.24, s * 0.76); ctx.lineTo(s * 0.18, s * 0.82); ctx.stroke();
  },

  pen(ctx, s) {
    ctx.strokeStyle = '#2f6fb5'; ctx.lineWidth = s * 0.07;
    ctx.beginPath(); ctx.moveTo(s * 0.3, s * 0.74); ctx.lineTo(s * 0.68, s * 0.3); ctx.stroke();
    ctx.fillStyle = METAL;
    ctx.beginPath();
    ctx.moveTo(s * 0.26, s * 0.78); ctx.lineTo(s * 0.34, s * 0.7);
    ctx.lineTo(s * 0.32, s * 0.68); ctx.closePath(); ctx.fill();
    ctx.strokeStyle = METAL_DARK; ctx.lineWidth = s * 0.03;
    ctx.beginPath(); ctx.moveTo(s * 0.6, s * 0.34); ctx.lineTo(s * 0.66, s * 0.42); ctx.stroke();
  },

  snack(ctx, s) {
    ctx.fillStyle = '#8a5a2b';
    roundRect(ctx, s * 0.2, s * 0.4, s * 0.6, s * 0.22, s * 0.05); ctx.fill();
    ctx.fillStyle = '#c98b3f';
    ctx.fillRect(s * 0.34, s * 0.4, s * 0.32, s * 0.22);
    ctx.fillStyle = '#8a5a2b';
    ctx.beginPath();
    ctx.moveTo(s * 0.2, s * 0.4); ctx.lineTo(s * 0.12, s * 0.34);
    ctx.lineTo(s * 0.12, s * 0.68); ctx.lineTo(s * 0.2, s * 0.62); ctx.closePath(); ctx.fill();
    ctx.beginPath();
    ctx.moveTo(s * 0.8, s * 0.4); ctx.lineTo(s * 0.88, s * 0.34);
    ctx.lineTo(s * 0.88, s * 0.68); ctx.lineTo(s * 0.8, s * 0.62); ctx.closePath(); ctx.fill();
  },

  earplugs(ctx, s) {
    for (const [x, y] of [[0.38, 0.44], [0.6, 0.58]]) {
      ctx.fillStyle = '#f0c96a';
      ctx.beginPath();
      ctx.ellipse(s * x, s * y, s * 0.11, s * 0.15, 0.4, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = '#b9932f'; ctx.lineWidth = 1.3; ctx.stroke();
    }
  },

  vape(ctx, s) {
    ctx.fillStyle = '#2b323d';
    roundRect(ctx, s * 0.42, s * 0.2, s * 0.16, s * 0.6, s * 0.05); ctx.fill();
    ctx.fillStyle = '#5fc9d8';
    roundRect(ctx, s * 0.45, s * 0.42, s * 0.1, s * 0.18, 2); ctx.fill();
    ctx.fillStyle = '#1b202a';
    roundRect(ctx, s * 0.44, s * 0.14, s * 0.12, s * 0.08, 2); ctx.fill();
  },

  ticket(ctx, s) {
    ctx.fillStyle = '#e7dfc8';
    roundRect(ctx, s * 0.16, s * 0.34, s * 0.68, s * 0.32, s * 0.04); ctx.fill();
    ctx.strokeStyle = '#a89b78'; ctx.lineWidth = 1.3;
    roundRect(ctx, s * 0.16, s * 0.34, s * 0.68, s * 0.32, s * 0.04); ctx.stroke();
    ctx.strokeStyle = '#a89b78';
    ctx.setLineDash([3, 3]);
    ctx.beginPath(); ctx.moveTo(s * 0.62, s * 0.34); ctx.lineTo(s * 0.62, s * 0.66); ctx.stroke();
    ctx.setLineDash([]);
    ctx.fillStyle = '#57503c';
    for (let i = 0; i < 3; i++) ctx.fillRect(s * 0.22, s * (0.42 + i * 0.07), s * 0.32, s * 0.03);
  },

  /* ---------------- verboten ---------------- */

  camera(ctx, s) {
    ctx.fillStyle = '#1c222c';
    roundRect(ctx, s * 0.16, s * 0.32, s * 0.68, s * 0.42, s * 0.06); ctx.fill();
    ctx.fillStyle = '#2b333f';
    roundRect(ctx, s * 0.36, s * 0.24, s * 0.2, s * 0.1, 2); ctx.fill();
    ctx.fillStyle = '#0d1117';
    ctx.beginPath(); ctx.arc(s * 0.5, s * 0.53, s * 0.16, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = METAL; ctx.lineWidth = s * 0.03;
    ctx.beginPath(); ctx.arc(s * 0.5, s * 0.53, s * 0.16, 0, Math.PI * 2); ctx.stroke();
    ctx.fillStyle = withAlpha('#7fd4ff', 0.5);
    ctx.beginPath(); ctx.arc(s * 0.45, s * 0.48, s * 0.05, 0, Math.PI * 2); ctx.fill();
  },

  glass(ctx, s) {
    ctx.fillStyle = withAlpha('#5f8f4e', 0.85);
    ctx.beginPath();
    ctx.moveTo(s * 0.4, s * 0.82);
    ctx.lineTo(s * 0.4, s * 0.42);
    ctx.quadraticCurveTo(s * 0.42, s * 0.3, s * 0.45, s * 0.24);
    ctx.lineTo(s * 0.55, s * 0.24);
    ctx.quadraticCurveTo(s * 0.58, s * 0.3, s * 0.6, s * 0.42);
    ctx.lineTo(s * 0.6, s * 0.82);
    ctx.closePath(); ctx.fill();
    ctx.fillStyle = '#c1262c';
    ctx.fillRect(s * 0.44, s * 0.18, s * 0.12, s * 0.08);
    ctx.fillStyle = withAlpha('#ffffff', 0.25);
    ctx.fillRect(s * 0.43, s * 0.46, s * 0.04, s * 0.3);
  },

  laser(ctx, s) {
    ctx.fillStyle = '#33404f';
    roundRect(ctx, s * 0.28, s * 0.44, s * 0.44, s * 0.14, s * 0.05); ctx.fill();
    ctx.fillStyle = METAL;
    roundRect(ctx, s * 0.68, s * 0.46, s * 0.08, s * 0.1, 2); ctx.fill();
    ctx.strokeStyle = withAlpha(PAL.green, 0.9); ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(s * 0.78, s * 0.51); ctx.lineTo(s * 0.94, s * 0.51); ctx.stroke();
  },

  substance(ctx, s) {
    ctx.fillStyle = withAlpha('#cfd6e0', 0.9);
    ctx.beginPath();
    ctx.moveTo(s * 0.3, s * 0.34);
    ctx.lineTo(s * 0.7, s * 0.34);
    ctx.lineTo(s * 0.64, s * 0.76);
    ctx.lineTo(s * 0.36, s * 0.76);
    ctx.closePath(); ctx.fill();
    ctx.strokeStyle = '#8d97a5'; ctx.lineWidth = 1.5; ctx.stroke();
    ctx.fillStyle = '#8d97a5';
    ctx.fillRect(s * 0.3, s * 0.28, s * 0.4, s * 0.07);
    ctx.fillStyle = withAlpha('#f2f5f9', 0.85);
    ctx.beginPath(); ctx.ellipse(s * 0.5, s * 0.62, s * 0.12, s * 0.08, 0, 0, Math.PI * 2); ctx.fill();
  },

  spray(ctx, s) {
    ctx.fillStyle = '#c1272d';
    roundRect(ctx, s * 0.38, s * 0.3, s * 0.24, s * 0.5, s * 0.05); ctx.fill();
    ctx.fillStyle = '#2b323d';
    roundRect(ctx, s * 0.42, s * 0.2, s * 0.16, s * 0.12, 2); ctx.fill();
    ctx.strokeStyle = withAlpha(PAL.amber, 0.8); ctx.lineWidth = 2;
    for (let i = 0; i < 3; i++) {
      ctx.beginPath();
      ctx.arc(s * 0.5, s * 0.18, s * (0.1 + i * 0.06), Math.PI * 1.2, Math.PI * 1.8);
      ctx.stroke();
    }
  },

  tool(ctx, s) {
    ctx.fillStyle = METAL;
    roundRect(ctx, s * 0.34, s * 0.3, s * 0.14, s * 0.5, s * 0.03); ctx.fill();
    roundRect(ctx, s * 0.52, s * 0.3, s * 0.14, s * 0.5, s * 0.03); ctx.fill();
    ctx.strokeStyle = METAL_DARK; ctx.lineWidth = 1.5;
    roundRect(ctx, s * 0.34, s * 0.3, s * 0.14, s * 0.5, s * 0.03); ctx.stroke();
    roundRect(ctx, s * 0.52, s * 0.3, s * 0.14, s * 0.5, s * 0.03); ctx.stroke();
    ctx.strokeStyle = '#dfe5ee'; ctx.lineWidth = s * 0.04;
    ctx.beginPath(); ctx.moveTo(s * 0.5, s * 0.3); ctx.lineTo(s * 0.5, s * 0.14); ctx.stroke();
  },

  baton(ctx, s) {
    ctx.strokeStyle = METAL_DARK; ctx.lineWidth = s * 0.09;
    ctx.beginPath(); ctx.moveTo(s * 0.22, s * 0.72); ctx.lineTo(s * 0.56, s * 0.42); ctx.stroke();
    ctx.strokeStyle = METAL; ctx.lineWidth = s * 0.06;
    ctx.beginPath(); ctx.moveTo(s * 0.56, s * 0.42); ctx.lineTo(s * 0.8, s * 0.24); ctx.stroke();
    ctx.fillStyle = PLASTIC;
    ctx.beginPath(); ctx.arc(s * 0.2, s * 0.74, s * 0.08, 0, Math.PI * 2); ctx.fill();
  },

  blade(ctx, s) {
    ctx.fillStyle = METAL;
    ctx.beginPath();
    ctx.moveTo(s * 0.22, s * 0.7);
    ctx.lineTo(s * 0.66, s * 0.28);
    ctx.lineTo(s * 0.74, s * 0.36);
    ctx.lineTo(s * 0.32, s * 0.78);
    ctx.closePath(); ctx.fill();
    ctx.strokeStyle = METAL_DARK; ctx.lineWidth = 1.4; ctx.stroke();
    ctx.strokeStyle = PLASTIC; ctx.lineWidth = s * 0.11;
    ctx.beginPath(); ctx.moveTo(s * 0.3, s * 0.76); ctx.lineTo(s * 0.16, s * 0.86); ctx.stroke();
  },

  cutter(ctx, s) {
    ctx.fillStyle = '#c8b03a';
    roundRect(ctx, s * 0.2, s * 0.46, s * 0.44, s * 0.16, s * 0.03); ctx.fill();
    ctx.strokeStyle = '#8d7b22'; ctx.lineWidth = 1.3;
    roundRect(ctx, s * 0.2, s * 0.46, s * 0.44, s * 0.16, s * 0.03); ctx.stroke();
    ctx.fillStyle = METAL;
    ctx.beginPath();
    ctx.moveTo(s * 0.62, s * 0.48); ctx.lineTo(s * 0.86, s * 0.48);
    ctx.lineTo(s * 0.86, s * 0.58); ctx.lineTo(s * 0.62, s * 0.6); ctx.closePath(); ctx.fill();
    ctx.strokeStyle = METAL_DARK; ctx.stroke();
    ctx.fillStyle = '#8d7b22';
    ctx.beginPath(); ctx.arc(s * 0.34, s * 0.54, s * 0.04, 0, Math.PI * 2); ctx.fill();
  },

  butterfly(ctx, s) {
    ctx.strokeStyle = METAL_DARK; ctx.lineWidth = s * 0.07;
    ctx.beginPath(); ctx.moveTo(s * 0.24, s * 0.72); ctx.lineTo(s * 0.5, s * 0.5); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(s * 0.3, s * 0.8); ctx.lineTo(s * 0.56, s * 0.58); ctx.stroke();
    ctx.fillStyle = METAL;
    ctx.beginPath();
    ctx.moveTo(s * 0.5, s * 0.5); ctx.lineTo(s * 0.82, s * 0.22);
    ctx.lineTo(s * 0.88, s * 0.3); ctx.lineTo(s * 0.56, s * 0.58); ctx.closePath(); ctx.fill();
    ctx.strokeStyle = METAL_DARK; ctx.lineWidth = 1.3; ctx.stroke();
  },

  knuckles(ctx, s) {
    ctx.strokeStyle = METAL; ctx.lineWidth = s * 0.07;
    for (let i = 0; i < 4; i++) {
      ctx.beginPath();
      ctx.arc(s * (0.28 + i * 0.15), s * 0.44, s * 0.07, 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.strokeStyle = METAL_DARK; ctx.lineWidth = s * 0.09;
    ctx.beginPath();
    ctx.moveTo(s * 0.22, s * 0.56);
    ctx.quadraticCurveTo(s * 0.5, s * 0.76, s * 0.78, s * 0.56);
    ctx.stroke();
  },

  stun(ctx, s) {
    ctx.fillStyle = PLASTIC;
    roundRect(ctx, s * 0.34, s * 0.36, s * 0.32, s * 0.44, s * 0.06); ctx.fill();
    ctx.strokeStyle = METAL; ctx.lineWidth = s * 0.045;
    ctx.beginPath(); ctx.moveTo(s * 0.42, s * 0.36); ctx.lineTo(s * 0.42, s * 0.2); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(s * 0.58, s * 0.36); ctx.lineTo(s * 0.58, s * 0.2); ctx.stroke();
    ctx.strokeStyle = withAlpha(PAL.cyan, 0.95); ctx.lineWidth = s * 0.035;
    ctx.beginPath();
    ctx.moveTo(s * 0.42, s * 0.22); ctx.lineTo(s * 0.52, s * 0.28);
    ctx.lineTo(s * 0.46, s * 0.3); ctx.lineTo(s * 0.58, s * 0.22);
    ctx.stroke();
    ctx.fillStyle = PAL.red;
    ctx.beginPath(); ctx.arc(s * 0.5, s * 0.62, s * 0.05, 0, Math.PI * 2); ctx.fill();
  },

  flare(ctx, s) {
    ctx.fillStyle = '#b4322c';
    roundRect(ctx, s * 0.4, s * 0.36, s * 0.2, s * 0.46, s * 0.03); ctx.fill();
    ctx.fillStyle = '#e7dfc8';
    ctx.fillRect(s * 0.4, s * 0.5, s * 0.2, s * 0.08);
    ctx.fillStyle = withAlpha(PAL.amber, 0.95);
    ctx.beginPath();
    ctx.moveTo(s * 0.5, s * 0.08);
    ctx.quadraticCurveTo(s * 0.66, s * 0.26, s * 0.5, s * 0.36);
    ctx.quadraticCurveTo(s * 0.34, s * 0.26, s * 0.5, s * 0.08);
    ctx.closePath(); ctx.fill();
  },

  banger(ctx, s) {
    ctx.fillStyle = '#c1272d';
    roundRect(ctx, s * 0.36, s * 0.4, s * 0.28, s * 0.4, s * 0.04); ctx.fill();
    ctx.fillStyle = '#e7dfc8';
    ctx.fillRect(s * 0.36, s * 0.56, s * 0.28, s * 0.07);
    ctx.strokeStyle = '#d6cba8'; ctx.lineWidth = s * 0.035;
    ctx.beginPath();
    ctx.moveTo(s * 0.5, s * 0.4);
    ctx.quadraticCurveTo(s * 0.66, s * 0.3, s * 0.6, s * 0.16);
    ctx.stroke();
    ctx.fillStyle = withAlpha(PAL.amber, 0.9);
    ctx.beginPath(); ctx.arc(s * 0.6, s * 0.14, s * 0.04, 0, Math.PI * 2); ctx.fill();
  },

  smokepot(ctx, s) {
    ctx.fillStyle = '#4d5a45';
    roundRect(ctx, s * 0.34, s * 0.44, s * 0.32, s * 0.36, s * 0.05); ctx.fill();
    ctx.strokeStyle = '#2f382a'; ctx.lineWidth = 1.4;
    roundRect(ctx, s * 0.34, s * 0.44, s * 0.32, s * 0.36, s * 0.05); ctx.stroke();
    ctx.fillStyle = withAlpha('#c9d2df', 0.5);
    for (let i = 0; i < 3; i++) {
      ctx.beginPath();
      ctx.arc(s * (0.42 + i * 0.09), s * (0.34 - i * 0.07), s * (0.08 - i * 0.012), 0, Math.PI * 2);
      ctx.fill();
    }
  },

  sparkler(ctx, s) {
    ctx.strokeStyle = METAL_DARK; ctx.lineWidth = s * 0.03;
    for (const dx of [-0.06, 0, 0.06]) {
      ctx.beginPath();
      ctx.moveTo(s * (0.42 + dx), s * 0.82); ctx.lineTo(s * (0.5 + dx), s * 0.3);
      ctx.stroke();
    }
    ctx.strokeStyle = withAlpha(PAL.amber, 0.9); ctx.lineWidth = s * 0.025;
    for (let i = 0; i < 6; i++) {
      const a = (i / 6) * Math.PI * 2;
      ctx.beginPath();
      ctx.moveTo(s * 0.5, s * 0.26);
      ctx.lineTo(s * (0.5 + Math.cos(a) * 0.16), s * (0.26 + Math.sin(a) * 0.16));
      ctx.stroke();
    }
  },

  pills(ctx, s) {
    ctx.fillStyle = withAlpha('#e7eef7', 0.85);
    roundRect(ctx, s * 0.34, s * 0.34, s * 0.32, s * 0.44, s * 0.06); ctx.fill();
    ctx.strokeStyle = '#98a3b2'; ctx.lineWidth = 1.5;
    roundRect(ctx, s * 0.34, s * 0.34, s * 0.32, s * 0.44, s * 0.06); ctx.stroke();
    ctx.fillStyle = '#7f8b9b';
    roundRect(ctx, s * 0.32, s * 0.26, s * 0.36, s * 0.1, s * 0.03); ctx.fill();
    for (const [x, y] of [[0.43, 0.52], [0.56, 0.58], [0.48, 0.66]]) {
      ctx.fillStyle = '#d76a8a';
      ctx.beginPath(); ctx.arc(s * x, s * y, s * 0.055, 0, Math.PI * 2); ctx.fill();
    }
  },

  powder(ctx, s) {
    // Gefaltetes Briefchen - ohne jede Beschriftung.
    ctx.fillStyle = '#e9edf3';
    ctx.beginPath();
    ctx.moveTo(s * 0.26, s * 0.4); ctx.lineTo(s * 0.74, s * 0.4);
    ctx.lineTo(s * 0.66, s * 0.7); ctx.lineTo(s * 0.34, s * 0.7);
    ctx.closePath(); ctx.fill();
    ctx.strokeStyle = '#98a3b2'; ctx.lineWidth = 1.4; ctx.stroke();
    ctx.strokeStyle = '#c3ccd8';
    ctx.beginPath(); ctx.moveTo(s * 0.5, s * 0.4); ctx.lineTo(s * 0.5, s * 0.7); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(s * 0.3, s * 0.55); ctx.lineTo(s * 0.7, s * 0.55); ctx.stroke();
  },

  vial(ctx, s) {
    ctx.fillStyle = withAlpha('#9fd8e8', 0.6);
    roundRect(ctx, s * 0.4, s * 0.34, s * 0.2, s * 0.44, s * 0.04); ctx.fill();
    ctx.strokeStyle = '#7fa9bb'; ctx.lineWidth = 1.4;
    roundRect(ctx, s * 0.4, s * 0.34, s * 0.2, s * 0.44, s * 0.04); ctx.stroke();
    ctx.fillStyle = '#c8a45a';
    roundRect(ctx, s * 0.43, s * 0.24, s * 0.14, s * 0.1, 2); ctx.fill();
    ctx.fillStyle = withAlpha('#b5d9a0', 0.9);
    ctx.fillRect(s * 0.42, s * 0.58, s * 0.16, s * 0.18);
  },

  screwdriver(ctx, s) {
    ctx.fillStyle = '#c1272d';
    roundRect(ctx, s * 0.22, s * 0.6, s * 0.26, s * 0.16, s * 0.06); ctx.fill();
    ctx.strokeStyle = METAL; ctx.lineWidth = s * 0.05;
    ctx.beginPath(); ctx.moveTo(s * 0.48, s * 0.68); ctx.lineTo(s * 0.8, s * 0.68); ctx.stroke();
    ctx.fillStyle = METAL_DARK;
    ctx.fillRect(s * 0.78, s * 0.63, s * 0.06, s * 0.1);
  },

  pliers(ctx, s) {
    ctx.strokeStyle = METAL; ctx.lineWidth = s * 0.06;
    ctx.beginPath(); ctx.moveTo(s * 0.28, s * 0.82); ctx.lineTo(s * 0.56, s * 0.44); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(s * 0.5, s * 0.82); ctx.lineTo(s * 0.72, s * 0.44); ctx.stroke();
    ctx.strokeStyle = METAL_DARK; ctx.lineWidth = s * 0.05;
    ctx.beginPath(); ctx.moveTo(s * 0.56, s * 0.44); ctx.lineTo(s * 0.46, s * 0.24); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(s * 0.72, s * 0.44); ctx.lineTo(s * 0.78, s * 0.24); ctx.stroke();
    ctx.fillStyle = '#c1272d';
    ctx.beginPath(); ctx.arc(s * 0.64, s * 0.46, s * 0.05, 0, Math.PI * 2); ctx.fill();
  },

  flask(ctx, s) {
    ctx.fillStyle = METAL;
    roundRect(ctx, s * 0.3, s * 0.3, s * 0.4, s * 0.48, s * 0.1); ctx.fill();
    ctx.strokeStyle = METAL_DARK; ctx.lineWidth = 1.5;
    roundRect(ctx, s * 0.3, s * 0.3, s * 0.4, s * 0.48, s * 0.1); ctx.stroke();
    ctx.fillStyle = METAL_DARK;
    roundRect(ctx, s * 0.44, s * 0.2, s * 0.12, s * 0.12, 2); ctx.fill();
    ctx.strokeStyle = withAlpha('#ffffff', 0.3); ctx.lineWidth = s * 0.03;
    ctx.beginPath(); ctx.moveTo(s * 0.38, s * 0.4); ctx.lineTo(s * 0.38, s * 0.68); ctx.stroke();
  },

  wine(ctx, s) {
    ctx.fillStyle = withAlpha('#3c2a45', 0.9);
    ctx.beginPath();
    ctx.moveTo(s * 0.38, s * 0.84);
    ctx.lineTo(s * 0.38, s * 0.46);
    ctx.quadraticCurveTo(s * 0.42, s * 0.32, s * 0.45, s * 0.22);
    ctx.lineTo(s * 0.55, s * 0.22);
    ctx.quadraticCurveTo(s * 0.58, s * 0.32, s * 0.62, s * 0.46);
    ctx.lineTo(s * 0.62, s * 0.84);
    ctx.closePath(); ctx.fill();
    ctx.fillStyle = '#8a2b3a';
    ctx.fillRect(s * 0.44, s * 0.14, s * 0.12, s * 0.1);
    ctx.fillStyle = '#e7dfc8';
    ctx.fillRect(s * 0.38, s * 0.56, s * 0.24, s * 0.16);
  },

  lens(ctx, s) {
    ctx.fillStyle = '#1c222c';
    roundRect(ctx, s * 0.26, s * 0.3, s * 0.48, s * 0.46, s * 0.06); ctx.fill();
    ctx.strokeStyle = METAL_DARK; ctx.lineWidth = 1.5;
    for (let i = 0; i < 3; i++) {
      ctx.beginPath();
      ctx.moveTo(s * 0.26, s * (0.42 + i * 0.11)); ctx.lineTo(s * 0.74, s * (0.42 + i * 0.11));
      ctx.stroke();
    }
    ctx.fillStyle = '#0d1117';
    ctx.beginPath(); ctx.ellipse(s * 0.5, s * 0.3, s * 0.24, s * 0.08, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = withAlpha('#7fd4ff', 0.45);
    ctx.beginPath(); ctx.ellipse(s * 0.5, s * 0.3, s * 0.16, s * 0.05, 0, 0, Math.PI * 2); ctx.fill();
  },

  actioncam(ctx, s) {
    ctx.fillStyle = '#2b333f';
    roundRect(ctx, s * 0.28, s * 0.32, s * 0.44, s * 0.4, s * 0.06); ctx.fill();
    ctx.strokeStyle = METAL_DARK; ctx.lineWidth = 1.4;
    roundRect(ctx, s * 0.28, s * 0.32, s * 0.44, s * 0.4, s * 0.06); ctx.stroke();
    ctx.fillStyle = '#0d1117';
    ctx.beginPath(); ctx.arc(s * 0.46, s * 0.52, s * 0.11, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = withAlpha('#7fd4ff', 0.55);
    ctx.beginPath(); ctx.arc(s * 0.43, s * 0.49, s * 0.04, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = PAL.red;
    ctx.fillRect(s * 0.62, s * 0.38, s * 0.05, s * 0.05);
  },

  blinder(ctx, s) {
    ctx.fillStyle = '#33404f';
    roundRect(ctx, s * 0.24, s * 0.4, s * 0.34, s * 0.2, s * 0.05); ctx.fill();
    ctx.fillStyle = METAL;
    ctx.beginPath();
    ctx.moveTo(s * 0.58, s * 0.34); ctx.lineTo(s * 0.72, s * 0.28);
    ctx.lineTo(s * 0.72, s * 0.72); ctx.lineTo(s * 0.58, s * 0.66);
    ctx.closePath(); ctx.fill();
    ctx.strokeStyle = withAlpha('#fff3c4', 0.9); ctx.lineWidth = 2;
    for (let i = -1; i <= 1; i++) {
      ctx.beginPath();
      ctx.moveTo(s * 0.74, s * (0.5 + i * 0.06));
      ctx.lineTo(s * 0.94, s * (0.5 + i * 0.16));
      ctx.stroke();
    }
  }
};

function drawUnknown(ctx, s) {
  ctx.strokeStyle = PAL.grey;
  ctx.lineWidth = 2;
  roundRect(ctx, s * 0.28, s * 0.28, s * 0.44, s * 0.44, 4);
  ctx.stroke();
  ctx.fillStyle = PAL.grey;
  ctx.font = `${Math.round(s * 0.3)}px "IBM Plex Mono", monospace`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('?', s * 0.5, s * 0.52);
}

/**
 * Umhängetasche an der Figur.
 * Der Riemen läuft von der gegenüberliegenden Schulter schräg über den Körper
 * zur Tasche an der Hüfte - so, wie man sie wirklich trägt.
 */
export function drawShoulderBag(ctx, { x, y, w, h, strapX, strapY, color = '#3a4557' }) {
  ctx.save();
  // Riemen
  if (strapX !== undefined) {
    ctx.strokeStyle = '#20262f';
    ctx.lineWidth = Math.max(2.5, w * 0.11);
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.moveTo(strapX, strapY);
    ctx.quadraticCurveTo((strapX + x + w * 0.5) / 2, (strapY + y) / 2 + h * 0.1, x + w * 0.5, y + h * 0.12);
    ctx.stroke();
  }

  // Korpus
  ctx.fillStyle = color;
  roundRect(ctx, x, y, w, h, w * 0.14);
  ctx.fill();
  // Deckelklappe
  ctx.fillStyle = 'rgba(0,0,0,0.3)';
  roundRect(ctx, x, y, w, h * 0.42, w * 0.14);
  ctx.fill();
  // Verschluss
  ctx.fillStyle = METAL_DARK;
  roundRect(ctx, x + w * 0.4, y + h * 0.34, w * 0.2, h * 0.16, 2);
  ctx.fill();
  ctx.strokeStyle = 'rgba(0,0,0,0.45)';
  ctx.lineWidth = 1.4;
  roundRect(ctx, x, y, w, h, w * 0.14);
  ctx.stroke();
  ctx.restore();
}
