# עדכון גדול לאפסטור – רשימת בדיקה מלאה

> נכתב אחרי סבב העבודה של אוקטובר 2026. קוד ה-Swift (ווידג'טים, כפתורי זכוכית נייטיב, Live Activity, כותרת, סרגל תחתון) **לא קומפל ולא נבדק ב-Xcode עדיין** - זה השלב הראשון.

## 0. גרסה
- היום: **1.3 (build 4)**. עדכון כזה עדיף **2.0 (build 5)** - שינוי עיצוב משמעותי, ווידג'טים חדשים, שפות.
- לשנות ב-`ios/App/App.xcodeproj/project.pbxproj` ב-**4 מקומות** כל אחד (`MARKETING_VERSION` ו-`CURRENT_PROJECT_VERSION`): Debug+Release של האפליקציה **וגם** של ה-Widget Extension. הרחבה חייבת להיות זהה לאפליקציה (עד עכשיו היא הייתה 1.0/1 - יישרתי אותה ל-1.3/4 כדי שלא תיפול בולידציה).

## 1. לפני העלאה (על המק)
1. `git pull origin main` (או הענף), `npm run cap:sync`.
2. Xcode: Clean (⇧⌘K) → Run על אייפון אמיתי, **למחוק את האפליקציה קודם**.
3. לבדוק שבונה ללא שגיאות (במיוחד: `NativeHomeEdit.swift`, וידג'טים, `NativeLiveActivityBridge`).
4. בדיקות מהירות על המכשיר:
   - דף הבית: לחיצה ארוכה → מצב עריכה (מינוס/גודל/+/✓ זכוכית), גרירה, מחיקה, הוספה, איפוס.
   - רשתות חברתיות וזיכרון נשמת לא ניתנים למחיקה.
   - "מונה משתמשים" ו"מחוברים כעת" כבלוקים נפרדים (קטן/ארוך).
   - הגדרות בכל 5 השפות (אין עברית שנשארה).
   - דיווח והצעות: שליחה (ראו סעיף 4 - השרת).
   - ווידג'טים: הוספה של כל סוג, מעבר בהיר/כהה במערכת, לחיצה פותחת את המקום הנכון (`betel://`).
   - מסך נעילה: תאריך, תהילים, רצף, זמן הבא, נרות, עד השקיעה, עומר.
   - StandBy: וידג'ט "תאריך גדול".
   - מצלמה (מראה לתפילין) - הרשאה ועבודה.
   - התקנה מחדש נקייה + שדרוג מגרסה קודמת (שהנתונים נשמרים).
5. Product → Archive → Distribute → App Store Connect.

## 2. דברים שחייבים לעדכן ב-App Store Connect
- **App Privacy (תוויות פרטיות):** נוסף איסוף של **שם, אימייל, תוכן משתמש** (טופס משוב) - "Contact Info" + "User Content", לא למעקב, לא לפרסום. נוספה גם עבודה עם מצלמה (בלי איסוף) ומיקום (על המכשיר). אם בעבר סומן "לא נאסף מידע" - צריך לשנות.
- **מדיניות פרטיות:** `privacy.html` עודכן בכל 5 השפות (משוב, מצלמה, מיקום). **חייב להיות מפורסם בכתובת שמוזנת ב-App Store Connect לפני שליחה לבדיקה** (ראו סעיף 5 על Vercel).
- **צילומי מסך** חדשים (העיצוב השתנה): 6.9" (iPhone 16/17 Pro Max) ו-6.5"; כדאי להוסיף צילום של ווידג'טים ושל מסך הבית המותאם.
- **תיאור / מה חדש** - ראו סעיף 3.
- **Review Notes** (הערות לבודק) - ראו סעיף 3.

## 3. טקסטים

### מה חדש (What's New)
**עברית**
```
עדכון גדול:
• מסך בית שמתאימים אישית – לחיצה ארוכה: גרירה, שינוי גודל, הוספה והסרה של כפתורים
• ווידג'טים חדשים למסך הבית, למסך הנעילה ול-StandBy: תאריך עברי ופרשה, זמני היום המדויקים, תהילים, נרות שבת ויום טוב, ספירת העומר, עד השקיעה
• עיצוב חדש בליקוויד גלס (iOS 26): סרגל תחתון, כותרת, חיפוש ופקדים
• הגדרות מתורגמות במלואן: עברית, אנגלית, צרפתית, רוסית וגאורגית
• מראה לתפילין עם זיהוי מדויק של מקום הנחת הבית
• דיווח והצעות לשיפור – ישירות מהאפליקציה
• מסך פתיחה חדש ושיפורי יציבות
```
**English**
```
Major update:
• Customize your home screen – long-press to drag, resize, add and remove buttons
• New widgets for the Home Screen, Lock Screen and StandBy: Hebrew date and parasha, exact daily times, Tehillim, Shabbat & Yom Tov candle lighting, Sefirat HaOmer, time until sunset
• New Liquid Glass design (iOS 26): tab bar, header, search and controls
• Fully translated Settings: Hebrew, English, French, Russian and Georgian
• Tefillin mirror with precise placement guidance
• Send feedback and suggestions right from the app
• New launch screen and stability improvements
```
**Français**
```
Mise à jour majeure :
• Écran d’accueil personnalisable – appui long pour déplacer, redimensionner, ajouter et retirer des boutons
• Nouveaux widgets (écran d’accueil, écran verrouillé, StandBy) : date hébraïque et paracha, horaires exacts, Tehilim, bougies de Chabbat et Yom Tov, Omer, temps jusqu’au coucher du soleil
• Nouveau design Liquid Glass (iOS 26)
• Réglages entièrement traduits : hébreu, anglais, français, russe, géorgien
• Miroir pour téfilin avec placement précis
• Envoyez vos remarques directement depuis l’app
```
**Русский**
```
Большое обновление:
• Настраиваемый главный экран – долгое нажатие: перетаскивать, менять размер, добавлять и убирать кнопки
• Новые виджеты (главный экран, экран блокировки, StandBy): еврейская дата и недельная глава, точные времена, Теилим, свечи Шаббата и Йом-Това, счёт Омера, время до заката
• Новый дизайн Liquid Glass (iOS 26)
• Настройки полностью переведены: иврит, английский, французский, русский, грузинский
• Зеркало для тфилин с точным указанием места
• Отправка отзывов прямо из приложения
```
**ქართული**
```
დიდი განახლება:
• მორგებადი მთავარი ეკრანი – ხანგრძლივი დაჭერა: გადაადგილება, ზომის შეცვლა, ღილაკების დამატება და ამოღება
• ახალი ვიჯეტები (მთავარი ეკრანი, ჩაკეტილი ეკრანი, StandBy): ებრაული თარიღი და ყოველკვირეული თავი, ზუსტი დროები, თეილიმი, შაბათისა და იომ ტოვის სანთლები, ომერი, დრო მზის ჩასვლამდე
• ახალი Liquid Glass დიზაინი (iOS 26)
• მთლიანად ნათარგმნი პარამეტრები: ებრაული, ინგლისური, ფრანგული, რუსული, ქართული
• თეფილინის სარკე ზუსტი მითითებით
• გამოხმაურების გაგზავნა პირდაპირ აპიდან
```

### Review Notes (למבקר של אפל)
```
No login or account is required. The app is a daily Torah-study companion.
Location (when in use) calculates daily prayer times and the compass; it stays on device.
Camera is used only by the optional "Tefillin mirror" screen; processed on device, nothing is saved or sent.
Widgets (Home Screen, Lock Screen, StandBy) and a Live Activity (countdown to sunrise/sunset) read a small App Group snapshot written by the app.
Optional push notifications ("New content") use Firebase Cloud Messaging.
Feedback form: name/email/subject/message are sent to the developer only to answer the user.
The app loads its static study texts from https://davidpit1565.github.io/Bet-El/ (GitHub Pages).
Built with Xcode 26 / iOS 26 SDK; Liquid Glass APIs have fallbacks on earlier iOS (deployment target 15).
```

## 4. דברים שפתוחים אצלך (לא קשורים לקוד)
- **דיווח והצעות – השרת:** הפונקציה `sendFeedback` ב-Firebase **לא פרוסה** (נותנת 404). עד שתפרוס (`firebase deploy --only functions` + מפתח Resend + דומיין מאומת) הטופס שומר ל-Firestore באוסף `feedback`, וזה עובד רק אם ה-rules מרשים יצירה. **בלי אחד משני אלה הדיווחים לא יגיעו אליך** (המשתמש יראה הודעת שגיאה עם העתק/שיתוף/מייל).
- **Firebase Cloud Messaging:** אחרי שחרור – כדאי קמפיין הודעה על התוכן החדש: https://console.firebase.google.com/project/bet-el-e6812/messaging
- **Privacy manifest:** אין `PrivacyInfo.xcprivacy` בפרויקט. האפליקציה וההרחבה משתמשות ב-`UserDefaults` (App Group) - אפל דורשת הצהרת "Required Reason API" (CA92.1). אם בהעלאה תקבל מייל/אזהרה `ITMS-91053` – להוסיף קובץ כזה ב-Xcode לשני היעדים (אפשר לבקש ממני להכין).
- **Signing:** ה-App Group `group.com.beitel.tehilim` חייב להיות מופעל גם ב-App ID של האפליקציה וגם של `com.beitel.tehilim.widget`. לבדוק ב-Signing & Capabilities. ה-Live Activities (`NSSupportsLiveActivities`) כבר ב-Info.plist.
- **סכמת URL:** נוספה `betel://` ל-Info.plist (לחיצה על וידג'ט פותחת את האפליקציה במקום הנכון).

## 5. Vercel חסום – האם זה פוגע?
- **אפליקציית האייפון לא תלויה ב-Vercel.** קבצי הלימוד נטענים מ-GitHub Pages (`davidpit1565.github.io/Bet-El/`), והאפליקציה עצמה ארוזה בבינארי.
- Vercel משמש רק (א) לגרסת הרשת/PWA ולאנליטיקס שלה (`/_vercel/*` - נטענים `defer`, ואם נכשלים לא קורה כלום) ו-(ב) כאחסון אפשרי ל-`privacy.html`/`support.html`.
- **מה כן לבדוק:** שכתובות ה-Privacy Policy וה-Support שמוזנות ב-App Store Connect **נגישות** (פותחים אותן בדפדפן). אם הן על Vercel – להעביר ל-GitHub Pages (`https://davidpit1565.github.io/Bet-El/privacy.html`) לפני ההגשה, כדי שאפל לא תיתקל בדף שלא נטען.
- **GitHub Pages מתפרסם מ-main** בכל מיזוג (`.github/workflows/pages.yml`). לכן מומלץ למזג ל-main **רק אחרי** שבדקת ב-Xcode, כי המיזוג מעדכן מיד גם את האתר החי ואת הנתונים שאפליקציה המותקנת טוענת.

## 6. סיכום מה השתנה מאז הגרסה החיה (לתיאור/הערות)
מסך בית מותאם (עריכה כמו באייפון) · בלוקים נפרדים למשתמשים/מחוברים · רשתות חברתיות ו"לעילוי נשמת" קבועים · מסך פתיחה מונפש · ליקוויד גלס נייטיב (טאב-בר, כותרת, חיפוש, בורר, כפתורי עריכה) · ווידג'טים: תאריך, זמנים מדויקים, תהילים, רצף, נרות, StandBy, מסך נעילה (תאריך+פרשה, תהילים, רצף, זמן הבא, נרות, עד השקיעה, עומר), Live Activity · תרגומי הגדרות ב-5 שפות · טופס דיווח (אימייל, שם, נושא, הודעה) · מראה תפילין עם זיהוי שיער · זמני היום: עלות השחר לפי הלוח, בלי זמנים שלא הוגדרו · שיתוף פרטי היום המלאים · דגל "מכשיר פיתוח" לא סופר משתמשים ב-Firebase.
