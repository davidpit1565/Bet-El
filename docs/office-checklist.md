# במשרד – רשימה לשחרור עדכון 2.0 (לפי הסדר)

1. **Mac:** `cd ~/Bet-El && git pull origin claude/additional-file-fas9ie` ואז `npm run cap:sync`.
2. **לקרוא** `MORNING-REPORT.md` (אם Claude Code בטרמינל סיים את עבודת הלילה) ולבדוק את התמונות ב-`docs/appstore/slides*/`.
3. **Xcode:** לבנות ולהתקין על האייפון. לבדוק:
   - הדר: נעלם בגלילה למטה, חוזר בגלילה למעלה (חוק לישראל, תהילים, ספרייה).
   - ברכה מעין שלוש: נוסח אחד, תוספת שבת/ראש חודש מופיעה.
   - ווידג'טים: לחיצה ארוכה במסך הבית → + → "תמיד" מופיע? (אם לא – פרומט 4).
   - קישורים נפתחים בתוך האפליקציה, שיתוף QR, מיקום אוטומטי.
4. **Firebase (דיווח והצעות):** `npx firebase-tools login` → `npx firebase-tools use bet-el-e6812` → פרומט 6 ב-`docs/claude-code-prompts.md`. לבדוק ששליחת טופס מגיעה.
5. **למזג את PR #221** (רק אחרי שלב 3 עבר) – צריך שדף הפרטיות יהיה באוויר לפני ההגשה.
6. **App Store Connect** (אם הטרמינל העלה): לבחור build 6, לבדוק טקסטים ותמונות, App Privacy, דירוג גיל, Export Compliance → **Submit for Review**.
7. אחרי האישור: לבטל את מפתח ה-API Admin וליצור App Manager; לשלוח הודעת Firebase על התוכן החדש.
