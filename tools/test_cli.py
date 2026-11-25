"""Exercise the installed command, optionally against an installed XXTColorPicker."""
import argparse
import json
import subprocess
import tempfile
from pathlib import Path

from test_images import verify_images

skill = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--host", help="auto, application directory, or a compatible application JAR")
args = parser.parse_args()
cli = ["java", "-jar", str(skill / "picker-format.jar")]


def run(*options, expected=0):
    p = subprocess.run(cli + list(map(str, options)), capture_output=True, text=True, timeout=155)
    if p.returncode != expected:
        raise AssertionError(f"{options} exited {p.returncode}, expected {expected}\n{p.stdout}\n{p.stderr}")
    return p.stdout + p.stderr


def write_case(path, **values):
    path.write_text(json.dumps(values, ensure_ascii=False), encoding="utf-8")


with tempfile.TemporaryDirectory(prefix="format-cli-test-") as temp:
    work = Path(temp)
    # The filename also exists inside the app. A failed reload must not validate the packaged copy.
    script = work / "X_Y_Color.lua"
    case = work / "sample.json"
    run("new", script, "--name", '引号"\\与中文')
    starter = script.read_text(encoding="utf-8")
    run("new", script, "--name", "另一格式", expected=1)
    assert script.read_text(encoding="utf-8") == starter
    write_case(case, points=[[100, 50, "0x00000A"]], expect={"rows": [["{{100, 50, 0x00000A}}"]]})
    run("check", script, "--case", case)
    if args.host:
        run("check", script, "--case", case, "--host", args.host)
    for body, field in [
        ("return !!!", "X_Y_Color.lua"),
        (starter.replace("args = {}", "wrong = {}"), "settingsRule.args"),
        (starter.replace('return pointLiteral(p) .. ",\\n"', "pointLiteral(p)"), "multiPosFormatRule"),
    ]:
        script.write_text(body, encoding="utf-8")
        result = run("check", script, "--case", case, expected=1)
        assert field in result, result
        if args.host and body == "return !!!":
            result = run("check", script, "--case", case, "--host", args.host, expected=1)
            assert "X_Y_Color.lua" in result and "hostLog" in result, result

    script.write_text(starter, encoding="utf-8")
    write_case(case, points=[], expect={"rows": [["wrong"]]})
    result = run("check", script, "--case", case, expected=1)
    assert "makeScriptRules[1]" in result and "wrong" in result and "{}" in result, result
    script.write_text(starter.replace('return "{" .. table.concat(points, ", ") .. "}"',
                                      'alertInfo("请选文件"); return "done"'), encoding="utf-8")
    write_case(case, points=[])
    result = run("check", script, "--case", case, expected=2)
    assert "alertInfo" in result and "unverified" in result, result
    if args.host:
        script.write_text(starter.replace('return "{" .. table.concat(points, ", ") .. "}"',
                                          'local w=getImageSize(); return tostring(w)'), encoding="utf-8")
        result = run("check", script, "--case", case, "--host", args.host, expected=2)
        assert "getImageSize" in result and "仅覆盖无图行为" in result, result
    print("Creation, overwrite protection, malformed module, error location, output mismatch and incomplete coverage passed")

    sample = skill / "examples/relative-points.lua"
    cases = skill / "examples/relative-points.json"
    run("check", sample, "--case", cases)
    if args.host:
        run("check", sample, "--case", cases, "--host", args.host)
    print("Empty and relative coordinates, settings, hover, clipboard, multi-column output, dynamic menu and double-click passed")

    verify_images(work, cli, args.host)
    print("Threshold, Otsu, color offset, foreground polarity and all three similarity algorithms passed")
