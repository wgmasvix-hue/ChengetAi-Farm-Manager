package com.chengetailabs.farmmanager;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Bundle;
import android.view.Menu;
import android.view.MenuItem;
import android.webkit.GeolocationPermissions;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.EditText;
import android.widget.FrameLayout;

public class MainActivity extends Activity {

    private static final String BASE_DOMAIN = "farm.chengetailabs.co.zw";
    private static final int FILE_CHOOSER_REQUEST = 1;
    private static final int LOCATION_REQUEST = 2;

    private WebView webView;
    private SharedPreferences prefs;
    private ValueCallback<Uri[]> pendingFileCallback;
    private GeolocationPermissions.Callback pendingGeoCallback;
    private String pendingGeoOrigin;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        prefs = getSharedPreferences("app", MODE_PRIVATE);

        webView = new WebView(this);
        setContentView(webView, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));

        WebSettings s = webView.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setGeolocationEnabled(true);
        s.setLoadWithOverviewMode(true);
        s.setUseWideViewPort(true);

        webView.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                Uri uri = request.getUrl();
                String host = uri.getHost();
                if (host != null && (host.equals(BASE_DOMAIN) || host.endsWith("." + BASE_DOMAIN))) {
                    return false;
                }
                try {
                    startActivity(new Intent(Intent.ACTION_VIEW, uri));
                } catch (Exception ignored) {
                }
                return true;
            }
        });

        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public void onGeolocationPermissionsShowPrompt(String origin,
                    GeolocationPermissions.Callback callback) {
                if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
                        == PackageManager.PERMISSION_GRANTED) {
                    callback.invoke(origin, true, true);
                } else {
                    pendingGeoCallback = callback;
                    pendingGeoOrigin = origin;
                    requestPermissions(new String[]{Manifest.permission.ACCESS_FINE_LOCATION},
                            LOCATION_REQUEST);
                }
            }

            @Override
            public boolean onShowFileChooser(WebView view, ValueCallback<Uri[]> callback,
                    FileChooserParams params) {
                if (pendingFileCallback != null) {
                    pendingFileCallback.onReceiveValue(null);
                }
                pendingFileCallback = callback;
                Intent intent = new Intent(Intent.ACTION_GET_CONTENT);
                intent.addCategory(Intent.CATEGORY_OPENABLE);
                intent.setType("*/*");
                try {
                    startActivityForResult(
                            Intent.createChooser(intent, getString(R.string.choose_file)),
                            FILE_CHOOSER_REQUEST);
                } catch (Exception e) {
                    pendingFileCallback = null;
                    return false;
                }
                return true;
            }
        });

        String url = prefs.getString("farm_url", null);
        if (url == null) {
            showFarmDialog(false);
        } else {
            webView.loadUrl(url);
        }
    }

    private void showFarmDialog(final boolean cancelable) {
        final EditText input = new EditText(this);
        input.setHint(R.string.farm_hint);
        input.setSingleLine(true);
        AlertDialog.Builder builder = new AlertDialog.Builder(this)
                .setTitle(R.string.farm_title)
                .setMessage(R.string.farm_message)
                .setView(input)
                .setCancelable(cancelable)
                .setPositiveButton(R.string.open_farm, (dialog, which) -> {
                    String name = input.getText().toString().trim().toLowerCase();
                    String url = name.isEmpty()
                            ? "https://" + BASE_DOMAIN + "/"
                            : "https://" + name + "." + BASE_DOMAIN + "/";
                    prefs.edit().putString("farm_url", url).apply();
                    webView.loadUrl(url);
                });
        if (cancelable) {
            builder.setNegativeButton(android.R.string.cancel, null);
        }
        builder.show();
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        menu.add(0, 1, 0, R.string.menu_refresh);
        menu.add(0, 2, 0, R.string.menu_change_farm);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        if (item.getItemId() == 1) {
            webView.reload();
            return true;
        }
        if (item.getItemId() == 2) {
            showFarmDialog(true);
            return true;
        }
        return super.onOptionsItemSelected(item);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == FILE_CHOOSER_REQUEST && pendingFileCallback != null) {
            Uri[] result = null;
            if (resultCode == RESULT_OK && data != null && data.getData() != null) {
                result = new Uri[]{data.getData()};
            }
            pendingFileCallback.onReceiveValue(result);
            pendingFileCallback = null;
            return;
        }
        super.onActivityResult(requestCode, resultCode, data);
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions,
            int[] grantResults) {
        if (requestCode == LOCATION_REQUEST && pendingGeoCallback != null) {
            boolean granted = grantResults.length > 0
                    && grantResults[0] == PackageManager.PERMISSION_GRANTED;
            pendingGeoCallback.invoke(pendingGeoOrigin, granted, granted);
            pendingGeoCallback = null;
            pendingGeoOrigin = null;
            return;
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
    }

    @Override
    public void onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack();
        } else {
            super.onBackPressed();
        }
    }
}
