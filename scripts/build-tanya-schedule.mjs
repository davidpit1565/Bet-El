#!/usr/bin/env node
/* Rebuilds data/tanya-schedule.json with each day's EXACT Tanya Yomi portion.

   The original schedule stored only the chapter/letter a day STARTS in
   (orderIndex), so the app showed that whole chapter for every day the
   chapter spans - up to 11 days in a row (Kuntres Acharon 4), and the same
   chapter in two consecutive weeks. Sefaria's calendar API gives the exact
   starting segment of each day's portion ("Iggeret HaKodesh 27:8"); a day
   runs from its own start up to (not including) the next day's start, and
   the last day of the cycle (18 Kislev) runs to the end of the book. The
   segment numbering is the same Kehot edition our data/chok-tanya/ blocks
   come from (verified segment-for-segment).

   Each order entry keeps orderIndex (the day's first unit, so older app
   builds keep working) and gains:
     hm, hd  - hebcal month number (Nisan=1 .. Adar/Adar I=12, Adar II=13) and
               day, so the app looks a day up by its Hebrew date (correct even
               in years whose Cheshvan/Kislev have 29 days)
     seg     - [[orderIndex, from, to], ...] 0-based inclusive segment ranges

   Usage: node scripts/build-tanya-schedule.mjs [regularStart leapStart]
   (Gregorian dates of 19 Kislev starting a regular and a leap cycle;
   defaults 2025-12-09 = 19 Kislev 5786, 2026-11-29 = 19 Kislev 5787). */
import fs from 'node:fs';

const REG_START = process.argv[2] || '2025-12-09';
const LEAP_START = process.argv[3] || '2026-11-29';
const MONTHS = {Nissan:1, Iyar:2, Sivan:3, Tammuz:4, Av:5, Elul:6, Tishrei:7, Cheshvan:8, Kislev:9,
  Tevet:10, Shevat:11, Adar:12, 'Adar I':12, 'Adar II':13};

const idx = JSON.parse(fs.readFileSync('data/chok-tanya-index.json', 'utf8'));
const old = JSON.parse(fs.readFileSync('data/tanya-schedule.json', 'utf8'));
const refPos = new Map(idx.order.map((e, i) => [e.ref, i]));

function addDays(iso, n){ const d = new Date(iso + 'T12:00:00Z'); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10); }
async function sefariaDay(iso){
  const [y, m, d] = iso.split('-').map(Number);
  for(let t = 0; t < 8; t++){
    try{
      const r = await fetch(`https://www.sefaria.org/api/calendars?year=${y}&month=${m}&day=${d}&diaspora=1`);
      const j = await r.json();
      const it = j.calendar_items.find(x => x.title.en === 'Tanya Yomi');
      if(it) return {ref: it.ref, label: it.displayValue.en, labelHe: it.displayValue.he};
    }catch(e){ if(t === 7) throw e; }
    await new Promise(res => setTimeout(res, 1000 * (t + 1))); // rate-limited / transient: back off
  }
  throw new Error('no Tanya Yomi for ' + iso);
}
/* "…Iggeret HaKodesh 27:8" -> unit "…Iggeret HaKodesh 27", segment 8;
   "…Likkutei Amarim, Title Page 1" (single-level unit) -> unit without number */
function parseStart(ref){
  let m = /^(.*):(\d+)$/.exec(ref);
  if(m) return {unit: m[1], seg: +m[2]};
  m = /^(.*) (\d+)$/.exec(ref);
  return {unit: m[1], seg: +m[2]};
}
async function build(startIso, n){
  const days = [];
  for(let i = 0; i < n; i += 4){
    const batch = [];
    for(let k = i; k < Math.min(n, i + 4); k++) batch.push(sefariaDay(addDays(startIso, k)));
    days.push(...await Promise.all(batch));
  }
  const starts = days.map(d => {
    const p = parseStart(d.ref);
    const oi = refPos.get(p.unit);
    if(oi == null) throw new Error('unknown unit ' + d.ref);
    if(p.seg < 1 || p.seg > idx.order[oi].n) throw new Error('segment out of range ' + d.ref);
    return {oi, seg: p.seg - 1};
  });
  if(starts[0].oi !== 0 || starts[0].seg !== 0) throw new Error('cycle must start at the title page');
  return days.map((d, i) => {
    const a = starts[i];
    const b = i + 1 < n ? starts[i + 1] : {oi: idx.order.length, seg: 0};
    if(b.oi < a.oi || (b.oi === a.oi && b.seg <= a.seg)) throw new Error('empty/backwards portion on ' + d.label);
    const seg = [];
    for(let oi = a.oi; oi <= b.oi; oi++){
      const from = oi === a.oi ? a.seg : 0;
      const to = oi === b.oi ? b.seg - 1 : idx.order[oi].n - 1;
      if(to >= from) seg.push([oi, from, to]);
    }
    const [day, ...mon] = d.label.split(' ');
    const hm = MONTHS[mon.join(' ')];
    if(!hm) throw new Error('month? ' + d.label);
    return {orderIndex: seg[0][0], hebrewDateLabelHe: d.labelHe, hebrewDateLabel: d.label, hm, hd: +day, seg};
  });
}
const out = {};
for(const [key, start] of [['regular', REG_START], ['leap', LEAP_START]]){
  const n = old[key].dayCount;
  const order = await build(start, n);
  out[key] = {...old[key], cycleStartDateExample: start, cycleEndDateExample: addDays(start, n - 1),
    source: 'Sefaria calendar API (Tanya Yomi), exact daily start segments', order};
  /* every segment of the book exactly once per cycle */
  const total = idx.order.reduce((s, e) => s + e.n, 0);
  const covered = order.reduce((s, e) => s + e.seg.reduce((t, [, f, to]) => t + to - f + 1, 0), 0);
  if(covered !== total) throw new Error(`${key}: covers ${covered} of ${total} segments`);
  console.log(key, n, 'days,', covered, 'segments');
}
fs.writeFileSync('data/tanya-schedule.json', JSON.stringify(out));
