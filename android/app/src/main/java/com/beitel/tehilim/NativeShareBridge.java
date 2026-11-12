package com.beitel.tehilim;

import android.content.Intent;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

/** Android WebView has no navigator.share, so shareDirect() (index.html) calls this: the system share sheet for plain text. */
@CapacitorPlugin(name = "NativeShare")
public class NativeShareBridge extends Plugin {
    @PluginMethod
    public void share(PluginCall call) {
        try {
            String text = call.getString("text", "");
            String title = call.getString("title", "");
            Intent send = new Intent(Intent.ACTION_SEND);
            send.setType("text/plain");
            send.putExtra(Intent.EXTRA_TEXT, text);
            if (title != null && !title.isEmpty()) send.putExtra(Intent.EXTRA_SUBJECT, title);
            Intent chooser = Intent.createChooser(send, (title == null || title.isEmpty()) ? null : title);
            getActivity().startActivity(chooser);
            call.resolve();
        } catch (Throwable t) {
            call.reject("share failed");
        }
    }
}
