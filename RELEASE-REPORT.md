# דוח שחרור גרסה 2.0 (build 6), Bet-El / תמיד

עודכן: 2026-10-10, ענף `claude/release-2-0-device`.
כל העבודה נעשתה לפי ההרשאה שנתת (שלבים 1-8).
**לא** נלחץ Submit for Review.
**לא** נשלחה שום התראה או קמפיין Firebase.
מפתח ה-ASC ו-`DEVELOPMENT_TEAM` לא הודפסו ולא נכנסו ל-git. ה-Team הועבר רק בשורת הפקודה של xcodebuild.
ה-stash-ים לא נגעו.

---

## 1. מיזוגים
- לתוך `claude/release-2-0-device` מוזגו:
  - `origin/main`
  - `claude/ios-search-appstore` (PR #225, טאב החיפוש)
  - `claude/dev-visits-fix` (PR #227, ספירת משתמשי App Store)
- בלי קונפליקטים.
- לפני הדחיפה: `git fetch origin main && git merge origin/main`, והענף כבר היה עדכני.
- PR #226 סומן ready. PR #225, #227 ו-#226 מוזגו ל-`main` עם merge commit, אחרי שכל הבדיקות עברו (ראו סעיף 9).

## 2. בנייה וסימולטור
- `npm run cap:sync` ובניית סימולטור הצליחו.
- **הערה:** על המחשב מותקנים רק Xcode 27 / iOS 27 SDK. גם build 6 שהועלה נבנה איתם. Apple מקבלת את זה, ו-`docs/release-update-checklist.md` עודכן בהתאם.

## 3. בדיקת החיפוש (he/en + `__BETEL_DEV_BUILD`)
- נבדקו בעברית ובאנגלית:
  - הצעות וחיפושים אחרונים
  - תוצאות חיות
  - פתיחת תוצאה
  - טאב החיפוש נשאר מסומן
- `__BETEL_DEV_BUILD` מוזרק בבניית Xcode/סימולטור, ולכן ביקור, נוכחות ו-Analytics מדולגים כמצופה.
- **באג שתוקן:** "חזרה" מתוצאה חיפוש לא חזרה למסך החיפוש. היא חוזרת אליו עכשיו.

## 4. Firestore
`stats/visits.count` הורד מ-470 ל-415, כפי שביקשת.

## 5. תיקונים נוספים ב-`index.html`
- **שורת הסטטוס** עוקבת אחרי ערכת הנושא בתוך האפליקציה (`StatusBar.setStyle` ב-`applySettings`). במצב בהיר הטקסט כבר לא לבן על לבן.
- **כותרת "-" באנגלית/צרפתית/רוסית/גאורגית:** מפתח המקף העברי (`'־':'-'`) חזר למילוני ה-I18N. בלעדיו הופיע "-" ככותרת במסך הבית ובלוח השנה.
- **צילומי "חק לישראל" בשבת** מוצגים עכשיו עם תוכן (fallback ליום חול).

## 6. צילומי מסך וסליידים
- **צילומים גולמיים מהסימולטור:**
  - iPhone 17 Pro Max (6.9") ו-iPad Pro 13"
  - he/en, כהה ובהיר
  - 9 מסכים: בית, חק לישראל, לוח שנה, תהילים, תפילות, ברכת המזון, חיפוש, הגדרות, ספרייה
  - נשמרים מקומית בלבד (כ-213MB, ב-`.gitignore`): `docs/appstore/raw-device{,-light}{,-ipad}/`
- **סליידים בסגנון Kosher Switch** (מסגרת מכשיר, כרטיסי זום, 10 לכל סט):
  - כהה: `docs/appstore/slides/<he|en>/<iphone-6.9|ipad-13>/01-hero.png … 10-set.png`
  - בהיר: `docs/appstore/slides-light/<he|en>/…`, באותו מבנה
- **תיקונים ב-`scripts/appstore-slides.mjs`:**
  - איתור הצילומים הבהירים
  - כרטיסי הזום כבר לא חותכים שורות, וב-iPad הזום מוגדל ומיושר לתחילת השורה
  - כותרות המשנה של מסך החיפוש
- כל הסליידים נבדקו בעין.
- הסליידים של fr/ru ישנים ולא עודכנו. אין להם צילומים חדשים.

## 7. App Store Connect (fastlane)
- **קבצים חדשים בריפו:**
  - `fastlane/Fastfile`, `Appfile`, `ExportOptions.plist`
  - `fastlane/metadata/` (נוצר ע"י `node scripts/fastlane-metadata.mjs` מ-`LISTING.md` ומה-What's New ב-checklist)
- **build 6** (גרסה 2.0) נבנה כ-archive, יוצא כ-IPA, הועלה ועבר processing.
- **מטא-דאטה** הועלתה ל-4 שפות: he, en-US, fr-FR, ru. כוללת שם, תת-כותרת, תיאור, מילות מפתח, טקסט קידום, What's New וכתובות.
- **צילומי מסך** הועלו ל-he ול-en-US: 10 ל-iPhone ו-10 ל-iPad בכל שפה (הסליידים הכהים).
- **build 6 נבחר** לגרסה 2.0 (lane `select_build`).
- **לא נשלח לבדיקה.**
- **פקודות להרצה חוזרת** (דורשות `ASC_KEY_ID`/`ASC_ISSUER_ID`/`ASC_KEY_PATH` בסביבה):
  ```
  node scripts/fastlane-metadata.mjs
  fastlane ios upload_build ipa:build/export/App.ipa
  fastlane ios upload_listing
  fastlane ios select_build
  ```

## 8. תצפיות (לא חוסמות, לשיקולך)
- באנגלית כותרת הקורא של ברכת המזון נחתכת ("Birkat Hama…").
- שדה החיפוש מופיע מעל דפי התוצאה שנפתחו מהחיפוש.
- החיפוש מחפש רק בכותרות, לא בתוך הטקסט.
- תפילות באנגלית מוצגות בתעתיק (לפי התכנון), לא בתרגום.
- באנגלית, ה-placeholder של חיפוש בתהילים עדיין בעברית.
- בצילומי ה-iPad שורת הסטטוס מציגה "Sat 10 Oct" לצד "תמיד". זה מגיע מהסימולטור.

## 9. בדיקות לפני הדחיפה
כולן עברו:
- `node --check` על כל 10 בלוקי ה-script
- `check-blocking-resources`
- `cap:sync`
- `test:sweep` (0 שגיאות)
- אין `BETEL_DEBUG` ואין `43DB56398H` בדיף

---

## 10. מה נשאר לך
1. **App Privacy** ב-App Store Connect (הפירוט ב-`docs/appstore/GUIDE.md`).
2. **Age Rating** ו-**Export Compliance** (אם ASC שואל על build 6).
3. **צילומי widgets ו-Lock Screen** ממכשיר אמיתי, אם רוצים אותם בחנות. סימולטור לא מצלם אותם.
4. **הגהה של רב** לברכת מעין שלוש וברכות הנהנין (נוסח עדות המזרח).
5. **צילומים ל-fr/ru** (כרגע יש להם רק טקסטים), אם רוצים.
6. **ללחוץ Submit for Review** בעצמך, כשהכול נראה טוב.
7. אחרי האישור: לשקול קמפיין הכרזה ב-Firebase. לא נשלח כלום.

## נספח: קבצים מקומיים שלא נכנסו ל-git
- `docs/appstore/raw-device*/`: צילומים גולמיים
- `build/`: archive ו-IPA
- `fastlane/screenshots/`: עותק של הסליידים
- `scratchpad/`, `scroll-shots-v3/`: תוצרי עבודה. אפשר למחוק.
- `ios/App/App.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/`: נוצר אוטומטית ע"י Xcode
