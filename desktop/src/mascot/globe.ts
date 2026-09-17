// Disegno del globo su canvas: porting di `Globe`, `GlobeBody`, `GlobeFeatures` e
// `GlobeSheen` in `Globy/Mascot/MascotView.swift`. Stessa geometria, stesse luci.

export type Vec3 = [number, number, number];
export interface Gaze {
  dx: number;
  dy: number;
}

/** Inclinazione dell'asse verso chi guarda: rende le latitudini ellissi. */
const TILT = 0.32;
/** Occhi in posizione fissa sulla sfera: guardano chi osserva quando la testa è dritta. */
const EYE_LON = 0.38;
const EYE_LAT = 0.08 + TILT;
const PARALLELS = [-35, 0, 35];
const MERIDIANS = [30, 90, 150];

export function globeRadius(size: number): number {
  return (size / 2) * 0.86;
}

export function globeCenter(size: number): { x: number; y: number } {
  return { x: size / 2, y: size / 2 - globeRadius(size) * 0.04 };
}

/** Punto unitario della sfera nelle coordinate del corpo (z verso chi guarda). */
function point(lon: number, lat: number): Vec3 {
  return [Math.cos(lat) * Math.sin(lon), Math.sin(lat), Math.cos(lat) * Math.cos(lon)];
}

/** Corpo → vista: rotazione della testa attorno all'asse verticale, poi inclinazione. */
function rotate(v: Vec3, gaze: Gaze): Vec3 {
  const yaw = gaze.dx;
  const pitch = TILT - gaze.dy;
  const x = v[0] * Math.cos(yaw) + v[2] * Math.sin(yaw);
  const z = -v[0] * Math.sin(yaw) + v[2] * Math.cos(yaw);
  return [x, v[1] * Math.cos(pitch) - z * Math.sin(pitch), v[1] * Math.sin(pitch) + z * Math.cos(pitch)];
}

function screen(v: Vec3, cx: number, cy: number, r: number): [number, number] {
  return [cx + v[0] * r, cy - v[1] * r];
}

function normalize(v: Vec3): Vec3 {
  const l = Math.hypot(v[0], v[1], v[2]) || 1;
  return [v[0] / l, v[1] / l, v[2] / l];
}

function cross(a: Vec3, b: Vec3): Vec3 {
  return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
}

function disk(ctx: CanvasRenderingContext2D, cx: number, cy: number, r: number): void {
  ctx.beginPath();
  ctx.arc(cx, cy, r, 0, Math.PI * 2);
}

/** Canvas del sistema supporta `filter`? WebKitGTK vecchi no: bagliore con l'ombra. */
const supportsFilter = "filter" in CanvasRenderingContext2D.prototype;

function blurred(ctx: CanvasRenderingContext2D, radius: number, draw: () => void): void {
  ctx.save();
  if (supportsFilter) {
    ctx.filter = `blur(${radius}px)`;
    draw();
  } else {
    // L'ombra di una figura spostata fuori vista disegna solo la sfocatura.
    ctx.shadowBlur = radius * 2;
    ctx.shadowColor = ctx.fillStyle as string;
    draw();
  }
  ctx.restore();
}

// MARK: Corpo (statico)

/** Ombra e corpo della sfera, luce dall'alto a sinistra. Sul vetro, una velatura leggera. */
export function drawBody(ctx: CanvasRenderingContext2D, size: number, glass: boolean): void {
  const r = globeRadius(size);
  const { x: cx, y: cy } = globeCenter(size);
  const light = { x: cx - r * 0.45, y: cy - r * 0.5 };
  ctx.clearRect(0, 0, size, size);

  ctx.fillStyle = `rgba(0,0,0,${glass ? 0.22 : 0.35})`;
  blurred(ctx, r * 0.08, () => {
    ctx.beginPath();
    ctx.ellipse(cx, cy + r * 1.0, r * 0.7, r * 0.08, 0, 0, Math.PI * 2);
    ctx.fill();
  });

  if (!glass) {
    const g = ctx.createRadialGradient(light.x, light.y, 0, light.x, light.y, r * 1.9);
    g.addColorStop(0, "rgb(92,92,92)");
    g.addColorStop(0.45, "rgb(36,36,36)");
    g.addColorStop(1, "rgb(10,10,10)");
    ctx.fillStyle = g;
    disk(ctx, cx, cy, r);
    ctx.fill();
    return;
  }
  const veil = ctx.createRadialGradient(light.x, light.y, 0, light.x, light.y, r * 1.9);
  veil.addColorStop(0, "rgba(255,255,255,0.10)");
  veil.addColorStop(0.5, "rgba(0,0,0,0)");
  veil.addColorStop(1, "rgba(0,0,0,0.14)");
  ctx.fillStyle = veil;
  disk(ctx, cx, cy, r);
  ctx.fill();
  const rim = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
  rim.addColorStop(0.7, "rgba(255,255,255,0)");
  rim.addColorStop(0.95, "rgba(255,255,255,0.18)");
  rim.addColorStop(1, "rgba(255,255,255,0.05)");
  ctx.fillStyle = rim;
  disk(ctx, cx, cy, r);
  ctx.fill();
}

// MARK: Riflesso (statico)

export function drawSheen(ctx: CanvasRenderingContext2D, size: number): void {
  const r = globeRadius(size);
  const { x: cx, y: cy } = globeCenter(size);
  ctx.clearRect(0, 0, size, size);
  ctx.save();
  disk(ctx, cx, cy, r);
  ctx.clip();
  ctx.fillStyle = "rgba(255,255,255,0.22)";
  blurred(ctx, r * 0.12, () => {
    ctx.beginPath();
    ctx.ellipse(cx - r * 0.37, cy - r * 0.61, r * 0.25, r * 0.17, 0, 0, Math.PI * 2);
    ctx.fill();
  });
  const stroke = ctx.createLinearGradient(cx - r, cy - r, cx + r, cy + r);
  stroke.addColorStop(0, "rgba(255,255,255,0)");
  stroke.addColorStop(1, "rgba(255,255,255,0.14)");
  ctx.strokeStyle = stroke;
  ctx.lineWidth = r * 0.04;
  disk(ctx, cx, cy, r);
  ctx.stroke();
  ctx.restore();
}

// MARK: Griglia e occhi (animati)

export interface FeatureState {
  glass: boolean;
  gaze: Gaze;
  eyeOpen: number;
  eyeWidth: number;
  eyeArch: number;
}

/** Strato di lavoro riusato a ogni fotogramma, per l'ombreggiatura dei tubicini. */
let scratch: HTMLCanvasElement | null = null;

export function drawFeatures(ctx: CanvasRenderingContext2D, size: number, pixelRatio: number, s: FeatureState): void {
  const r = globeRadius(size);
  const { x: cx, y: cy } = globeCenter(size);
  ctx.clearRect(0, 0, size, size);
  drawGrid(ctx, size, pixelRatio, s, cx, cy, r);
  drawEyes(ctx, s, cx, cy, r);
}

/** Paralleli e meridiani come tubicini in rilievo: nastri costruiti sulla superficie 3D e
 *  proiettati. Tre nastri sovrapposti danno la sezione rotonda: bordo, corpo, riflesso. */
function drawGrid(
  target: CanvasRenderingContext2D,
  size: number,
  pixelRatio: number,
  s: FeatureState,
  cx: number,
  cy: number,
  r: number,
): void {
  // 72 segmenti per giro: sul globo di 70 pt i lati restano sotto i 3 pt.
  const steps = 72;
  const hw = 0.031;
  const light: [number, number] = [-0.6, -0.8];
  const edge = new Path2D();
  const core = new Path2D();
  const shine = new Path2D();

  const addRibbon = (path: Path2D, left: [number, number][], right: [number, number][]) => {
    if (left.length < 2) return;
    path.moveTo(left[0][0], left[0][1]);
    for (let i = 1; i < left.length; i++) path.lineTo(left[i][0], left[i][1]);
    for (let i = right.length - 1; i >= 0; i--) path.lineTo(right[i][0], right[i][1]);
    path.closePath();
  };

  const addCurve = (pointAt: (t: number) => Vec3) => {
    const pts: Vec3[] = [];
    for (let i = 0; i < steps; i++) pts.push(pointAt(i / steps));
    // Si parte da un punto nascosto, così un tratto visibile non si spezza a metà.
    let start = pts.findIndex((p) => rotate(p, s.gaze)[2] < -0.05);
    if (start < 0) start = 0;
    let el: [number, number][] = [], er: [number, number][] = [];
    let cl: [number, number][] = [], cr: [number, number][] = [];
    let sl: [number, number][] = [], sr: [number, number][] = [];
    const flush = () => {
      addRibbon(edge, el, er);
      addRibbon(core, cl, cr);
      addRibbon(shine, sl, sr);
      el = []; er = []; cl = []; cr = []; sl = []; sr = [];
    };
    for (let j = 0; j <= steps; j++) {
      const i = (start + j) % steps;
      const p = pts[i];
      // Leggermente oltre l'orizzonte: il bordo della sfera fa da maschera.
      if (rotate(p, s.gaze)[2] <= -0.05) {
        flush();
        continue;
      }
      const a = pts[(i + 1) % steps];
      const b = pts[(i + steps - 1) % steps];
      const side = normalize(cross([a[0] - b[0], a[1] - b[1], a[2] - b[2]], p));
      const s3 = rotate(side, s.gaze);
      const len = Math.hypot(s3[0], s3[1]);
      const k = len > 1e-3 ? Math.max(-1, Math.min(1, (s3[0] / len) * light[0] + (-s3[1] / len) * light[1])) : 0;
      const at = (offset: number) =>
        screen(rotate(normalize([p[0] + side[0] * offset, p[1] + side[1] * offset, p[2] + side[2] * offset]), s.gaze), cx, cy, r);
      el.push(at(hw)); er.push(at(-hw));
      cl.push(at(hw * (0.12 * k + 0.72))); cr.push(at(hw * (0.12 * k - 0.72)));
      sl.push(at(hw * (0.45 * k + 0.14))); sr.push(at(hw * (0.45 * k - 0.14)));
    }
    flush();
  };

  for (const lat of PARALLELS) addCurve((t) => point(t * 2 * Math.PI, (lat * Math.PI) / 180));
  for (const lon of MERIDIANS) addCurve((t) => point((lon * Math.PI) / 180, (t - 0.5) * 2 * Math.PI));

  // Strato a parte: l'ombreggiatura `source-atop` deve toccare solo i tubicini.
  if (!scratch) scratch = document.createElement("canvas");
  const px = Math.ceil(size * pixelRatio);
  if (scratch.width !== px) {
    scratch.width = px;
    scratch.height = px;
  }
  const ctx = scratch.getContext("2d")!;
  ctx.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0);
  ctx.clearRect(0, 0, size, size);
  ctx.save();
  disk(ctx, cx, cy, r);
  ctx.clip();
  const glass = s.glass;
  ctx.fillStyle = glass ? "rgb(158,158,158)" : "rgb(41,41,41)";
  ctx.fill(edge);
  ctx.fillStyle = glass ? "rgb(217,217,217)" : "rgb(77,77,77)";
  ctx.fill(core);
  // Niente sfocatura sul riflesso: a questa scala sarebbe sotto il pixel.
  ctx.fillStyle = glass ? "rgb(255,255,255)" : "rgb(158,158,158)";
  ctx.fill(shine);
  // Stessa luce della sfera: i tubicini si scuriscono lontano dalla luce.
  ctx.globalCompositeOperation = "source-atop";
  const lx = cx - r * 0.45, ly = cy - r * 0.5;
  const shade = ctx.createRadialGradient(lx, ly, 0, lx, ly, r * 1.9);
  shade.addColorStop(0, "rgba(0,0,0,0)");
  shade.addColorStop(0.55, `rgba(0,0,0,${glass ? 0.1 : 0.25})`);
  shade.addColorStop(1, `rgba(0,0,0,${glass ? 0.35 : 0.7})`);
  ctx.fillStyle = shade;
  ctx.fillRect(0, 0, size, size);
  ctx.restore();

  target.save();
  target.setTransform(1, 0, 0, 1, 0, 0);
  target.drawImage(scratch, 0, 0);
  target.restore();
}

/** Occhi solidali alla sfera, capsule sulla superficie: seguono la curvatura e si
 *  deformano in prospettiva quando la testa gira. */
function drawEyes(ctx: CanvasRenderingContext2D, s: FeatureState, cx: number, cy: number, r: number): void {
  const halfWidth = 0.115 * Math.max(s.eyeWidth, 0.5);
  const halfStraight = 0.19;
  // Il battito schiaccia la capsula in verticale fino a una sottile fessura.
  const squash = Math.max(s.eyeOpen, 0.12);
  const arch = Math.max(0, s.eyeArch);
  const arcSteps = 10, sideSteps = 8;
  const eyes = new Path2D();
  for (const side of [-1, 1]) {
    const outline: [number, number][] = [];
    for (let k = 0; k <= arcSteps; k++) {
      const a = (Math.PI * k) / arcSteps;
      outline.push([halfWidth * Math.cos(a), halfStraight + halfWidth * Math.sin(a)]);
    }
    for (let k = 0; k <= sideSteps; k++) outline.push([-halfWidth, halfStraight - (2 * halfStraight * k) / sideSteps]);
    for (let k = 0; k <= arcSteps; k++) {
      const a = Math.PI + (Math.PI * k) / arcSteps;
      outline.push([halfWidth * Math.cos(a), -halfStraight + halfWidth * Math.sin(a)]);
    }
    for (let k = 0; k <= sideSteps; k++) outline.push([halfWidth, -halfStraight + (2 * halfStraight * k) / sideSteps]);
    outline.forEach(([u, v], n) => {
      const uNorm = u / halfWidth;
      const bow = arch * (1 - uNorm * uNorm);
      const lat = EYE_LAT + v * squash + bow;
      const lon = side * EYE_LON + u / Math.cos(lat);
      const [x, y] = screen(rotate(point(lon, lat), s.gaze), cx, cy, r);
      if (n === 0) eyes.moveTo(x, y);
      else eyes.lineTo(x, y);
    });
    eyes.closePath();
  }
  // Alone e bagliore in un solo strato sfocato: una sfocatura per fotogramma.
  ctx.save();
  if (supportsFilter) {
    ctx.filter = `blur(${r * 0.13}px)`;
    if (s.glass) {
      // Alone scuro morbido: gli occhi restano leggibili anche su sfondi chiari.
      ctx.fillStyle = "rgba(0,0,0,0.35)";
      ctx.fill(eyes);
    }
    ctx.fillStyle = "rgba(255,255,255,0.55)";
    ctx.fill(eyes);
  } else {
    ctx.shadowColor = "rgba(255,255,255,0.55)";
    ctx.shadowBlur = r * 0.26;
    ctx.fillStyle = "rgba(255,255,255,0.55)";
    ctx.fill(eyes);
  }
  ctx.restore();
  ctx.fillStyle = "white";
  ctx.fill(eyes);
}

/** Apertura degli occhi `elapsed` secondi dopo l'inizio di un battito. */
export function eyeOpen(elapsed: number, double: boolean): number {
  const blink = (start: number) => {
    const d = elapsed - start;
    if (d < 0 || d >= 0.18) return 1;
    return Math.abs(d - 0.09) / 0.09;
  };
  return Math.min(blink(0), double ? blink(0.28) : 1);
}
