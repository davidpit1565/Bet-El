package com.beitel.tehilim;

import android.content.Context;

import org.json.JSONArray;
import org.json.JSONObject;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.TimeZone;

/**
 * Snapshot the web app pushes (BetElWidgetBridge.updateSharedData) + everything the Android widgets and the
 * ongoing zman notification derive from it. Same data the iOS widgets read: exact zmanim table, parasha/holiday
 * per day, candle lighting, streak - so the widgets keep working for ~2 months without opening the app.
 */
final class BetElStore {
    private static final String PREFS = "betel_widget_data";
    private static final String KEY = "snapshot";

    private BetElStore() {}

    static void save(Context c, String json) {
        c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, json).apply();
    }

    static JSONObject read(Context c) {
        try {
            String s = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null);
            return s == null ? new JSONObject() : new JSONObject(s);
        } catch (Exception e) {
            return new JSONObject();
        }
    }

    // ---------- strings (he, en, fr, ru, ka) - same table as the iOS widgets (Localization.swift) ----------
    private static final Map<String, String[]> T = new HashMap<>();
    private static void put(String k, String he, String en, String fr, String ru, String ka) { T.put(k, new String[]{he, en, fr, ru, ka}); }
    static {
        put("dawn", "עֲלוֹת הַשַּׁחַר", "Dawn", "Aube", "Рассвет", "განთიადი");
        put("sunrise", "זְרִיחָה", "Sunrise", "Lever du soleil", "Восход", "მზის ამოსვლა");
        put("chatzot", "חֲצוֹת", "Midday", "Midi", "Полдень", "შუადღე");
        put("sunset", "שְׁקִיעָה", "Sunset", "Coucher du soleil", "Закат", "მზის ჩასვლა");
        put("tzeit", "צֵאת הַכּוֹכָבִים", "Nightfall", "Tombée de la nuit", "Выход звёзд", "ვარსკვლავების გამოჩენა");
        put("chatzotNight", "חֲצוֹת הַלַּיְלָה", "Midnight", "Minuit", "Полночь", "შუაღამე");
        put("nextZman", "הַזְּמַן הַבָּא", "Next zman", "Prochain horaire", "Следующее время", "შემდეგი დრო");
        put("zmanimToday", "זְמַנֵּי הַיּוֹם", "Today's times", "Horaires du jour", "Времена на сегодня", "დღევანდელი დროები");
        put("candleIn", "עַד הַדְלָקָה", "Until candle lighting", "Avant l’allumage", "До зажигания", "სანთლების ანთებამდე");
        put("noCandle", "אֵין הַדְלָקָה בְּקָרוֹב", "No candle lighting soon", "Pas d’allumage prochain", "Ближайшего зажигания нет", "უახლოეს დროს ანთება არ არის");
        put("candleLighting", "הַדְלָקַת נֵרוֹת", "Candle lighting", "Allumage des bougies", "Зажигание свечей", "სანთლების ანთება");
        put("streakTitle", "רֶצֶף לִמּוּד", "Study streak", "Série d’étude", "Серия учёбы", "სწავლის სერია");
        put("best", "שִׂיא", "Best", "Record", "Рекорд", "რეკორდი");
        put("dayStreak", "יָמִים בְּרֶצֶף", "day streak", "jours d’affilée", "дней подряд", "დღე ზედიზედ");
        put("openApp", "פִּתְחוּ אֶת הָאַפְּלִיקַצְיָה", "Open the app", "Ouvrez l’application", "Откройте приложение", "გახსენით აპლიკაცია");
    }

    static String lang(JSONObject d) {
        String l = d.optString("lang", "he");
        return ("he".equals(l) || "en".equals(l) || "fr".equals(l) || "ru".equals(l) || "ka".equals(l)) ? l : "he";
    }

    static boolean rtl(JSONObject d) { return "he".equals(lang(d)); }

    static String t(String key, String lang) {
        String[] v = T.get(key);
        if (v == null) return key;
        int i = "he".equals(lang) ? 0 : "fr".equals(lang) ? 2 : "ru".equals(lang) ? 3 : "ka".equals(lang) ? 4 : 1;
        return v[i];
    }

    static String omerLine(int n, String lang) {
        switch (lang) {
            case "he": return "הַיּוֹם " + n + " בָּעֹמֶר";
            case "fr": return "Jour " + n + " de l’Omer";
            case "ru": return "День " + n + " Омера";
            case "ka": return "ომერის " + n + "-ე დღე";
            default: return "Day " + n + " of the Omer";
        }
    }

    // ---------- time helpers ----------
    static long iso(String s) {
        if (s == null || s.isEmpty() || "null".equals(s)) return -1;
        try {
            SimpleDateFormat f = new SimpleDateFormat(s.contains(".") ? "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'" : "yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US);
            f.setTimeZone(TimeZone.getTimeZone("UTC"));
            return f.parse(s).getTime();
        } catch (Exception e) {
            return -1;
        }
    }

    static String ymd(long t) {
        SimpleDateFormat f = new SimpleDateFormat("yyyy-MM-dd", Locale.US);
        return f.format(new java.util.Date(t));
    }

    static String hm(long t) {
        SimpleDateFormat f = new SimpleDateFormat("HH:mm", Locale.US);
        return f.format(new java.util.Date(t));
    }

    static long nextMidnight(long now) {
        java.util.Calendar c = java.util.Calendar.getInstance();
        c.setTimeInMillis(now);
        c.set(java.util.Calendar.HOUR_OF_DAY, 0); c.set(java.util.Calendar.MINUTE, 0);
        c.set(java.util.Calendar.SECOND, 0); c.set(java.util.Calendar.MILLISECOND, 0);
        c.add(java.util.Calendar.DAY_OF_MONTH, 1);
        return c.getTimeInMillis();
    }

    /** "Thursday, 15 October 2026" in the app language. */
    static String gregLine(long now, String lang) {
        SimpleDateFormat f = new SimpleDateFormat("EEEE, d MMMM yyyy", new Locale(lang));
        return f.format(new java.util.Date(now));
    }

    // ---------- tables ----------
    static JSONArray arr(JSONObject d, String key) {
        try {
            Object o = d.opt(key);
            if (o instanceof JSONArray) return (JSONArray) o;
            if (o instanceof String && !((String) o).isEmpty() && !"null".equals(o)) return new JSONArray((String) o);
        } catch (Exception ignored) {}
        return new JSONArray();
    }

    private static JSONObject rowFor(JSONObject d, String key, String day) {
        JSONArray a = arr(d, key);
        for (int i = 0; i < a.length(); i++) {
            JSONObject r = a.optJSONObject(i);
            if (r != null && day.equals(r.optString("d"))) return r;
        }
        return null;
    }

    /** Hebrew date in the app language, e.g. "ד׳ חשון תשפ״ז". Empty when the table doesn't cover the day. */
    static String hebDate(JSONObject d, long now) {
        JSONObject r = rowFor(d, "hebDays", ymd(now));
        return r == null ? "" : (r.optString("n") + " " + r.optString("m") + " " + r.optString("y")).trim();
    }

    static String dayLabel(JSONObject d, long now) {
        JSONObject r = rowFor(d, "dayLabels", ymd(now));
        return r == null ? "" : r.optString("t");
    }

    static int omerDay(JSONObject d, long now) {
        JSONObject r = rowFor(d, "omer", ymd(now));
        return r == null ? 0 : r.optInt("n", 0);
    }

    static final class Z {
        final String key; final long t;
        Z(String key, long t) { this.key = key; this.t = t; }
    }

    private static void add(List<Z> out, String key, String iso) {
        long t = iso(iso);
        if (t > 0) out.add(new Z(key, t));
    }

    /** Every known zman (dawn, sunrise, midday, sunset, nightfall when synced, midnight = midday + 12h), sorted. */
    static List<Z> allZmanim(JSONObject d) {
        List<Z> out = new ArrayList<>();
        JSONArray rows = arr(d, "zmanim");
        for (int i = 0; i < rows.length(); i++) {
            JSONObject r = rows.optJSONObject(i);
            if (r == null) continue;
            add(out, "dawn", r.optString("a"));
            add(out, "sunrise", r.optString("r"));
            add(out, "chatzot", r.optString("c"));
            add(out, "sunset", r.optString("s"));
            add(out, "tzeit", r.optString("t"));
            long c = iso(r.optString("c"));
            if (c > 0) out.add(new Z("chatzotNight", c + 12L * 60 * 60 * 1000));
        }
        Collections.sort(out, new Comparator<Z>() { public int compare(Z a, Z b) { return Long.compare(a.t, b.t); } });
        return out;
    }

    static List<Z> upcoming(JSONObject d, long now, int max) {
        List<Z> out = new ArrayList<>();
        for (Z z : allZmanim(d)) {
            if (z.t > now) { out.add(z); if (out.size() >= max) break; }
        }
        return out;
    }

    /** Today's rows for the list widget (no midnight). */
    static List<Z> today(JSONObject d, long now) {
        String day = ymd(now);
        List<Z> out = new ArrayList<>();
        JSONObject r = rowFor(d, "zmanim", day);
        if (r != null) {
            add(out, "dawn", r.optString("a"));
            add(out, "sunrise", r.optString("r"));
            add(out, "chatzot", r.optString("c"));
            add(out, "sunset", r.optString("s"));
            add(out, "tzeit", r.optString("t"));
        }
        return out;
    }

    /** Next candle lighting after now: {time, label}, or null. */
    static Object[] nextCandle(JSONObject d, long now) {
        JSONArray a = arr(d, "candles");
        for (int i = 0; i < a.length(); i++) {
            JSONObject r = a.optJSONObject(i);
            if (r == null) continue;
            long t = iso(r.optString("t"));
            if (t > now) return new Object[]{t, r.optString("l")};
        }
        return null;
    }
}
