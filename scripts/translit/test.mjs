#!/usr/bin/env node
// Hand-checked unit tests for the Hebrew -> English transliterator (no dependencies).
//   node scripts/translit/test.mjs
// Expected strings were derived by hand from Hebrew phonology + the conventions documented in README.md
// (BIC/prayers style: b/k/p for bet/kaf/pe, ch = chet, q = qof, tz, doubled dagesh chazak).
import { scheme } from './en.mjs';
import { transliterate, newStats } from './core.mjs';

const T = (s) => transliterate(s, scheme, newStats()).out;
let pass = 0; const fails = [];
function eq(name, he, expected) {
  const got = T(he);
  if (got === expected) pass++; else fails.push(`${name}: ${he}\n   expected: ${expected}\n   got:      ${got}`);
}

// --- basics: vowels, matres, dagesh
eq('shalom', 'שָׁלוֹם', 'Shalom');
eq('bereshit (shva na at start, hirik+yod)', 'בְּרֵאשִׁית', 'Bereshit');
eq('hashshamayim (dagesh chazak after article)', 'הַשָּׁמַיִם', 'Hashshamayim');
eq('vayhi (shva nach after patach)', 'וַיְהִי', 'Vayhi');
eq('yisrael (sin, silent aleph)', 'יִשְׂרָאֵל', 'Yisrael');
eq('tora (final he after qamatz silent)', 'תּוֹרָה', 'Tora');
eq('mosheh (final he after segol sounded)', 'מֹשֶׁה', 'Mosheh');
eq('lo (cholam + aleph)', 'לֹא', 'Lo');
eq('elohim (hataf segol)', 'אֱלֹהִים', 'Elohim');
eq('abodat (hataf patach)', 'עֲבוֹדַת', 'Abodat');
eq('bayit (yod with hirik is consonant)', 'בַּיִת', 'Bayit');
eq('en (tsere+yod mater)', 'אֵין', 'En');
eq('hayyom (yod with dagesh = yy, vav-cholam vowel)', 'הַיּוֹם', 'Hayyom');
eq('torah/vav shuruk', 'וְהוּא', 'Vehu');
eq('dabar', 'דָּבָר', 'Dabar');
eq('ani', 'אֲנִי', 'Ani');

// --- shva rules
eq('shva nach after short vowel (dibre)', 'דִּבְרֵי', 'Dibre');
eq('shva nach after short vowel (malkut)', 'מַלְכוּת', 'Malkut');
eq('shva na after long vowel (shomerim)', 'שׁוֹמְרִים', 'Shomerim');
eq('shva na after long vowel (omerim)', 'אוֹמְרִים', 'Omerim');
eq('shva na after shuruk conj (ubekol)', 'וּבְכָל', 'Ubekol');
eq('shva na under dagesh chazak', 'הַמְּעַט', 'Hammeat');
eq('two shvas: first silent, second vocal (yishmeru)', 'יִשְׁמְרוּ', 'Yishmeru');
eq('two shvas at word end are both silent (vayebk)', 'וַיֵּבְךְּ', 'Vayyebk');
eq('identical consonants: halelu', 'הַלְלוּ', 'Halelu');
eq('shva na after dagesh forte + bgdkpt (shette)', 'שְׁתֵּי', 'Shette');
eq('word-initial shva', 'בְּיָדוֹ', 'Beyado');
eq('shva after hirik in verb (yitgabber)', 'יִתְגַּבֵּר', 'Yitgabber');

// --- dagesh qal vs chazak, gemination
eq('dagesh chazak in nun', 'הִנֵּה', 'Hinneh');
eq('dagesh chazak after she- (shebbiktab)', 'שֶׁבִּכְתָב', 'Shebbiktab');
eq('dagesh qal after shva (not doubled)', 'יִתְבָּרֵךְ', 'Yitbarek');
eq('tz doubles as tztz', 'הַצִּבּוּר', 'Hatztzibbur');
eq('shin doubles', 'קְדֻשָּׁה', 'Qedushsha');

// --- qamatz katan vs gadol
eq('kol', 'כָּל', 'Kol');
eq('vechol-ha', 'וְכָל־הָעָם', 'Vekol-haam');
eq('nokhri (noun: katan)', 'הַנָּכְרִי', 'Hannokri');
eq('amru (verb in shuruk: gadol, vocal shva)', 'אָמְרוּ', 'Ameru');
eq('mevarchin (participle: gadol)', 'מְבָרְכִין', 'Mebarekin');
eq('hareshut (article: gadol)', 'הָרְשׁוּת', 'Hareshut');
eq('tzorkei (suffixed noun: katan)', 'צָרְכֵי', 'Tzorke');

// --- patach gnuva, final letters
eq('ruach (furtive patach)', 'רוּחַ', 'Ruach');
eq('shamea (furtive patach on ayin)', 'שָׁמֵעַ', 'Shamea');
eq('melaka (silent aleph, final he)', 'מְלָאכָה', 'Melaka');
eq('final kaf', 'לְךָ', 'Leka');
eq('furtive patach after hirik+yod', 'שְׁלִיחַ', 'Sheliach');
eq('alayv (qamatz + yod + vav)', 'עָלָיו', 'Alayv');
eq('mah (patach + he sounded)', 'מַה', 'Mah');
eq('mitzvot (vav consonant with cholam after shva)', 'מִצְוֹת', 'Mitzvot');

// --- maqaf, punctuation, tags, capitalisation
eq('maqaf -> hyphen', 'עַל־פְּנֵי', 'Al-pene');
eq('b tags kept + punctuation kept', '<b>דִּין:</b> שָׁלוֹם.', '<b>Din:</b> shalom.'); // ':' is not a sentence boundary
eq('sentence capitalisation', 'שָׁלוֹם. שָׁלוֹם', 'Shalom. Shalom');
eq('parentheses/em dash kept', '(שָׁלוֹם) — דָּבָר', '(Shalom) — dabar');

// --- divine name
eq('tetragrammaton', 'יְהֹוָה', 'Adonai');
eq('tetragrammaton with prefix', 'לַיְהֹוָה', 'LaAdonai');
eq('written yud-yud', 'יְיָ', 'Adonai');
eq('he-geresh = Hashem', 'אַתָּה ה\'', 'Atta Hashem');
eq('prefix + he-geresh', "לַה'", 'LaHashem');
eq('numeral he-geresh before sefaim', "וּבוֹ ה' סְעִיפִים", 'Ubo h\' seipim');

// --- abbreviations, numerals, citations, unvocalized words
eq('gershayim numeral', 'י"ט', 'Y"t');
eq('mixed prefix + numeral', 'בְּי"ד', 'Bey"d');
eq('zal abbreviation (vocalized first letter)', 'זַ"ל', 'Za"l');
eq('letter numeral with geresh', "סְעִיף ד'", "Seip d'");
eq('citation with bare letters', '(בְּרֵאשִׁית א׳ א׳)', "(Bereshit a' a')");
eq('vego-geresh abbreviation', "וְגוֹ'", "Vego'");
eq('unvocalized abbreviation vegomer', "וגו'", "Vego'");
eq('prefix vav without nikud', 'ומַפְסִיקִין', 'Umapsiqin');
eq('bracketed single letter', 'דָּבָר [ה]', 'Dabar [h]');

// --- ZWJ vav-cholam as in the data
eq('vav + ZWJ + cholam', 'אַמּו‍ֹת', 'Ammot');

const total = pass + fails.length;
if (fails.length) { console.error(fails.join('\n')); console.error(`\n${fails.length} of ${total} FAILED`); process.exit(1); }
console.log(`all ${total} transliteration tests passed`);
