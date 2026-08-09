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
    afterEvaluate {{ proj ->
        if (proj.plugins.hasPlugin("com.android.library") || proj.plugins.hasPlugin("com.android.application")) {{
            proj.android {{
                compileSdkVersion {COMPILE_SDK}
            }}
        }}
    }}
}}
"""

KOTLIN_BLOCK = f"""
// {MARKER}: fuerza compileSdk {COMPILE_SDK} en todos los módulos
// (incluidos los de los plugins) para evitar choques de versión
// entre distintos plugins de Flutter.
subprojects {{
    afterEvaluate {{
        if (project.plugins.hasPlugin("com.android.application") || project.plugins.hasPlugin("com.android.library")) {{
            project.extensions.configure<com.android.build.gradle.BaseExtension> {{
                compileSdkVersion({COMPILE_SDK})
            }}
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

    if MARKER not in content:
        content += "\n" + block
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"Bloque de compileSdk global agregado a: {path}")
    else:
        print(f"Ya estaba agregado en: {path}")


if __name__ == "__main__":
    main()
