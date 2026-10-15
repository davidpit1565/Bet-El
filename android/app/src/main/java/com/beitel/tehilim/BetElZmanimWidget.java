package com.beitel.tehilim;

import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;

public class BetElZmanimWidget extends AppWidgetProvider {
    @Override
    public void onUpdate(Context context, AppWidgetManager mgr, int[] ids) {
        BetElWidgets.update(context, mgr, BetElZmanimWidget.class, ids);
        BetElRefresh.run(context);
    }

    @Override
    public void onEnabled(Context context) {
        BetElRefresh.run(context);
    }
}
