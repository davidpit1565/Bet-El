# מדריך הגשה לאפסטור – "תמיד" גרסה 2.0 (build 6)

הכל כאן מוכן: טקסטים בחמש שפות (`LISTING.md`), צילומי מסך מוכנים בכל הגדלים (`screenshots/`), הערות לבודק ו"מה חדש" (`../release-update-checklist.md` סעיף 3). המדריך הזה אומר **מה לעשות, בסדר, בלי לדלג**.

---

## שלב 0 – לפני שנוגעים באפסטור (חובה)
1. **בדיקה על המכשיר** של בילד 6 (ה-prompt של Claude Code מתקין אותו). עוברים על הרשימה ב-`release-update-checklist.md` סעיף 1. לא ממשיכים אם משהו קורס. מה שחשוב במיוחד: וידג'טים בגלריה, כותרת שנעלמת בגלילה, ה-QR, קישור התרומה (חלון Safari פנימי), שליחת דיווח והצעות.
2. **מיזוג PR #221 ל-main** (רק אחרי שהכל עובד במכשיר). הסיבה: ה-Privacy Policy וה-Support שאפל בודקת נמצאים ב-GitHub Pages, ורק המיזוג מעלה את הגרסה המעודכנת (מצלמה, מיקום, משוב). בדוק אחרי כמה דקות שהקישור https://davidpit1565.github.io/Bet-El/privacy.html מציג את הנוסח החדש. כתוב לי "תמזג" ואעשה את זה.
3. **כללי Firestore** לדיווח והצעות – ה-prompt של Claude Code עושה את זה. בדוק ששליחה אחת מהאפליקציה מצליחה ("ההודעה נשלחה, תודה!"). בלי זה הטופס יציג כשל.
4. **צילומי מסך מהמכשיר** (ראו שלב 3) – 5 דקות, שווה את זה.

## שלב 1 – ארכיב והעלאה (על המק)
1. Xcode ← פותחים `ios/App/App.xcworkspace` (לא `.xcodeproj`).
2. למעלה בוחרים יעד **Any iOS Device (arm64)**.
3. ודא ב-Signing & Capabilities, לשני ה-Targets (App ו-BetElWidget): אותו Team, **App Groups** מופעל עם `group.com.beitel.tehilim`, ו-Push Notifications + Live Activities באפליקציה.
4. ודא Version **2.0** ו-Build **6** (ב-General). הבילד חייב להיות מספר שלא הועלה אף פעם.
5. **Product ← Archive**. כשנגמר נפתח Organizer.
6. **Validate App** (בודק בעיות לפני שליחה) ואז **Distribute App ← App Store Connect ← Upload** (השאר ברירות מחדל: Upload symbols, automatic signing).
7. אחרי ~10–30 דקות מגיע מייל "processing complete" והבילד מופיע ב-App Store Connect ← TestFlight.
8. ב-Organizer אפשר לבחור **Generate Privacy Report** ולוודא שאין התראות חדשות.
> חובה: בנייה עם Xcode 26 / iOS 26 SDK (אפל דורשת זאת להעלאות חדשות). אם Validate מתלונן על משהו – שלח לי את ההודעה.

## שלב 2 – TestFlight (מומלץ מאוד, 15 דקות)
App Store Connect ← TestFlight ← הבילד ← **Internal Testing** ← מוסיפים את עצמך. מתקינים מ-TestFlight על האייפון ובודקים שוב את הדברים הקריטיים (וידג'טים, ה-QR, מיקום, קישורים). זה בדיוק הקוד שעומד לעלות.

## שלב 3 – צילומי מסך
- בתיקייה `docs/appstore/screenshots/` יש לכל שפה (he/en/fr/ru/ka) שתי תיקיות:
  - `iphone-6.9/` – **1320×2868** (iPhone 6.9"). מספיק גודל אחד לאייפון, אפל מקטינה לשאר.
  - `ipad-13/` – **2064×2752** (iPad 13"). **נדרש כי האפליקציה תומכת באייפד** (`TARGETED_DEVICE_FAMILY=1,2`).
- מעלים בסדר המספרים 01 → 08 (עד 10 מותר). הראשון הוא מה שרואים בחיפוש, ולכן "כל הלימוד היומי במקום אחד".
- **שני מסכים שאפל מצפה לראות וחסרים כי אי אפשר לצלם אותם כאן – צלם מהאייפון:**
  1. **מסך הבית האמיתי** (עם הזכוכית הנייטיב) – בית בערכה כהה, גלילה לראש.
  2. **ווידג'טים** – מסך בית עם ווידג'ט תאריך/זמנים, ומסך נעילה עם ווידג'טים.
  איך: לחץ Side+Volume Up לצילום. העבר למק ב-AirDrop. תן שמות: `he-01-home.png`, `he-09-widgets.png` והכנס לתיקייה `docs/appstore/raw-device/`. אחרי זה הרץ `node scripts/appstore-compose.mjs he` (או בקש מ-Claude Code) והצילומים החדשים יחליפו את הישנים עם כיתוב.
- כללי אפל: הצילום חייב להראות את האפליקציה בפועל (לא פרסומת). הכיתובים והמסגרת בסדר.

## שלב 4 – הגרסה ב-App Store Connect
My Apps ← **תמיד** ← **+** ליד iOS App ← **2.0**.

1. **Screenshots** – מעלים לכל שפה לפי שלב 3.
2. **Promotional Text, Description, Keywords, Subtitle, Name** – מ-`LISTING.md`, לכל שפה (Localizations: Hebrew, English, French, Russian, Georgian – מוסיפים שפה דרך "+" ליד שם השפה).
3. **What's New** – מ-`release-update-checklist.md` סעיף 3.
4. **Support URL / Marketing URL / Privacy Policy URL** – מ-`LISTING.md` (בראש הקובץ).
5. **Build** – בוחרים את build 6.
6. **App Review Information** – אין התחברות (No sign-in required). דוא"ל וטלפון ליצירת קשר. **Notes** – מדביקים את "Review Notes" מהמסמך.
7. **Version Release** – מומלץ **Manually release** (לשחרר בעצמך אחרי האישור) או **Phased Release for Automatic Updates** (הפצה הדרגתית 7 ימים – הכי בטוח כי הקוד לא קומפל כל כך הרבה זמן).

### App Privacy (כרטיס "App Privacy" ← Edit)
השווה למה שכבר מוגדר ועדכן. התשובות המומלצות לפי הקוד הנוכחי:
| סוג נתון | מה אוסף | מטרה | מקושר למשתמש | מעקב |
|---|---|---|---|---|
| Contact Info – Name | טופס דיווח והצעות (רק אם המשתמש שולח; אין שדה אימייל) | App Functionality | כן | לא |
| User Content – Other User Content | תוכן ההודעה | App Functionality | כן | לא |
| Identifiers – Device ID | טוקן Push (Firebase) + מזהה של Firebase Analytics | App Functionality, Analytics | לא | לא |
| Usage Data – Product Interaction | Firebase Analytics | Analytics | לא | לא |
| Location | המיקום **נשאר על המכשיר** ואינו נשלח → "Not collected" | – | – | – |
**Tracking: No.** אם אתה לא בטוח בנקודה כלשהי – תגיד לי ואבדוק מול הקוד.

### Age Rating
כל התשובות "None/No" ← 4+. אין תוכן גולש חופשי, אין הימורים, אין תוכן מבוגרים.

### Export Compliance
האפליקציה מגדירה `ITSAppUsesNonExemptEncryption=false` – ב-App Store Connect פשוט עונים "No" אם נשאלים.

### Category
Primary: **Reference** (או Education), Secondary: Lifestyle.

## שלב 5 – שליחה לבדיקה
1. **Add for Review** ← **Submit to App Review**.
2. בדיקה לוקחת בדרך כלל 24–48 שעות. מייל עם כל שינוי סטטוס.
3. אם **נדחה**: קוראים את הסיבה ב-Resolution Center. הסיבות הסבירות והמענה:
   - **קישור תרומה** (Guideline 3.2.1): הקישור מוביל לאתר הקהילה ללא תשלום באפליקציה. כבר מוסבר בהערות לבודק. אם מבקשים – אפשר להסתיר את השורה בגרסה הבאה.
   - **מדיניות פרטיות לא מתאימה**: לכן שלב 0.2 קריטי.
   - **קריסה**: הבילד נבדק ב-TestFlight לפני.
4. **אחרי האישור:** משחררים (או שמשתחרר אוטומטית). שולחים קמפיין הודעה ב-Firebase על התוכן החדש: https://console.firebase.google.com/project/bet-el-e6812/messaging
5. מעקב: Xcode ← Organizer ← Crashes, ו-App Store Connect ← Analytics. אם יש קריסות – שלח לי.

## מה אני לא יכול לעשות מכאן
- להיכנס ל-App Store Connect, להעלות, או ללחוץ "Submit" – רק אתה.
- לצלם את מסך הבית הנייטיב והווידג'טים (שלב 3).
- לאמת שהנוסח של ברכה מעין שלוש וברכות הנהנין נכון להלכה – **רב צריך לעבור על זה לפני שהגרסה יוצאת**, או שמסירים אותן מרשימת הברכות בגרסה הזו.
