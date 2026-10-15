package com.beitel.tehilim;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;

import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;

import org.json.JSONObject;

import java.util.List;

/**
 * Android counterpart of the iOS Live Activity: one ongoing, silent notification that counts down (system
 * chronometer - keeps ticking without the app running) to the next zman: dawn, sunrise, midday, sunset,
 * nightfall (when synced) and midnight. Re-posted at every zman by BetElRefresh's alarm.
 */
final class LiveZmanNotifier {
    private static final String CHANNEL = "live_zman";
    private static final int ID = 4401;

    private LiveZmanNotifier() {}

    static void cancel(Context c) {
        try { NotificationManagerCompat.from(c).cancel(ID); } catch (Throwable ignored) {}
    }

    static void refresh(Context c) {
        JSONObject d = BetElStore.read(c);
        if (!d.optBoolean("liveNotif", true)) { cancel(c); return; }
        NotificationManagerCompat nm = NotificationManagerCompat.from(c);
        if (!nm.areNotificationsEnabled()) return;
        long now = System.currentTimeMillis();
        List<BetElStore.Z> up = BetElStore.upcoming(d, now, 1);
        if (up.isEmpty()) { cancel(c); return; }
        BetElStore.Z next = up.get(0);
        String lang = BetElStore.lang(d);

        if (Build.VERSION.SDK_INT >= 26) {
            NotificationChannel ch = new NotificationChannel(CHANNEL, BetElStore.t("nextZman", lang), NotificationManager.IMPORTANCE_LOW);
            ch.setShowBadge(false);
            ch.setSound(null, null);
            ch.enableVibration(false);
            NotificationManager sys = (NotificationManager) c.getSystemService(Context.NOTIFICATION_SERVICE);
            if (sys != null) sys.createNotificationChannel(ch);
        }

        Intent open = new Intent(Intent.ACTION_VIEW, Uri.parse("betel://calendar")).setPackage(c.getPackageName());
        int flags = PendingIntent.FLAG_UPDATE_CURRENT | (Build.VERSION.SDK_INT >= 23 ? PendingIntent.FLAG_IMMUTABLE : 0);
        PendingIntent pi = PendingIntent.getActivity(c, 4402, open, flags);

        Notification n = new NotificationCompat.Builder(c, CHANNEL)
                .setSmallIcon(R.drawable.ic_stat_zman)
                .setColor(0xFFD4AF5F)
                .setContentTitle(BetElStore.t(next.key, lang))
                .setContentText(BetElStore.t("nextZman", lang) + " · " + BetElStore.hm(next.t))
                .setWhen(next.t)
                .setShowWhen(true)
                .setUsesChronometer(true)
                .setChronometerCountDown(true)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setSilent(true)
                .setCategory(NotificationCompat.CATEGORY_STATUS)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setContentIntent(pi)
                // Safety net: never leave a countdown at 0 if the rollover alarm is late - the next tick re-posts it.
                .setTimeoutAfter(next.t - now + 90_000)
                .build();
        try { nm.notify(ID, n); } catch (SecurityException ignored) {}
    }
}
