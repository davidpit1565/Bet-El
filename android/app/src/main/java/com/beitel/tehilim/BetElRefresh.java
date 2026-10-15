package com.beitel.tehilim;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

import org.json.JSONObject;

import java.util.List;

/** One entry point that re-renders every widget + the ongoing notification and arms the next rollover alarm. */
final class BetElRefresh {
    static final String ACTION = "com.beitel.tehilim.REFRESH";

    private BetElRefresh() {}

    static void run(Context c) {
        try { BetElWidgets.updateAll(c); } catch (Throwable ignored) {}
        try { LiveZmanNotifier.refresh(c); } catch (Throwable ignored) {}
        try { scheduleNext(c); } catch (Throwable ignored) {}
    }

    /** Wakes at the next zman / local midnight so the countdowns and the Hebrew date roll over on their own. */
    private static void scheduleNext(Context c) {
        AlarmManager am = (AlarmManager) c.getSystemService(Context.ALARM_SERVICE);
        if (am == null) return;
        long now = System.currentTimeMillis();
        JSONObject d = BetElStore.read(c);
        long next = BetElStore.nextMidnight(now);
        List<BetElStore.Z> up = BetElStore.upcoming(d, now, 1);
        if (!up.isEmpty()) next = Math.min(next, up.get(0).t);
        long at = Math.max(next + 3000, now + 30000);
        Intent i = new Intent(c, ZmanRefreshReceiver.class).setAction(ACTION);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT | (Build.VERSION.SDK_INT >= 23 ? PendingIntent.FLAG_IMMUTABLE : 0);
        PendingIntent pi = PendingIntent.getBroadcast(c, 7001, i, flags);
        // Inexact on purpose (no exact-alarm permission needed): may fire a minute or so late in Doze.
        if (Build.VERSION.SDK_INT >= 23) am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi);
        else am.set(AlarmManager.RTC_WAKEUP, at, pi);
    }
}
