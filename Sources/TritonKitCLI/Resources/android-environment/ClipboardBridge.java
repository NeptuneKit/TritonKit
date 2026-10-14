import java.lang.reflect.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.Base64;

/** Runs as uid shell through app_process. No installed APK or business SDK.
 * IClipboard signatures vary by Android version. Resolve named methods and
 * synthesize only the documented shell package/attribution/user/device fields.
 * Unknown parameter shapes fail closed instead of guessing Binder transaction IDs.
 */
public final class ClipboardBridge {
    public static void main(String[] args) {
        try {
            if (args.length != 1 || !(args[0].equals("get") || args[0].equals("set"))) throw new Exception("invalid_operation");
            Class<?> binder = Class.forName("android.os.IBinder");
            Object raw = Class.forName("android.os.ServiceManager").getMethod("getService", String.class).invoke(null, "clipboard");
            Object service = Class.forName("android.content.IClipboard$Stub").getMethod("asInterface", binder).invoke(null, raw);
            int user = 0; // shell helper targets the owner profile; Binder API differs across API levels
            Object clip = null;
            if (args[0].equals("set")) {
                ByteArrayOutputStream bytes = new ByteArrayOutputStream();
                byte[] buffer = new byte[4096]; int n;
                while ((n = System.in.read(buffer)) != -1) { bytes.write(buffer, 0, n); if (bytes.size() > 65536) throw new Exception("text_too_large"); }
                clip = Class.forName("android.content.ClipData").getMethod("newPlainText", CharSequence.class, CharSequence.class).invoke(null, "Triton", new String(bytes.toByteArray(), StandardCharsets.UTF_8));
                invoke(service, "setPrimaryClip", clip, user);
            }
            Object current = invoke(service, "getPrimaryClip", null, user);
            String text = "";
            if (current != null) {
                Object item = current.getClass().getMethod("getItemAt", int.class).invoke(current, 0);
                Object value = item.getClass().getMethod("getText").invoke(item);
                if (value == null) throw new Exception("non_text_clipboard");
                text = value.toString();
            }
            if (text.getBytes(StandardCharsets.UTF_8).length > 65536) throw new Exception("text_too_large");
            System.out.println("TRITON_CLIPBOARD:" + Base64.getEncoder().encodeToString(text.getBytes(StandardCharsets.UTF_8)));
        } catch (Throwable error) {
            // Never print Binder exceptions, clipboard data, package IDs or stack traces.
            System.err.println("TRITON_CLIPBOARD_ERROR:unsupported_or_denied");
            System.exit(1);
        }
    }
    private static Object invoke(Object service, String name, Object clip, int user) throws Exception {
        for (Method method : Class.forName("android.content.IClipboard").getMethods()) {
            if (!method.getName().equals(name)) continue;
            Class<?>[] types = method.getParameterTypes();
            Object[] values = new Object[types.length];
            int strings = 0, ints = 0; boolean supported = true;
            for (int i = 0; i < types.length; i++) {
                if (types[i].getName().equals("android.content.ClipData")) values[i] = clip;
                else if (types[i] == String.class) values[i] = strings++ == 0 ? "com.android.shell" : null;
                else if (types[i] == int.class) values[i] = ints++ == 0 ? user : 0;
                else { supported = false; break; }
            }
            if (!supported || strings < 1 || strings > 2 || ints > 2) continue;
            return method.invoke(service, values);
        }
        throw new Exception("unsupported_signature");
    }
}
