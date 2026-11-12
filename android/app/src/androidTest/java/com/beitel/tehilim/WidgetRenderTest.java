package com.beitel.tehilim;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

import android.appwidget.AppWidgetProviderInfo;
import android.content.ComponentName;
import android.content.Context;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.RemoteViews;
import android.widget.TextView;

import androidx.test.platform.app.InstrumentationRegistry;

import org.json.JSONArray;
import org.json.JSONObject;
import org.junit.Test;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.TimeZone;

/**
 * Applies every widget's RemoteViews the way a launcher does (apply() throws ActionException for any action the
 * framework rejects, which is what shows up on a phone as "Can't load widget"), and checks the data arrives.
 */
public class WidgetRenderTest {
    private static String isoIn(long ms) {
        SimpleDateFormat f = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US);
        f.setTimeZone(TimeZone.getTimeZone("UTC"));
        return f.format(new Date(System.currentTimeMillis() + ms));
    }

    private static JSONObject snapshot(String lang) throws Exception {
        long h = 3600_000L;
        String today = BetElStore.ymd(System.currentTimeMillis());
        JSONObject d = new JSONObject();
        d.put("lang", lang);
        d.put("streakCount", 7);
        d.put("streakBest", 12);
        JSONObject z = new JSONObject();
        z.put("d", today);
        z.put("a", isoIn(-5 * h)); z.put("r", isoIn(-4 * h)); z.put("c", isoIn(2 * h)); z.put("s", isoIn(8 * h));
        // The table is sent as a JSON *string* by the app (JSON.stringify), so do the same here.
        d.put("zmanim", new JSONArray().put(z).toString());
        d.put("hebDays", new JSONArray().put(new JSONObject().put("d", today).put("n", "ד׳").put("m", "חשון").put("y", "תשפ״ז")).toString());
        d.put("dayLabels", new JSONArray().put(new JSONObject().put("d", today).put("t", "פרשת נח")).toString());
        d.put("candles", new JSONArray().put(new JSONObject().put("t", isoIn(30 * h)).put("l", "Shabbat candles")).toString());
        return d;
    }

    private static String allText(View v) {
        StringBuilder sb = new StringBuilder();
        if (v instanceof TextView && v.getVisibility() == View.VISIBLE) sb.append(((TextView) v).getText()).append('|');
        if (v instanceof ViewGroup) {
            ViewGroup g = (ViewGroup) v;
            for (int i = 0; i < g.getChildCount(); i++) sb.append(allText(g.getChildAt(i)));
        }
        return sb.toString();
    }

    @Test
    public void everyWidgetAppliesAndShowsData() throws Exception {
        Context c = InstrumentationRegistry.getInstrumentation().getTargetContext();
        for (String lang : new String[]{"he", "en"}) {
            JSONObject d = snapshot(lang);
            for (Class<?> p : BetElWidgets.PROVIDERS) {
                RemoteViews rv = BetElWidgets.build(c, p, d, System.currentTimeMillis());
                View v = rv.apply(c, new FrameLayout(c));
                assertNotNull(p.getSimpleName(), v);
                String text = allText(v);
                if (p == BetElMainWidget.class) assertTrue(text, text.contains("חשון") && text.contains("פרשת נח"));
                if (p == BetElZmanimWidget.class) assertTrue(text, text.contains(BetElStore.hm(System.currentTimeMillis() + 2 * 3600_000L)));
                if (p == BetElCandleWidget.class) assertTrue(text, text.contains("Shabbat candles"));
                if (p == BetElStreakWidget.class) assertTrue(text, text.contains("7") && text.contains("12"));
            }
        }
    }

    @Test
    public void emptySnapshotStillApplies() throws Exception {
        Context c = InstrumentationRegistry.getInstrumentation().getTargetContext();
        for (Class<?> p : BetElWidgets.PROVIDERS) {
            View v = BetElWidgets.build(c, p, new JSONObject(), System.currentTimeMillis()).apply(c, new FrameLayout(c));
            assertNotNull(v);
        }
    }

    @Test
    public void providersAreInstalledAndDeclareLayouts() {
        Context c = InstrumentationRegistry.getInstrumentation().getTargetContext();
        android.appwidget.AppWidgetManager m = android.appwidget.AppWidgetManager.getInstance(c);
        int found = 0;
        for (AppWidgetProviderInfo i : m.getInstalledProvidersForPackage(c.getPackageName(), null)) {
            assertTrue(i.initialLayout != 0);
            found++;
        }
        assertEquals(4, found);
        for (Class<?> p : BetElWidgets.PROVIDERS) assertNotNull(new ComponentName(c, p));
    }
}
