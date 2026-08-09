"""
Bug conocido y documentado de device_calendar: al compilar en modo
release, R8 (el optimizador de código de Android) borra los campos
como "id" y "name" de los calendarios antes de que lleguen a la app
-- por eso retrieveCalendars() encuentra los calendarios pero todos
sus campos llegan en null. La solución oficial (documentada en
pub.dev/packages/device_calendar) es agregar una regla de ProGuard
que le diga a R8 que no toque esas clases.

Este script:
1. Crea/actualiza android/app/proguard-rules.pro con las reglas.
2. Se asegura de que build.gradle (o .kts) haga referencia a ese
   archivo dentro del bloque release, activando minificación con
   las reglas de por medio.

Uso: python3 add_proguard_rules.py <ruta_carpeta_android/app>
"""
import re
import sys
import os

PROGUARD_RULES = """# device_calendar: evita que R8 borre o renombre los campos usados
# para leer los calendarios y eventos del teléfono. Sin esto,
# retrieveCalendars() devuelve calendarios con id y nombre en null
# en las compilaciones release. Ver: https://pub.dev/packages/device_calendar
-keep class com.builttoroam.devicecalendar.** { *; }

# flutter_local_notifications: mantiene intactas las clases nativas
# de notificaciones programadas en segundo plano.
-keep class com.dexterous.** { *; }

# speech_to_text: mantiene intactas las clases nativas del
# reconocimiento de voz.
-keep class com.csdcorp.speech_to_text.** { *; }
"""


def ensure_proguard_file(android_app_dir: str):
    path = os.path.join(android_app_dir, "proguard-rules.pro")
    existing = ""
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            existing = f.read()
    if "com.builttoroam.devicecalendar" not in existing:
        with open(path, "a", encoding="utf-8") as f:
            f.write("\n" + PROGUARD_RULES)
    print(f"proguard-rules.pro listo: {path}")


def patch_groovy(content: str) -> str:
    if "proguard-rules.pro" in content:
        return content
    pattern = re.compile(r"(release\s*\{)")
    return pattern.sub(
        r"\1\n            minifyEnabled true\n"
        r"            shrinkResources true\n"
        r"            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'",
        content,
        count=1,
    )


def patch_kotlin(content: str) -> str:
    if "proguard-rules.pro" in content:
        return content
    pattern = re.compile(r"(release\s*\{)")
    return pattern.sub(
        r"\1\n            isMinifyEnabled = true\n"
        r"            isShrinkResources = true\n"
        r'            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")',
        content,
        count=1,
    )


def main():
    android_app_dir = sys.argv[1]  # ej: app/android/app
    ensure_proguard_file(android_app_dir)

    kts_path = os.path.join(android_app_dir, "build.gradle.kts")
    groovy_path = os.path.join(android_app_dir, "build.gradle")

    if os.path.exists(kts_path):
        build_path = kts_path
        patcher = patch_kotlin
    else:
        build_path = groovy_path
        patcher = patch_groovy

    with open(build_path, "r", encoding="utf-8") as f:
        content = f.read()
    content = patcher(content)
    with open(build_path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"build.gradle actualizado para usar proguard-rules.pro: {build_path}")


if __name__ == "__main__":
    main()
