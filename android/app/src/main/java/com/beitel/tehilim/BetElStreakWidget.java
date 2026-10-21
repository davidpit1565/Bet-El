package com.beitel.tehilim;

import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;

public class BetElStreakWidget extends AppWidgetProvider {
    @Override
    public void onUpdate(Context context, AppWidgetManager mgr, int[] ids) {
        BetElWidgets.update(context, mgr, BetElStreakWidget.class, ids);
        BetElRefresh.run(context);
    }

    @Override
    public void onEnabled(Context context) {
        BetElRefresh.run(context);
    }
}
