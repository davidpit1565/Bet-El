package com.beitel.tehilim;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/** Alarm tick, boot, time/timezone change, app update: refresh widgets + notification and re-arm. */
public class ZmanRefreshReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        BetElRefresh.run(context);
    }
}
