package com.beitel.tehilim;

import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

/** Same JS surface as the iOS plugin: the app pushes its widget snapshot, Android stores it and re-renders. */
@CapacitorPlugin(name = "BetElWidgetBridge")
public class BetElWidgetBridge extends Plugin {
    @PluginMethod
    public void updateSharedData(PluginCall call) {
        try {
            BetElStore.save(getContext(), call.getData().toString());
            BetElRefresh.run(getContext());
        } catch (Throwable ignored) {}
        call.resolve();
    }
}
