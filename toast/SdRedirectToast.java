// Copyright (C) 2026 FadedAtlas. Licensed under GPL-3.0 (see LICENSE), with an additional attribution
// term under section 7(b): see "Additional terms" in README.md.

import java.lang.reflect.Method;

/**
 * Shows an Android toast from a root shell:
 *   CLASSPATH=sd-redirect-toast.dex app_process /system/bin SdRedirectToast "message" [package]
 * With a package, "{app}" in the message is replaced by that app's label (the package name if it has none).
 *
 * Toast.show() can't be used: it enqueues under the context's package ("android", owned by uid 1000), and
 * NotificationManagerService rejects that from uid 0. Instead the text toast goes straight to
 * INotificationManager.enqueueTextToast as package "root", which the service accepts from uid 0 and
 * treats as a system toast. SystemUI draws it, so no looper or window is needed here.
 *
 * Everything goes through reflection so this compiles with a plain JDK (no android.jar).
 * Exits 0 after the toast was enqueued, 1 on any failure (the caller then posts a notification).
 */
public class SdRedirectToast {
    public static void main(String[] args) {
        try {
            String text = args.length > 0 ? args[0] : "SD Redirect";
            if (args.length > 1) text = text.replace("{app}", label(args[1]));

            Object nm = Class.forName("android.app.NotificationManager").getMethod("getService").invoke(null);
            Method enqueue = null;
            for (Method m : nm.getClass().getMethods())
                if (m.getName().equals("enqueueTextToast")) { enqueue = m; break; }
            if (enqueue == null) throw new NoSuchMethodException("INotificationManager.enqueueTextToast");

            // The signature differs between Android versions; fill the parameters by type:
            // 11: (String pkg, IBinder token, CharSequence text, int duration, int displayId, callback)
            // 12+: (String pkg, IBinder token, CharSequence text, int duration, boolean isUiContext, int displayId, callback)
            Class<?> binderCls = Class.forName("android.os.IBinder");
            Class<?>[] types = enqueue.getParameterTypes();
            Object[] a = new Object[types.length];
            int ints = 0;
            for (int i = 0; i < types.length; i++) {
                Class<?> t = types[i];
                if (t == String.class) a[i] = "root";
                else if (t == CharSequence.class) a[i] = text;
                else if (t == binderCls) a[i] = Class.forName("android.os.Binder").getConstructor().newInstance();
                else if (t == int.class) a[i] = ints++ == 0 ? 1 /* LENGTH_LONG */ : 0 /* DEFAULT_DISPLAY */;
                else if (t == boolean.class) a[i] = true;
                else a[i] = null;
            }
            enqueue.invoke(nm, a);

            // Stay alive while the toast is on screen, in case the service tracks the token's owner.
            Thread.sleep(4000);
            System.exit(0);
        } catch (Throwable t) {
            t.printStackTrace();
            System.exit(1);
        }
    }

    // The label the launcher shows for pkg; the package name if it can't be resolved.
    private static String label(String pkg) {
        try {
            Class<?> looperCls = Class.forName("android.os.Looper");
            looperCls.getMethod("prepareMainLooper").invoke(null);
            Class<?> atCls = Class.forName("android.app.ActivityThread");
            Object at = atCls.getMethod("systemMain").invoke(null);
            Object ctx = atCls.getMethod("getSystemContext").invoke(at);

            Object pm = ctx.getClass().getMethod("getPackageManager").invoke(ctx);
            Class<?> pmCls = Class.forName("android.content.pm.PackageManager");
            Class<?> aiCls = Class.forName("android.content.pm.ApplicationInfo");
            Object ai = pmCls.getMethod("getApplicationInfo", String.class, int.class).invoke(pm, pkg, 0);
            Object l = pmCls.getMethod("getApplicationLabel", aiCls).invoke(pm, ai);
            return l != null ? l.toString() : pkg;
        } catch (Throwable t) {
            return pkg;
        }
    }
}
