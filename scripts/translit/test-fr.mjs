#!/usr/bin/env node
// Hand-checked unit tests for the Hebrew -> French transliterator (convention A, see FR-NOTES.md / spec-fr.json).
//   node scripts/translit/test-fr.mjs
// Expected strings were derived by hand from the convention (kh, k for qof, ch, ts, é, ou, doubled dagesh chazak,
// gu/ss/ï rules, Adonaï), and cross-checked against attested forms in the app's existing French data.
import { scheme } from './fr.mjs';
import { transliterate, newStats } from './core.mjs';

const T = (s) => transliterate(s, scheme, newStats()).out;
let pass = 0; const fails = [];
function eq(name, he, expected) {
  const got = T(he);
  if (got === expected) pass++; else fails.push(`${name}: ${he}\n   expected: ${expected}\n   got:      ${got}`);
}

// --- letters and vowels
eq('chalom (shin=ch, cholam-vav)', 'שָׁלוֹם', 'Chalom');
eq('tora (silent final he)', 'תּוֹרָה', 'Tora');
eq('moche (segol, silent he)', 'מֹשֶׁה', 'Moché');
eq('yisrael (sin, silent aleph, tsere=é)', 'יִשְׂרָאֵל', 'Yisraél');
eq('kodech (qof=k, tsadi)', 'קֹדֶשׁ', 'Kodéch');
eq('tsaddik (ts, doubled dalet, final kaf=kh)', 'צַדִּיק', 'Tsaddik');
eq('rouakh (furtive patach)', 'רוּחַ', 'Rouakh');
eq('yodea (furtive patach on ayin)', 'יוֹדֵעַ', 'Yodéa');
eq('elohim (hataf segol, chirik-yod)', 'אֱלֹהִים', 'Élohim');
eq('bayit (consonant yod after patach)', 'בַּיִת', 'Bayit');
eq('hammayim (doubled mem, patach-yod)', 'הַמַּיִם', 'Hammayim');
eq('en (tsere-yod = é)', 'אֵין', 'Én');
eq('kubutz = ou', 'סֻכָּה', 'Soukka');
eq('shuruk = ou', 'וְהוּא', 'Véhou');
eq('khaf soft / khaf dagesh', 'מְכַכֵּב', 'Mékhakkév');
eq('pe soft = f', 'יוֹסֵף', 'Yosséf');
eq('bet soft = v', 'אָבִיב', 'Aviv');

// --- doubling (dagesh chazak)
eq('hashem (doubled shin)', 'הַשֵּׁם', 'Hachchém');
eq('chabbat (doubled bet)', 'שַׁבָּת', 'Chabbat');
eq('michchoum (doubled shin after chirik)', 'מִשּׁוּם', 'Michchoum');
eq('ribbi', 'רִבִּי', 'Ribbi');
eq('mippene (pe doubled)', 'מִפְּנֵי', 'Mippéné');
eq('vayyomer (yod dagesh)', 'וַיֹּאמֶר', 'Vayyomér');
eq('word-final dagesh not doubled (at)', 'אַתְּ', 'At');
eq('dagesh kal after shva not doubled (yitgabber)', 'יִתְגַּבֵּר', 'Yitgabbér');

// --- shva
eq('shva na at word start', 'בְּרֵאשִׁית', 'Béréchit');
eq('shva nach after short vowel (omrim silent)', 'אוֹמְרִים', 'Omrim');
eq('shva nach (malkout)', 'מַלְכוּת', 'Malkhout');
eq('shva na after vav-shuruk', 'וּבְכָל', 'Ouvékhol');
eq('shva na under doubled letter', 'הַמְּעַט', 'Hamméat');
eq('two shvas: second vocal', 'וַיֵּבְךְּ', 'Vayyévk');
eq('ha + shva letter: shva vocal', 'הַמְקַבֵּל', 'Hamékabbél');
eq('final shva silent', 'נָתַנְתְּ', 'Natant');

// --- gu / ss / ï / kol
eq('guemara (gu before é)', 'גְּמָרָא', 'Guémara');
eq('guet (gu before é, tsere)', 'גֵּט', 'Guét');
eq('gadol (g before o)', 'גָּדוֹל', 'Gadol');
eq('assour (ss between vowels)', 'אָסוּר', 'Assour');
eq('yossi (ss)', 'יוֹסֵי', 'Yossé');
eq('sin at word start stays s', 'שָׂם', 'Sam');
eq('s after shva nach stays s', 'מִסְפָּר', 'Mispar');
eq('hoil (ï after o)', 'הוֹאִיל', 'Hoïl');
eq('haicha (ï after a)', 'הָאִשָּׁה', 'Haïchcha');
eq('kol (qamatz katan)', 'כָּל', 'Kol');
eq('explicit qamatz katan mark (U+05C7)', 'חׇכְמָה', 'Khokhma');
eq('unmarked qamatz stays a', 'חָכְמָה', 'Khakhma');
eq('amro: unmarked qamatz before shva = a', 'אָמְרוֹ', 'Amro');

// --- mater yod / vav
eq('alav (qamatz, yod, final vav)', 'עָלָיו', 'Alav');
eq('beevarav', 'בְּאֵבָרָיו', 'Béévarav');
eq('vav consonant after vowelled letter (mitsvot)', 'מִצְוֹת', 'Mitsvot');
eq('ayin silent (yaatsim)', 'יַעֲצִימוּ', 'Yaatsimou');

// --- mappiq he and final he
eq('mappiq he after qamatz is sounded', 'אוֹתָהּ', 'Otah');
eq('mappiq he after shuruk (Aramaic) is silent', 'אֲבוּהּ', 'Avou');
eq('mappiq he after tsere-yod sounded (daf style)', 'לֵיהּ', 'Léh');

// --- divine name, abbreviations, punctuation, case
eq('written Name', 'יְיָ', 'Adonaï');
eq('Hashem abbreviation', "ה'", 'Adonaï');
eq('prefix + Hashem', "לַה'", 'LaAdonaï');
eq('vegomer', "וְגוֹ'", 'Végomér');
eq('maqaf -> hyphen, lower case mid-sentence', 'בָּרוּךְ־הוּא כָּל', 'Baroukh-hou kol');
eq('sentence start capital only', 'לֹא. לֹא', 'Lo. Lo');
eq('<b> markers and punctuation kept', '<b>דִּין:</b> שָׁלוֹם', '<b>Din:</b> chalom');
eq('Adonai stays capital mid-sentence', 'שָׁלוֹם יְיָ', 'Chalom Adonaï');
eq('word ending in yod-yod is not the Name', 'לְשַׁוּוֹיֵי', 'Léchavvoyé');

if (fails.length) { console.log(`${pass} passed, ${fails.length} FAILED\n` + fails.join('\n')); process.exit(1); }
console.log(`all ${pass} French transliteration tests passed`);
