"""Build the Java 8 CLI against a matching XXTColorPicker application JAR and source checkout."""
import argparse
from pathlib import Path
import subprocess
import tempfile
from zipfile import ZipFile, ZIP_DEFLATED

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("repo", type=Path)
parser.add_argument("host_jar", type=Path)
args = parser.parse_args()
tools = Path(__file__).resolve().parent
skill = tools.parent
with tempfile.TemporaryDirectory() as temp:
    out = Path(temp)
    subprocess.run(["javac", "--release", "8", "-encoding", "UTF-8", "-cp", str(args.host_jar),
                    "-d", str(out), *map(str, sorted((tools / "src").rglob("*.java")))], check=True)
    built = out / "picker-format.jar"
    with ZipFile(built, "w", compression=ZIP_DEFLATED) as jar, ZipFile(args.host_jar) as host:
        jar.writestr("META-INF/MANIFEST.MF", "Manifest-Version: 1.0\r\nMain-Class: picker.PickerFormat\r\n\r\n")
        for name in host.namelist():
            if name.startswith(("org/luaj/", "org/json/")) and name.endswith(".class"):
                jar.writestr(name, host.read(name))
        for f in out.rglob("*.class"):
            jar.write(f, f.relative_to(out).as_posix())
        for f in (tools / "lua").iterdir():
            jar.write(f, "pickerdata/" + f.name)
        jar.write(skill / "assets/point-list.lua", "pickerdata/point-list.lua")
        jar.writestr("pickerdata/compat.lua", host.read("scripts/colorpicker/customformats.lua"))
        for name, source in [("LuaJ", "org/luaj/vm2/Lua.java"), ("JSON", "org/json/JSONObject.java")]:
            text = (args.repo / "src" / source).read_text()
            jar.writestr("META-INF/licenses/" + name + ".txt", text[text.index("/*"):text.index("*/")+2])
    (skill / "picker-format.jar").write_bytes(built.read_bytes())
