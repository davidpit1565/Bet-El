# עדכון גדול לאפסטור – רשימת בדיקה מלאה

> **מדריך הגשה צעד-צעד, טקסטים בחמש שפות וצילומי מסך מוכנים:** `docs/appstore/` (`GUIDE.md`, `LISTING.md`, `screenshots/`). לבנות מחדש צילומי מסך: `node scripts/appstore-capture.mjs` ואז `node scripts/appstore-compose.mjs`.

> נכתב אחרי סבב העבודה של אוקטובר 2026. קוד ה-Swift (ווידג'טים, כפתורי זכוכית נייטיב, Live Activity, כותרת, סרגל תחתון) **לא קומפל ולא נבדק ב-Xcode עדיין** - זה השלב הראשון.

## 0. גרסה
- **עודכן ל-2.0 (build 6)** בכל 4 המקומות (אפליקציה + Widget Extension). אם בכל זאת רוצים 1.x – לשנות ב-`project.pbxproj`; ה-build חייב להיות מספר שעוד לא הועלה ל-App Store Connect.
- לשנות ב-`ios/App/App.xcodeproj/project.pbxproj` ב-**4 מקומות** כל אחד (`MARKETING_VERSION` ו-`CURRENT_PROJECT_VERSION`): Debug+Release של האפליקציה **וגם** של ה-Widget Extension. הרחבה חייבת להיות זהה לאפליקציה (עד עכשיו היא הייתה 1.0/1 - יישרתי אותה ל-1.3/4 כדי שלא תיפול בולידציה).

## 1. לפני העלאה (על המק)
1. `git pull origin main` (או הענף), `npm run cap:sync`.
2. Xcode: Clean (⇧⌘K) → Run על אייפון אמיתי, **למחוק את האפליקציה קודם**.
3. לבדוק שבונה ללא שגיאות (במיוחד: `NativeHomeEdit.swift`, וידג'טים, `NativeLiveActivityBridge`).
4. בדיקות מהירות על המכשיר:
   - דף הבית: **התאמה אישית כבויה** (`HOME_CUSTOMIZE=false`) - אין לחיצה ארוכה/עריכה. לוודא שהבית (נייטיב, כרטיסי זכוכית) נראה נכון, ש"משתמשים" ו"מחוברים כעת" זה לצד זה, וכל כרטיס פותח את המקום הנכון.
   - מסכי הרשימות (תפילות, הגדרות, ספרייה ותתי-רשימות): נייטיב דרך `nativeScreenSpec`; לבדוק שכל שורה פותחת את המסך הנכון, שחיפוש מציג תוצאות (HTML) וחוזר לרשימה כשמנקים.
   - "מונה משתמשים" ו"מחוברים כעת" מתעדכנים (המספרים מגיעים מ-Firebase).
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
• ווידג'טים חדשים למסך הבית, למסך הנעילה ול-StandBy: תאריך עברי ופרשה, זמני היום המדויקים, תהילים, נרות שבת ויום טוב, ספירת העומר, עד השקיעה
• עיצוב חדש בליקוויד גלס (iOS 26): סרגל תחתון, כותרת, חיפוש ופקדים
• טאב חיפוש חדש: פרק, תפילה או ספר בכל הספרייה
• הגדרות מתורגמות במלואן: עברית, אנגלית, צרפתית, רוסית וגאורגית
• מראה לתפילין עם זיהוי מדויק של מקום הנחת הבית
• דיווח והצעות לשיפור – ישירות מהאפליקציה
• ברכה מעין שלוש וברכות הנהנין בנוסח עדות המזרח
• קוד QR לשיתוף האפליקציה, קישורים הנפתחים בתוך האפליקציה, מיקום אוטומטי וכותרת שנעלמת בגלילה
• מסך פתיחה חדש ושיפורי יציבות
```
**English**
```
Major update:
• New widgets for the Home Screen, Lock Screen and StandBy: Hebrew date and parasha, exact daily times, Tehillim, Shabbat & Yom Tov candle lighting, Sefirat HaOmer, time until sunset
• New Liquid Glass design (iOS 26): tab bar, header, search and controls
• New Search tab: find any chapter, prayer or book in the library
• Fully translated Settings: Hebrew, English, French, Russian and Georgian
• Tefillin mirror with precise placement guidance
• Send feedback and suggestions right from the app
• Birkat Meein Shalosh and Birkot HaNehenin (Edot HaMizrach wording)
• Shareable QR code, links that open inside the app, automatic location and a header that tucks away as you scroll
• New launch screen and stability improvements
```
**Français**
```
Mise à jour majeure :
• Nouveaux widgets (écran d’accueil, écran verrouillé, StandBy) : date hébraïque et paracha, horaires exacts, Tehilim, bougies de Chabbat et Yom Tov, Omer, temps jusqu’au coucher du soleil
• Nouveau design Liquid Glass (iOS 26)
• Nouvel onglet Recherche : un chapitre, une prière ou un livre dans toute la bibliothèque
• Réglages entièrement traduits : hébreu, anglais, français, russe, géorgien
• Miroir pour téfilin avec placement précis
• Envoyez vos remarques directement depuis l’app
• Berakha méèn chalosh et bénédictions avant de manger (rite séfarade orientale)
• QR code de partage, liens ouverts dans l’app, localisation automatique et en-tête qui se replie au défilement
```
**Русский**
```
Большое обновление:
• Новые виджеты (главный экран, экран блокировки, StandBy): еврейская дата и недельная глава, точные времена, Теилим, свечи Шаббата и Йом-Това, счёт Омера, время до заката
• Новый дизайн Liquid Glass (iOS 26)
• Новая вкладка «Поиск»: глава, молитва или книга во всей библиотеке
• Настройки полностью переведены: иврит, английский, французский, русский, грузинский
• Зеркало для тфилин с точным указанием места
• Отправка отзывов прямо из приложения
• Браха меэйн шалош и благословения перед едой (нусах мизрах)
• QR-код для обмена приложением, ссылки открываются внутри приложения, автоматическая геолокация и заголовок, скрывающийся при прокрутке
```
**ქართული**
```
დიდი განახლება:
• ახალი ვიჯეტები (მთავარი ეკრანი, ჩაკეტილი ეკრანი, StandBy): ებრაული თარიღი და ყოველკვირეული თავი, ზუსტი დროები, თეილიმი, შაბათისა და იომ ტოვის სანთლები, ომერი, დრო მზის ჩასვლამდე
• ახალი Liquid Glass დიზაინი (iOS 26)
• მთლიანად ნათარგმნი პარამეტრები: ებრაული, ინგლისური, ფრანგული, რუსული, ქართული
• თეფილინის სარკე ზუსტი მითითებით
• გამოხმაურების გაგზავნა პირდაპირ აპიდან
• ბრაქა მეეინ შალოშ და ბრაქოტ ჰანეჰენინ (აღმოსავლური წესი)
• გაზიარების QR კოდი, აპის შიგნით გახსნადი ბმულები, ავტომატური მდებარეობა და გადაფურცვლისას მიმალული სათაური
```

### Review Notes (למבקר של אפל)
```
No login or account is required. The app is a daily Torah-study companion.
Location (when in use) calculates daily prayer times and the compass; it stays on device. The app asks for it automatically on first launch so the times match the user's place.
External links (donation page, privacy, terms, social profiles) open in an in-app Safari sheet. The donation link goes to the community's own website; there is no in-app payment.
The star-rating prompt uses Apple's own SKStoreReviewController (at most about once a week, iOS decides).
Camera is used only by the optional "Tefillin mirror" screen; processed on device, nothing is saved or sent.
Widgets (Home Screen, Lock Screen, StandBy) and a Live Activity (countdown to sunrise/sunset) read a small App Group snapshot written by the app.
Optional push notifications ("New content") use Firebase Cloud Messaging.
Feedback form: name/email/subject/message are sent to the developer only to answer the user.
The app loads its static study texts from https://davidpit1565.github.io/Bet-El/ (GitHub Pages).
Built with Xcode 27 / iOS 27 SDK; Liquid Glass APIs have fallbacks on earlier iOS (deployment target 15).
```

## 4. דברים שפתוחים אצלך (לא קשורים לקוד)
- **דיווח והצעות – השרת:** הפונקציה `sendFeedback` ב-Firebase **לא פרוסה** (נותנת 404). עד שתפרוס (`firebase deploy --only functions` + מפתח Resend + דומיין מאומת) הטופס שומר ל-Firestore באוסף `feedback`, וזה עובד רק אם ה-rules מרשים יצירה. **בלי אחד משני אלה הדיווחים לא יגיעו אליך** (המשתמש יראה הודעת שגיאה עם העתק/שיתוף/מייל).
- **Firebase Cloud Messaging:** אחרי שחרור – כדאי קמפיין הודעה על התוכן החדש: https://console.firebase.google.com/project/bet-el-e6812/messaging
- **Privacy manifest:** נוסף `PrivacyInfo.xcprivacy` לאפליקציה ולהרחבה (UserDefaults: CA92.1 + 1C8F.1, בלי מעקב). אחרי ארכיב: Product → Archive → Generate Privacy Report ולוודא שאין API נוסף שדורש הצהרה (למשל File timestamp) - אם כן, להוסיף לקובץ.
- **Signing:** ה-App Group `group.com.beitel.tehilim` חייב להיות מופעל גם ב-App ID של האפליקציה וגם של `com.beitel.tehilim.widget`. לבדוק ב-Signing & Capabilities. ה-Live Activities (`NSSupportsLiveActivities`) כבר ב-Info.plist.
- **סכמת URL:** נוספה `betel://` ל-Info.plist (לחיצה על וידג'ט פותחת את האפליקציה במקום הנכון).

## 5. Vercel חסום – האם זה פוגע?
- **אפליקציית האייפון לא תלויה ב-Vercel.** קבצי הלימוד נטענים מ-GitHub Pages (`davidpit1565.github.io/Bet-El/`), והאפליקציה עצמה ארוזה בבינארי.
- Vercel משמש רק (א) לגרסת הרשת/PWA ולאנליטיקס שלה (`/_vercel/*` - נטענים `defer`, ואם נכשלים לא קורה כלום) ו-(ב) כאחסון אפשרי ל-`privacy.html`/`support.html`.
- **מה כן לבדוק:** שכתובות ה-Privacy Policy וה-Support שמוזנות ב-App Store Connect **נגישות** (פותחים אותן בדפדפן). אם הן על Vercel – להעביר ל-GitHub Pages (`https://davidpit1565.github.io/Bet-El/privacy.html`) לפני ההגשה, כדי שאפל לא תיתקל בדף שלא נטען.
- **GitHub Pages מתפרסם מ-main** בכל מיזוג (`.github/workflows/pages.yml`). לכן מומלץ למזג ל-main **רק אחרי** שבדקת ב-Xcode, כי המיזוג מעדכן מיד גם את האתר החי ואת הנתונים שאפליקציה המותקנת טוענת.

## 6. סיכום מה השתנה מאז הגרסה החיה (לתיאור/הערות)
מסך בית מותאם (עריכה כמו באייפון) · בלוקים נפרדים למשתמשים/מחוברים · רשתות חברתיות ו"לעילוי נשמת" קבועים · מסך פתיחה מונפש · ליקוויד גלס נייטיב (טאב-בר, כותרת, חיפוש, בורר, כפתורי עריכה) · ווידג'טים: תאריך, זמנים מדויקים, תהילים, רצף, נרות, StandBy, מסך נעילה (תאריך+פרשה, תהילים, רצף, זמן הבא, נרות, עד השקיעה, עומר), Live Activity · תרגומי הגדרות ב-5 שפות · טופס דיווח (אימייל, שם, נושא, הודעה) · מראה תפילין עם זיהוי שיער · זמני היום: עלות השחר לפי הלוח, בלי זמנים שלא הוגדרו · שיתוף פרטי היום המלאים · דגל "מכשיר פיתוח" לא סופר משתמשים ב-Firebase.

## 7. בדיקת עמידה בכללי אפל (נבדק בקוד לפני העדכון)
- ✅ **ITSAppUsesNonExemptEncryption=false**, הרשאות מצלמה/מיקום/תנועה עם נוסח ברור, `NSSupportsLiveActivities`, אין חריגי ATS, אין `server.url` בפיתוח, אייקון 1024 בלי שקיפות (RGB).
- ✅ **Privacy manifest** נוסף (ראו סעיף 4). **לעדכן ידנית את תוויות הפרטיות** ב-App Store Connect (סעיף 2) - Firebase Analytics/נוכחות + טופס משוב.
- ✅ **Xcode 26+ / iOS 26+ SDK** נדרש לארכיב (דרישת אפל); build 6 נבנה עם Xcode 27 / iOS 27 SDK. יעד הפריסה נשאר 15.0.
- ⚠️ **תרומות (הגדרות → "תמכו בבית אל")**: קישור חיצוני לדף תרומה (`bet-el.be`). זה היה קיים כבר בגרסה המאושרת, אבל סעיף 3.2.1(vi) מתיר גיוס תרומות באפליקציה רק לעמותה מאושרת. אם אפל תשאל: להסביר שהקישור הוא לדף תרומה של העמותה בלבד ולא פותח תוכן. אם רוצים אפס סיכון - להסתיר את השורה באפליקציית ה-iOS (להשאיר רק ב-PWA).
- ⚠️ **התראות "תוכן חדש" (FCM Web Push)**: ב-WKWebView של iOS הן לא נתמכות. לוודא שהמתג בהגדרות לא מבטיח משהו שלא עובד בבילד של האפליקציה (אחרת אפל עלולה לראות תכונה שבורה, סעיף 2.1) - אם לא עובד, להסתיר אותו בנייטיב.
- ⚠️ **קוד שנטען מרחוק**: מראה התפילין טוענת MediaPipe (WASM/מודל) מ-jsDelivr ומ-Google בשימוש הראשון. מותר כשהוא רץ בתוך ה-WebView, אבל כדאי לציין ב-Review Notes (כבר כתוב שם שטקסטים נטענים מ-GitHub Pages - להוסיף גם את זה).
- ⚠️ **ההרחבה (Widget)**: אין לוג קריסה עדיין - הווידג'טים ו-Live Activity לא הוצגו בגלריה על המכשיר. **חובה לפתור לפני העלאה** (אפל בודקת שהווידג'טים עובדים). ראו את הלוג דרך Xcode (סכמת BetElWidget).
- ⚠️ **קוד ה-Swift לא קומפל**: `NativeHome.swift` ואחרים - לבנות, לתקן, ולהריץ את הבדיקות בסעיף 1 על אייפון אמיתי לפני ארכיב.
