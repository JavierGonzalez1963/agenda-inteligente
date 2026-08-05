"""
device_calendar y flutter_local_notifications usan APIs de Java 8+ que,
en Android con minSdk < 26, exigen "core library desugaring" activado.
Sin esto, `flutter build apk` falla con un error del estilo:

    Dependency ':device_calendar' requires core library desugaring to
    be enabled for :app.

Este script activa esa opción automáticamente en el build.gradle que
genera `flutter create`, y agrega la dependencia de desugaring.
Lo ejecuta el workflow de GitHub Actions — no necesitas correrlo a mano.

Uso: python3 merge_build_gradle.py <ruta_build.gradle>
"""
import re
import sys

DESUGAR_DEP = "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'"


def ensure_compile_options(content: str) -> str:
    if "coreLibraryDesugaringEnabled" in content:
        return content  # ya estaba activado

    if "compileOptions" in content:
        # Inserta la línea dentro del primer bloque compileOptions { ... }
        pattern = re.compile(r"(compileOptions\s*\{)")
        content = pattern.sub(
            r"\1\n        coreLibraryDesugaringEnabled true",
            content,
            count=1,
        )
    else:
        # No existe el bloque: lo crea dentro de android { ... }
        pattern = re.compile(r"(android\s*\{)")
        content = pattern.sub(
            r"\1\n    compileOptions {\n"
            r"        coreLibraryDesugaringEnabled true\n"
            r"        sourceCompatibility JavaVersion.VERSION_1_8\n"
            r"        targetCompatibility JavaVersion.VERSION_1_8\n"
            r"    }",
            content,
            count=1,
        )
    return content


def ensure_desugar_dependency(content: str) -> str:
    if "desugar_jdk_libs" in content:
        return content  # ya estaba agregada

    # Busca un bloque dependencies { ... } de nivel superior (no el "android {}")
    match = re.search(r"\ndependencies\s*\{", content)
    if match:
        insert_at = match.end()
        content = content[:insert_at] + f"\n    {DESUGAR_DEP}" + content[insert_at:]
    else:
        content += f"\n\ndependencies {{\n    {DESUGAR_DEP}\n}}\n"
    return content


def main():
    path = sys.argv[1]
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    content = ensure_compile_options(content)
    content = ensure_desugar_dependency(content)

    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

    print(f"build.gradle actualizado con core library desugaring: {path}")


if __name__ == "__main__":
    main()
