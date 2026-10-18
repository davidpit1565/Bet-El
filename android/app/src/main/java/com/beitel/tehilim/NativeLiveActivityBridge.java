package com.beitel.tehilim;

import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

/** Android's "Live Activity": the ongoing zman countdown notification (see LiveZmanNotifier). */
@CapacitorPlugin(name = "NativeLiveActivity")
public class NativeLiveActivityBridge extends Plugin {
    @PluginMethod
    public void refresh(PluginCall call) {
        try { BetElRefresh.run(getContext()); } catch (Throwable ignored) {}
        call.resolve();
    }

    @PluginMethod
    public void end(PluginCall call) {
        try { LiveZmanNotifier.cancel(getContext()); } catch (Throwable ignored) {}
        call.resolve();
    }
}
