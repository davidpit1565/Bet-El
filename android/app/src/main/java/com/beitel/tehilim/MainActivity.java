package com.beitel.tehilim;

import android.os.Bundle;

import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        registerPlugin(BetElWidgetBridge.class);
        registerPlugin(NativeLiveActivityBridge.class);
        super.onCreate(savedInstanceState);
    }
}
