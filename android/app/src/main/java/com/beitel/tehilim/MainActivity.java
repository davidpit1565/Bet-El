package com.beitel.tehilim;

import android.os.Bundle;
import android.webkit.WebSettings;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        applyFixedTextZoom();
    }

    @Override
    public void onResume() {
        super.onResume();
        applyFixedTextZoom();
    }

    /**
     * Android's WebView multiplies every font by the phone's "Font size" setting (textZoom follows it), so on phones
     * with a large system font the whole app rendered oversized and broken (huge tile titles, wrapped labels) while the
     * same page looked right in a browser. The app has its own reading-size setting (S.fontScale), so the WebView text
     * zoom is pinned to 100%.
     */
    private void applyFixedTextZoom() {
        try {
            if (getBridge() != null && getBridge().getWebView() != null) {
                WebSettings s = getBridge().getWebView().getSettings();
                if (s.getTextZoom() != 100) s.setTextZoom(100);
            }
        } catch (Exception ignored) { }
    }
}
