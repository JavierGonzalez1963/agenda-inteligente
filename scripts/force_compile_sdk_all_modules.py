"""
El error ":file_picker is currently compiled against android-34" no
se arregla cambiando el build.gradle de TU app -- viene de la propia
configuración interna del plugin file_picker (dentro de su código
fuente, fuera de este repositorio).

La solución estándar de la comunidad Flutter para este tipo de
choques entre plugins es forzar un mismo compileSdk para TODOS los
módulos del proyecto (el tuyo y los de cada plugin), agregando un
bloque "subprojects" en el build.gradle raíz de android/ (un nivel
arriba del de app/).

Usamos plugins.withId(...) en vez de afterEvaluate: el propio
build.gradle.kts que genera Flutter ya fuerza una evaluación
temprana de ":app" (con evaluationDependsOn), lo que hace fallar a
afterEvaluate con "project is already evaluated". plugins.withId
se dispara en el momento en que el plugin de Android se aplica,
sin depender de ese orden de evaluación.

Uso: python3 force_compile_sdk_all_modules.py <ruta_carpeta_android>
"""
import sys
import os

MARKER = "force_compile_sdk_all_modules"
COMPILE_SDK = 36

GROOVY_BLOCK = f"""
// {MARKER}: fuerza compileSdk {COMPILE_SDK} en todos los módulos
// (incluidos los de los plugins) para evitar choques de versión
// entre distintos plugins de Flutter.
subprojects {{
    plugins.withId("com.android.library") {{
        android {{
            compileSdkVersion {COMPILE_SDK}
        }}
    }}
    plugins.withId("com.android.application") {{
        android {{
            compileSdkVersion {COMPILE_SDK}
        }}
    }}
}}
"""

KOTLIN_BLOCK = f"""
// {MARKER}: fuerza compileSdk {COMPILE_SDK} en todos los módulos
// (incluidos los de los plugins) para evitar choques de versión
// entre distintos plugins de Flutter.
subprojects {{
    plugins.withId("com.android.library") {{
        extensions.configure<com.android.build.gradle.LibraryExtension> {{
            compileSdk = {COMPILE_SDK}
        }}
    }}
    plugins.withId("com.android.application") {{
        extensions.configure<com.android.build.gradle.BaseExtension> {{
            compileSdkVersion({COMPILE_SDK})
        }}
    }}
}}
"""


def main():
    android_dir = sys.argv[1]  # ej: app/android
    kts_path = os.path.join(android_dir, "build.gradle.kts")
    groovy_path = os.path.join(android_dir, "build.gradle")

    if os.path.exists(kts_path):
        path, block = kts_path, KOTLIN_BLOCK
    elif os.path.exists(groovy_path):
        path, block = groovy_path, GROOVY_BLOCK
    else:
        print(f"No se encontró build.gradle ni build.gradle.kts en {android_dir}")
        sys.exit(1)

    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # Si ya existe una versión anterior (con afterEvaluate) de este bloque,
    # la quitamos para no dejar dos versiones conflictivas.
    if MARKER in content:
        start = content.find(f"\n// {MARKER}")
        if start != -1:
            content = content[:start].rstrip() + "\n"

    content += "\n" + block
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Bloque de compileSdk global (plugins.withId) agregado a: {path}")


if __name__ == "__main__":
    main()
