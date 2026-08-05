"""
Inserta los permisos y receivers necesarios dentro del AndroidManifest.xml
que genera `flutter create`. Lo ejecuta automáticamente el workflow de
GitHub Actions — no necesitas correrlo tú mismo a mano.

Uso: python3 merge_manifest.py <ruta_manifest_generado>
"""
import sys

PERMISSIONS = """
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
    <uses-permission android:name="android.permission.USE_EXACT_ALARM" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.READ_CALENDAR" />
    <uses-permission android:name="android.permission.WRITE_CALENDAR" />
"""

RECEIVERS = """
        <receiver
            android:name="dev.fluttercommunity.plus.androidalarmmanager.AlarmBroadcastReceiver"
            android:exported="false" />
        <receiver
            android:name="dev.fluttercommunity.plus.androidalarmmanager.RebootBroadcastReceiver"
            android:enabled="false"
            android:exported="false">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
            </intent-filter>
        </receiver>
"""


def main():
    path = sys.argv[1]
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    if "RECORD_AUDIO" not in content:
        content = content.replace("<application", PERMISSIONS + "\n    <application", 1)

    if "AlarmBroadcastReceiver" not in content:
        content = content.replace("</application>", RECEIVERS + "\n    </application>", 1)

    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

    print(f"Manifest actualizado: {path}")


if __name__ == "__main__":
    main()
