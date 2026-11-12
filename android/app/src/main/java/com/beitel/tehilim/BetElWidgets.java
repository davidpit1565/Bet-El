package com.beitel.tehilim;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.SystemClock;
import android.view.View;
import android.widget.RemoteViews;

import org.json.JSONObject;

import java.util.List;

/** Renders the four Android home-screen widgets (same content + palette as the iOS ones; follow system light/dark). */
final class BetElWidgets {
    private BetElWidgets() {}

    static final Class<?>[] PROVIDERS = {
            BetElMainWidget.class, BetElZmanimWidget.class, BetElCandleWidget.class, BetElStreakWidget.class
    };

    static void updateAll(Context c) {
        AppWidgetManager mgr = AppWidgetManager.getInstance(c);
        for (Class<?> p : PROVIDERS) {
            int[] ids = mgr.getAppWidgetIds(new ComponentName(c, p));
            if (ids != null && ids.length > 0) update(c, mgr, p, ids);
        }
    }

    static void update(Context c, AppWidgetManager mgr, Class<?> provider, int[] ids) {
        JSONObject d = BetElStore.read(c);
        long now = System.currentTimeMillis();
        for (int id : ids) {
            try {
                mgr.updateAppWidget(id, build(c, provider, d, now));
            } catch (Throwable t) {
                // One broken widget must not stop the others (or the notification / alarm that follow).
                android.util.Log.e("BetElWidgets", "update failed for " + provider.getSimpleName(), t);
            }
        }
    }

    /** Builds the RemoteViews for one provider (package-private so the instrumented test can apply them). */
    static RemoteViews build(Context c, Class<?> provider, JSONObject d, long now) {
        if (provider == BetElMainWidget.class) return main(c, d, now);
        if (provider == BetElZmanimWidget.class) return zmanim(c, d, now);
        if (provider == BetElCandleWidget.class) return candle(c, d, now);
        return streak(c, d, now);
    }

    // ---------- helpers ----------
    private static int color(Context c, int res) { return c.getResources().getColor(res, null); }

    /* No reflection-based setters (setInt "setGravity" etc.): a RemoteViews action naming a method that is not
       @RemotableViewMethod throws while the launcher applies it, and the whole widget then shows "Can't load widget".
       Text alignment comes from the layouts (textAlignment="textStart": Hebrew right, others left). */
    private static void text(RemoteViews rv, int id, String s, int color) {
        rv.setTextViewText(id, s);
        rv.setTextColor(id, color);
    }

    private static PendingIntent link(Context c, String kind, int code) {
        Intent i = new Intent(Intent.ACTION_VIEW, Uri.parse("betel://" + kind)).setPackage(c.getPackageName());
        int flags = PendingIntent.FLAG_UPDATE_CURRENT | (Build.VERSION.SDK_INT >= 23 ? PendingIntent.FLAG_IMMUTABLE : 0);
        return PendingIntent.getActivity(c, code, i, flags);
    }

    /** System-driven countdown (keeps ticking with no process running); hidden if there is nothing to count to. */
    private static void countdown(RemoteViews rv, boolean rtl, long end, long now, int color) {
        // Two Chronometers (left / right aligned in the layout) instead of switching gravity at runtime.
        int show = rtl ? R.id.countdown_rtl : R.id.countdown, hide = rtl ? R.id.countdown : R.id.countdown_rtl;
        rv.setViewVisibility(hide, View.GONE);
        if (end > now) {
            rv.setViewVisibility(show, View.VISIBLE);
            rv.setChronometer(show, SystemClock.elapsedRealtime() + (end - now), null, true);
            rv.setChronometerCountDown(show, true);
            rv.setTextColor(show, color);
        } else {
            rv.setViewVisibility(show, View.GONE);
        }
    }

    // ---------- main: Hebrew date + parasha + next zman ----------
    private static RemoteViews main(Context c, JSONObject d, long now) {
        RemoteViews rv = new RemoteViews(c.getPackageName(), R.layout.widget_main);
        String lang = BetElStore.lang(d);
        int ink = color(c, R.color.widget_ink), soft = color(c, R.color.widget_ink_soft);
        int gold = color(c, R.color.widget_gold), bright = color(c, R.color.widget_gold_bright);
        String heb = BetElStore.hebDate(d, now);
        text(rv, R.id.tv_greg, BetElStore.gregLine(now, lang), soft);
        text(rv, R.id.tv_heb, heb.isEmpty() ? "תמיד" : heb, bright);
        String label = BetElStore.dayLabel(d, now);
        int omer = BetElStore.omerDay(d, now);
        if (label.isEmpty() && omer > 0) label = BetElStore.omerLine(omer, lang);
        text(rv, R.id.tv_label, label, gold);
        rv.setViewVisibility(R.id.tv_label, label.isEmpty() ? View.GONE : View.VISIBLE);
        List<BetElStore.Z> up = BetElStore.upcoming(d, now, 1);
        if (up.isEmpty()) {
            text(rv, R.id.tv_next, BetElStore.t("openApp", lang), soft);
            rv.setViewVisibility(R.id.countdown, View.GONE);
            rv.setViewVisibility(R.id.countdown_rtl, View.GONE);
        } else {
            BetElStore.Z z = up.get(0);
            text(rv, R.id.tv_next, BetElStore.t(z.key, lang) + " · " + BetElStore.hm(z.t), soft);
            countdown(rv, BetElStore.rtl(d), z.t, now, ink);
        }
        rv.setOnClickPendingIntent(R.id.root, link(c, "calendar", 11));
        return rv;
    }

    // ---------- zmanim list ----------
    private static RemoteViews zmanim(Context c, JSONObject d, long now) {
        RemoteViews rv = new RemoteViews(c.getPackageName(), R.layout.widget_zmanim);
        String lang = BetElStore.lang(d);
        boolean rtl = BetElStore.rtl(d);
        int ink = color(c, R.color.widget_ink), soft = color(c, R.color.widget_ink_soft), bright = color(c, R.color.widget_gold_bright);
        text(rv, R.id.tv_title, BetElStore.t("zmanimToday", lang), soft);
        rv.removeAllViews(R.id.rows);
        List<BetElStore.Z> today = BetElStore.today(d, now);
        List<BetElStore.Z> up = BetElStore.upcoming(d, now, 1);
        long nextT = up.isEmpty() ? -1 : up.get(0).t;
        for (BetElStore.Z z : today) {
            RemoteViews row = new RemoteViews(c.getPackageName(), rtl ? R.layout.widget_row_rtl : R.layout.widget_row_ltr);
            boolean isNext = z.t == nextT;
            row.setTextViewText(R.id.row_label, BetElStore.t(z.key, lang));
            row.setTextViewText(R.id.row_time, BetElStore.hm(z.t));
            row.setTextColor(R.id.row_label, isNext ? bright : ink);
            row.setTextColor(R.id.row_time, isNext ? bright : (z.t < now ? soft : ink));
            rv.addView(R.id.rows, row);
        }
        if (today.isEmpty()) {
            text(rv, R.id.tv_empty, BetElStore.t("openApp", lang), soft);
            rv.setViewVisibility(R.id.tv_empty, View.VISIBLE);
        } else {
            rv.setViewVisibility(R.id.tv_empty, View.GONE);
        }
        rv.setOnClickPendingIntent(R.id.root, link(c, "calendar", 12));
        return rv;
    }

    // ---------- candle lighting ----------
    private static RemoteViews candle(Context c, JSONObject d, long now) {
        RemoteViews rv = new RemoteViews(c.getPackageName(), R.layout.widget_candle);
        String lang = BetElStore.lang(d);
        int ink = color(c, R.color.widget_ink), soft = color(c, R.color.widget_ink_soft);
        int gold = color(c, R.color.widget_gold), bright = color(c, R.color.widget_gold_bright);
        Object[] next = BetElStore.nextCandle(d, now);
        if (next == null) {
            text(rv, R.id.tv_title, BetElStore.t("candleLighting", lang), soft);
            text(rv, R.id.tv_time, "—", bright);
            text(rv, R.id.tv_sub, BetElStore.t("noCandle", lang), gold);
            rv.setViewVisibility(R.id.countdown, View.GONE);
            rv.setViewVisibility(R.id.countdown_rtl, View.GONE);
        } else {
            long t = (Long) next[0];
            String l = (String) next[1];
            text(rv, R.id.tv_title, l == null || l.isEmpty() ? BetElStore.t("candleLighting", lang) : l, soft);
            text(rv, R.id.tv_time, BetElStore.hm(t), bright);
            text(rv, R.id.tv_sub, BetElStore.t("candleIn", lang), gold);
            countdown(rv, BetElStore.rtl(d), t, now, ink);
        }
        rv.setOnClickPendingIntent(R.id.root, link(c, "calendar", 13));
        return rv;
    }

    // ---------- study streak ----------
    private static RemoteViews streak(Context c, JSONObject d, long now) {
        RemoteViews rv = new RemoteViews(c.getPackageName(), R.layout.widget_streak);
        String lang = BetElStore.lang(d);
        int soft = color(c, R.color.widget_ink_soft), gold = color(c, R.color.widget_gold), bright = color(c, R.color.widget_gold_bright);
        text(rv, R.id.tv_title, BetElStore.t("streakTitle", lang), soft);
        text(rv, R.id.tv_count, String.valueOf(d.optInt("streakCount", 0)), bright);
        text(rv, R.id.tv_sub, BetElStore.t("dayStreak", lang), gold);
        text(rv, R.id.tv_best, BetElStore.t("best", lang) + " " + d.optInt("streakBest", 0), soft);
        rv.setOnClickPendingIntent(R.id.root, link(c, "tracker", 14));
        return rv;
    }
}
