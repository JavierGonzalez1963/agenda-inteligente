"""
device_calendar y flutter_local_notifications usan APIs de Java 8+ que,
en Android con minSdk < 26, exigen "core library desugaring" activado.
Sin esto, `flutter build apk` falla con un error del estilo:

    Dependency ':device_calendar' requires core library desugaring to
    be enabled for :app.

Este script activa esa opción automáticamente en el build.gradle (o
build.gradle.kts, según la versión de Flutter que lo haya generado) y
agrega la dependencia de desugaring. Detecta el formato por la
extensión del archivo que le pases y usa la sintaxis correcta.

Uso: python3 merge_build_gradle.py <ruta_build.gradle_o_.kts>
"""
import re
import sys


def patch_groovy(content: str) -> str:
    if "coreLibraryDesugaringEnabled" not in content:
        if "compileOptions" in content:
            content = re.sub(
                r"(compileOptions\s*\{)",
                r"\1\n        coreLibraryDesugaringEnabled true",
                content,
                count=1,
            )
        else:
            content = re.sub(
                r"(android\s*\{)",
                r"\1\n    compileOptions {\n"
                r"        coreLibraryDesugaringEnabled true\n"
                r"        sourceCompatibility JavaVersion.VERSION_1_8\n"
                r"        targetCompatibility JavaVersion.VERSION_1_8\n"
                r"    }",
                content,
                count=1,
            )

    if "desugar_jdk_libs" not in content:
        dep_line = "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'"
        match = re.search(r"\ndependencies\s*\{", content)
        if match:
            insert_at = match.end()
            content = content[:insert_at] + f"\n    {dep_line}" + content[insert_at:]
        else:
            content += f"\n\ndependencies {{\n    {dep_line}\n}}\n"
    return content


def patch_kotlin(content: str) -> str:
    if "isCoreLibraryDesugaringEnabled" not in content:
        if "compileOptions" in content:
            content = re.sub(
                r"(compileOptions\s*\{)",
                r"\1\n        isCoreLibraryDesugaringEnabled = true",
                content,
                count=1,
            )
        else:
            content = re.sub(
                r"(android\s*\{)",
                r"\1\n    compileOptions {\n"
                r"        isCoreLibraryDesugaringEnabled = true\n"
                r"        sourceCompatibility = JavaVersion.VERSION_1_8\n"
                r"        targetCompatibility = JavaVersion.VERSION_1_8\n"
                r"    }",
                content,
                count=1,
            )

    if "desugar_jdk_libs" not in content:
        dep_line = 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")'
        match = re.search(r"\ndependencies\s*\{", content)
        if match:
            insert_at = match.end()
            content = content[:insert_at] + f"\n    {dep_line}" + content[insert_at:]
        else:
            content += f"\n\ndependencies {{\n    {dep_line}\n}}\n"
    return content


def main():
    path = sys.argv[1]
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    if path.endswith(".kts"):
        content = patch_kotlin(content)
    else:
        content = patch_groovy(content)

    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

    print(f"build.gradle actualizado con core library desugaring: {path}")


if __name__ == "__main__":
    main()
