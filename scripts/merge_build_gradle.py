"""
Dos ajustes que necesitan nuestros plugins en build.gradle (o
build.gradle.kts, según la versión de Flutter que lo haya generado):

1. device_calendar y flutter_local_notifications usan APIs de Java 8+
   que, con minSdk < 26, exigen "core library desugaring" activado.
   Sin esto, `flutter build apk` falla con:
       Dependency ':device_calendar' requires core library desugaring...

2. file_picker (por su dependencia flutter_plugin_android_lifecycle)
   exige compilar contra compileSdk 36 o superior. Sin esto falla con:
       :file_picker is currently compiled against android-34...
       Update this project to use a newer compileSdk of at least 36.

Este script aplica ambos ajustes automáticamente. Detecta el formato
(Groovy o Kotlin DSL) por la extensión del archivo que le pases.

Uso: python3 merge_build_gradle.py <ruta_build.gradle_o_.kts>
"""
import re
import sys

MIN_COMPILE_SDK = 36


def patch_compile_sdk_groovy(content: str) -> str:
    # Reemplaza "compileSdk flutter.compileSdkVersion" (o un número ya
    # puesto ahí) por un número fijo, para no depender de la versión
    # por defecto que traiga el Flutter usado en la compilación.
    if re.search(r"compileSdk\s+" + str(MIN_COMPILE_SDK) + r"\b", content):
        return content
    if re.search(r"compileSdk\s+flutter\.compileSdkVersion", content):
        return re.sub(
            r"compileSdk\s+flutter\.compileSdkVersion",
            f"compileSdk {MIN_COMPILE_SDK}",
            content,
            count=1,
        )
    if re.search(r"compileSdk(Version)?\s+\d+", content):
        return re.sub(
            r"compileSdk(Version)?\s+\d+",
            f"compileSdk {MIN_COMPILE_SDK}",
            content,
            count=1,
        )
    return content


def patch_compile_sdk_kotlin(content: str) -> str:
    if re.search(r"compileSdk\s*=\s*" + str(MIN_COMPILE_SDK) + r"\b", content):
        return content
    if re.search(r"compileSdk\s*=\s*flutter\.compileSdkVersion", content):
        return re.sub(
            r"compileSdk\s*=\s*flutter\.compileSdkVersion",
            f"compileSdk = {MIN_COMPILE_SDK}",
            content,
            count=1,
        )
    if re.search(r"compileSdk\s*=\s*\d+", content):
        return re.sub(
            r"compileSdk\s*=\s*\d+",
            f"compileSdk = {MIN_COMPILE_SDK}",
            content,
            count=1,
        )
    return content


def patch_groovy(content: str) -> str:
    content = patch_compile_sdk_groovy(content)

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
    content = patch_compile_sdk_kotlin(content)

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

    print(f"build.gradle actualizado (compileSdk {MIN_COMPILE_SDK} + desugaring): {path}")


if __name__ == "__main__":
    main()
