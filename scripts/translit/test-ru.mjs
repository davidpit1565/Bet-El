#!/usr/bin/env node
// Hand-checked unit tests for the Hebrew -> Russian (Cyrillic) transliterator, dialect A of spec-ru.json.
//   node scripts/translit/test-ru.mjs
import { scheme } from './ru.mjs';
import { transliterate, newStats } from './core.mjs';

const T = (s) => transliterate(s, scheme, newStats()).out;
let pass = 0; const fails = [];
function eq(name, he, expected) {
  const got = T(he);
  if (got === expected) pass++; else fails.push(`${name}: ${he}\n   expected: ${expected}\n   got:      ${got}`);
}

// --- basics
eq('shalom', 'שָׁלוֹם', 'Шалом');
eq('bereshit (dagesh qal, shva na, tsere+yod)', 'בְּרֵאשִׁית', 'Берешит');
eq('hashshamayim (dagesh chazak)', 'הַשָּׁמַיִם', 'Гашшамайим');
eq('vayhi (shva nach)', 'וַיְהִי', 'Вайги');
eq('yisrael (sin = с, silent aleph)', 'יִשְׂרָאֵל', 'Йисраел');
eq('tora (silent final he)', 'תּוֹרָה', 'Тора');
eq('moshe', 'מֹשֶׁה', 'Моше');
eq('lo', 'לֹא', 'Ло');
eq('elohim (hataf segol, he = г)', 'אֱלֹהִים', 'Елогим');
eq('avodat (ayin silent, hataf patach)', 'עֲבוֹדַת', 'Аводат');
eq('bayit (yod consonant)', 'בַּיִת', 'Байит');
eq('hayom', 'הַיּוֹם', 'Гаййом');
eq('vehu (vav shuruk)', 'וְהוּא', 'Вегу');
eq('ani', 'אֲנִי', 'Ани');
// --- fricatives / special letters
eq('shabbat (bet dagesh chazak)', 'שַׁבָּת', 'Шаббат');
eq('baruch (khaf final = х)', 'בָּרוּךְ', 'Барух');
eq('kol (qamatz katan)', 'כָּל', 'Кол');
eq('tzaddik (tsadi doubled)', 'צַדִּיק', 'Цаддик');
eq('hayyim (yod gem)', 'חַיִּים', 'Хаййим');
eq('mitzvot (vav consonant)', 'מִצְוֹת', 'Мицвот');
eq('qof and pe rafe', 'קָפַץ', 'Кафац');
eq('aleph/ayin hiatus unmarked', 'יַעֲקֹב', 'Йааков');
// --- diphthongs / vowel letters
eq('alav (ָיו = ав)', 'עָלָיו', 'Алав');
eq('panav', 'פָּנָיו', 'Панав');
eq('adonai (real word, lower case)', 'אֲדֹנָי', 'Адонай');
eq('chay (patach+yod = ай)', 'חַי', 'Хай');
eq('goy (cholam+yod = ой)', 'גּוֹי', 'Гой');
eq('beyadam (yod+shva-na)', 'בְּיָדָם', 'Бейадам');
eq('shuruk word', 'אוּלָם', 'Улам');
eq('chirik male + final mem', 'דִּבְרֵי', 'Дивре');
// --- furtive patach / mappiq
eq('ruach (furtive before chet)', 'רוּחַ', 'Руах');
eq('noach', 'נֹחַ', 'Ноах');
eq('yodea (furtive ayin)', 'יוֹדֵעַ', 'Йодеа');
eq('lah mappiq he = г', 'לָהּ', 'Лаг');
eq('hamizbeach (dagesh qal after shva... furtive)', 'הַמִּזְבֵּחַ', 'Гаммизбеах');
// --- shva
eq('shva nach after qamatz (data: гайта)', 'וְהָיְתָה', 'Вегайта');
eq('shva nach after short vowel', 'מַלְכוּת', 'Малхут');
eq('shva na after shuruk', 'וּבְכָל', 'Увехол');
eq('two shvas mid-word: 2nd vocal', 'יִשְׁרְצוּ', 'Йишрецу');
eq('shva under dagesh chazak', 'הַמְּעַט', 'Гаммеат');
eq('word-final kaf shva', 'לְךָ', 'Леха');
eq('kedma', 'קֵדְמָה', 'Кедма');
eq('aramaic alma (aleph-final qamatz)', 'בְּעָלְמָא', 'Беалма');
// --- punctuation, maqaf, capitals, names
eq('maqaf', 'עַל־פְּנֵי', 'Ал-пене');
eq('capital only at unit start', 'וַיֹּאמֶר אֱלֹהִים', 'Ваййомер елогим');
eq('tetragrammaton mid-sentence capital', 'וַיֹּאמֶר יְהֹוָה', 'Ваййомер Адонай');
eq('yod yod = Адонай', 'לַיְיָ', 'Лаадонай');
eq('prefixed ה\' = лаадонай', 'לַה\' אֶחָד', 'Лаадонай ехад');
eq('ה\' name', 'נְאֻם ה\'', 'Неум Адонай');
eq('ה\' numeral before плural noun', 'סְעִיפִים ה\' קֻפּוֹת', 'Сеифим г\' куппот');
eq('bold markers kept', '<b>דִּין הַבֹּקֶר:</b> וְאָמַר', '<b>Дин габбокер:</b> веамар');
eq('vegomer', 'וְגוֹ\'', 'Вегомер');
eq('abbreviation with quotes kept', 'י"ט סְעִיפִים', 'Й"т сеифим');
eq('niggun gem after shva-na not doubled', 'שְׁתֵּי', 'Шете');
eq('vav consonant with vowel', 'וָו', 'Вав');
eq('hatuf-qamatz = о', 'אֳנִיָּה', 'Ониййа');

if (fails.length) { console.log(fails.join('\n')); console.log(`\n${pass} passed, ${fails.length} FAILED`); process.exit(1); }
console.log(`ru: ${pass} passed`);
