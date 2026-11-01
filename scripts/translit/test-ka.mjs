#!/usr/bin/env node
// Hand-checked Georgian cases (recommended scheme). node scripts/translit/test-ka.mjs
import { scheme } from './ka.mjs';
import { transliterate, newStats } from './core.mjs';
const T = (s) => transliterate(s, scheme, newStats()).out;
let pass = 0; const fails = [];
const eq = (name, he, exp) => { const got = T(he); if (got === exp) pass++; else fails.push(`${name}: ${he}\n  expected ${exp}\n  got      ${got}`); };

// the 8 reviewed community names
eq('chayei', 'חַיֵּי', 'ხაიე'); eq('sara', 'שָׂרָה', 'სარა');
eq('bereshit', 'בְּרֵאשִׁית', 'ბერეშით'); eq('shemot', 'שְׁמוֹת', 'შემოთ');
eq('vayikra', 'וַיִּקְרָא', 'ვაიკრა'); eq('bemidbar', 'בְּמִדְבַּר', 'ბემიდბარ');
eq('nitzavim', 'נִצָּבִים', 'ნიცავიმ'); eq('chanuka', 'חֲנוּכָּה', 'ხანუქა'); eq('tehilim', 'תְּהִלִּים', 'თეჰილიმ');
// basics
eq('shalom', 'שָׁלוֹם', 'შალომ'); eq('yisrael', 'יִשְׂרָאֵל', 'ისრაელ'); eq('chayim', 'חַיִּים', 'ხაიმ');
eq('tora', 'תּוֹרָה', 'თორა'); eq('mosheh', 'מֹשֶׁה', 'მოშე'); eq('lo', 'לֹא', 'ლო');
eq('elohim', 'אֱלֹהִים', 'ელოჰიმ'); eq('abodat', 'עֲבוֹדַת', 'ყავოდათ'); eq('bayit', 'בַּיִת', 'ბაით');
eq('en', 'אֵין', 'ენ'); eq('hayom', 'הַיּוֹם', 'ჰაიომ'); eq('vehu', 'וְהוּא', 'ვეჰუ'); eq('dabar', 'דָּבָר', 'დავარ');
eq('ani', 'אֲנִי', 'ანი'); eq('shabbat (no doubling)', 'שַׁבָּת', 'შაბათ'); eq('hashem word', 'הַשֵּׁם', 'ჰაშემ');
eq('hashshamayim', 'הַשָּׁמַיִם', 'ჰაშამაიმ');
// letters: kaf/qof/pe/tsadi/tet/tav/chet
eq('baruch (kaf final rafe)', 'בָּרוּךְ', 'ბარუხ'); eq('melech', 'מֶלֶךְ', 'მელეხ'); eq('kol (qamatz katan)', 'כָּל', 'ქოლ');
eq('qol qof', 'קוֹל', 'კოლ'); eq('pinchas', 'פִּנְחָס', 'ფინხას'); eq('mishpatim', 'מִשְׁפָּטִים', 'მიშფატიმ');
eq('tzedaka', 'צְדָקָה', 'ცედაკა'); eq('tzadik final', 'צַדִּיק', 'ცადიკ'); eq('tet', 'טוֹב', 'ტოვ'); eq('tav', 'תִּתֵּן', 'თითენ');
eq('chet', 'חָכְמָה', 'ხოხმა'); eq('samech', 'סִימָן', 'სიმან'); eq('vav consonant', 'וָו', 'ვავ');
// shva
eq('dibre shva nach', 'דִּבְרֵי', 'დივრე'); eq('shomerim', 'שׁוֹמְרִים', 'შომერიმ'); eq('ubekol', 'וּבְכָל', 'უვეხოლ');
eq('malkut', 'מַלְכוּת', 'მალხუთ'); eq('hammeat (shva under dagesh)', 'הַמְּעַט', 'ჰამეყატ');
// divine names, glides, punctuation
eq('adonai', 'יְהֹוָה', 'ადონაი'); eq('adonai2', 'אֲדֹנָי', 'ადონაი');
eq('yy', 'יְיָ', 'ადონაი'); eq('hashem', "ה'", 'ჰაშემ'); eq('alav (ָיו)', 'עָלָיו', 'ყალავ'); eq('elay', 'אֵלַי', 'ელაი');
eq('goy cholam+yod', 'גּוֹי', 'გოი'); eq('maqaf', 'עַל־כֵּן', 'ყალ-ქენ'); eq('final he sounded mappiq', 'אוֹתָהּ', 'ოთაჰ');
eq('hallelu (identical letters)', 'הַלְלוּ', 'ჰალელუ'); eq('yitzchak', 'יִצְחָק', 'იცხაკ'); eq('yaakov', 'יַעֲקֹב', 'იაყაკოვ');
eq('markup kept', '<b>שָׁלוֹם</b>', '<b>შალომ</b>');
eq('sof pasuk punct', 'שָׁלוֹם:', 'შალომ:');
console.log(`${pass} passed, ${fails.length} failed`);
if (fails.length) { console.log(fails.join('\n')); process.exit(1); }
