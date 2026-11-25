package picker;

import org.json.*;
import org.luaj.vm2.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.TimeUnit;
import java.util.stream.Stream;

public class PickerFormat {
    static final String USAGE = "java -jar picker-format.jar new FILE.lua --name NAME\n"
            + "java -jar picker-format.jar check FILE.lua [--case CASE.json] [--host auto|APP|JAR]";
    static String read(Path p) throws IOException {
        return new String(Files.readAllBytes(p), StandardCharsets.UTF_8);
    }
    static String resource(String path) throws IOException {
        try (InputStream in = PickerFormat.class.getResourceAsStream("/pickerdata/" + path)) {
            if (in == null) throw new IOException("缺少工具资源 " + path);
            ByteArrayOutputStream bytes = new ByteArrayOutputStream();
            byte[] buf = new byte[8192];
            int count;
            while ((count = in.read(buf)) != -1) bytes.write(buf, 0, count);
            return new String(bytes.toByteArray(), StandardCharsets.UTF_8);
        }
    }
    static String literal(String text) {
        StringBuilder s = new StringBuilder("\"");
        for (char c : text.toCharArray()) {
            if (c == '"' || c == '\\') s.append('\\');
            if (c < 32 || c == 127) s.append(String.format("\\%03d", (int)c));
            else s.append(c);
        }
        return s.append('"').toString();
    }
    static LuaValue lua(Object obj) {
        if (obj instanceof JSONObject) {
            LuaTable t = new LuaTable();
            JSONObject o = (JSONObject)obj;
            for (String k : o.keySet()) t.set(k, lua(o.get(k)));
            return t;
        }
        if (obj instanceof JSONArray) {
            LuaTable t = new LuaTable();
            JSONArray a = (JSONArray)obj;
            for (int i = 0; i < a.length(); i++) t.set(i+1, lua(a.get(i)));
            return t;
        }
        if (obj instanceof Number) return LuaValue.valueOf(((Number)obj).doubleValue());
        if (obj instanceof Boolean) return LuaValue.valueOf((Boolean)obj);
        if (obj instanceof String) return LuaValue.valueOf((String)obj);
        throw new IllegalArgumentException("样例不支持 null");
    }
    static Object json(LuaValue value) {
        if (value.istable()) {
            JSONArray a = new JSONArray();
            for (int i = 1; i <= value.length(); i++) a.put(json(value.get(i)));
            return a;
        }
        if (value.type() == LuaValue.TSTRING) return value.tojstring();
        if (value.isboolean()) return value.toboolean();
        if (value.isnumber()) return value.todouble();
        throw new IllegalArgumentException("无法显示结果 " + value.typename());
    }
    static JSONObject report(LuaValue table) {
        JSONObject out = new JSONObject();
        for (LuaValue key : table.checktable().keys()) out.put(key.checkjstring(), json(table.get(key)));
        return out;
    }
    static void keys(JSONObject object, String... names) {
        Set<String> allowed = new HashSet<>(Arrays.asList(names));
        for (String key : object.keySet()) if (!allowed.contains(key))
            throw new IllegalArgumentException("未知样例字段 " + key);
    }
    static int integer(Object value, String field) {
        if (!(value instanceof Number) || ((Number)value).doubleValue() != ((Number)value).intValue())
            throw new IllegalArgumentException(field + " 需要整数");
        return ((Number)value).intValue();
    }
    static void coordinates(JSONArray a, boolean color) {
        if (a.length() != (color ? 3 : 2)) throw new IllegalArgumentException("坐标字段数错误 " + a);
        integer(a.get(0), "x"); integer(a.get(1), "y");
        if (color) {
            Object v = a.get(2);
            if (v instanceof String && ((String)v).matches("0[xX][0-9A-Fa-f]{1,6}"))
                v = Integer.parseInt(((String)v).substring(2), 16);
            int rgb = integer(v, "RGB");
            if (rgb < 0 || rgb > 0xffffff) throw new IllegalArgumentException("RGB 超出 24 位范围");
            a.put(2, rgb);
        }
    }
    static void validateCase(JSONObject c) {
        keys(c, "name", "points", "regions", "settings", "hover", "actions", "expect");
        JSONArray points = c.getJSONArray("points");
        for (int i=0; i<points.length(); i++) coordinates(points.getJSONArray(i), true);
        if (c.has("hover")) coordinates(c.getJSONArray("hover"), true);
        if (c.has("regions")) {
            JSONObject r = c.getJSONObject("regions");
            keys(r, "a", "s", "x", "c");
            for (String k : r.keySet()) coordinates(r.getJSONArray(k), false);
        }
        if (c.has("name")) c.getString("name");
        if (c.has("settings")) c.getJSONObject("settings");
        if (c.has("expect")) keys(c.getJSONObject("expect"), "picked", "pickClipboard", "rows",
                "generateClipboard", "menus", "afterRows", "clipboard", "hoverBottom", "hoverZoom");
        if (c.has("actions")) {
            JSONArray actions = c.getJSONArray("actions");
            for (int i=0; i<actions.length(); i++) {
                JSONObject a = actions.getJSONObject(i);
                keys(a, "type", "row", "item");
                String type = a.getString("type");
                if (!(type.equals("menu") || type.equals("doubleClick"))) throw new IllegalArgumentException("未知动作 " + type);
                if (integer(a.get("row"), "row") < 1) throw new IllegalArgumentException("row 从 1 开始");
                if (a.has("item") && (!type.equals("menu") || integer(a.get("item"), "item") < 1))
                    throw new IllegalArgumentException("item 是菜单项序号，从 1 开始");
            }
        }
    }
    static Path hostJar(String option) throws IOException {
        List<Path> choices = new ArrayList<>();
        if ("auto".equals(option)) {
            String env = System.getenv("XXTCOLORPICKER_JAR");
            if (env != null) choices.add(Paths.get(env));
            choices.add(Paths.get("/Applications/XXTColorPicker.app"));
            choices.add(Paths.get(System.getProperty("user.home"), "Applications/XXTColorPicker.app"));
            for (String variable : Arrays.asList("ProgramFiles", "LOCALAPPDATA")) {
                String base = System.getenv(variable);
                if (base != null) choices.add(Paths.get(base, "XXTColorPicker"));
            }
            choices.add(Paths.get("XXTColorPicker.jar"));
            choices.add(Paths.get("out/artifacts/XXTColorPicker/XXTColorPicker.jar"));
        } else choices.add(Paths.get(option));
        for (Path p : choices) {
            if (Files.isDirectory(p)) {
                for (String sub : Arrays.asList("Contents/Resources/Java/XXTColorPicker.jar","XXTColorPicker.jar","app/XXTColorPicker.jar"))
                    if (Files.isRegularFile(p.resolve(sub))) return p.resolve(sub).toRealPath();
            } else if (Files.isRegularFile(p)) return p.toRealPath();
        }
        throw new IOException("未找到 XXTColorPicker，请用 --host 指定 .app 或 JAR 路径");
    }
    static String callbackFor(String key, Object wanted, Object got, JSONObject fixture) {
        if (key.equals("hoverBottom")) return "mouseTrackInfoBottomRule";
        if (key.equals("hoverZoom")) return "mouseTrackInfoZoomRule";
        if (key.equals("picked") || key.equals("pickClipboard")) return "multiPosFormatRule";
        if (key.equals("generateClipboard")) return "makeScriptRules[1]";
        if (key.equals("rows") && wanted instanceof JSONArray && got instanceof JSONArray) {
            JSONArray a=(JSONArray)wanted, b=(JSONArray)got;
            int i=0;
            while (i<Math.min(a.length(),b.length()) && a.optJSONArray(i)!=null && a.getJSONArray(i).similar(b.opt(i))) i++;
            return "makeScriptRules[" + (i+1) + "]";
        }
        if (fixture.has("actions")) return "结果行交互 " + fixture.getJSONArray("actions");
        return "makeScriptRules";
    }
    static int check(Path file, JSONObject c, Path host) throws Exception {
        validateCase(c);
        Path tmp = Files.createTempDirectory("picker-format-");
        try {
            Path tool = Paths.get(PickerFormat.class.getProtectionDomain().getCodeSource().getLocation().toURI());
            String cp = tool.toString();
            List<String> args = new ArrayList<>();
            args.add(Paths.get(System.getProperty("java.home"),"bin","java").toString());
            if (host != null) {
                cp = host + File.pathSeparator + cp;
                Path projectLib = host.getParent().resolve("../../../lib").normalize();
                if (Files.isDirectory(projectLib)) cp += File.pathSeparator + projectLib.resolve("*");
                cp += File.pathSeparator + host.getParent().resolve("lib/*");
                if (!System.getProperty("java.specification.version").startsWith("1.")) {
                    String os = System.getProperty("os.name");
                    String toolkit = os.startsWith("Mac") ? "sun.lwawt" : os.startsWith("Windows") ? "sun.awt.windows" : "sun.awt.X11";
                    args.add("--add-opens=java.desktop/" + toolkit + "=ALL-UNNAMED");
                    args.add("--add-opens=java.desktop/sun.awt=ALL-UNNAMED");
                }
            }
            args.addAll(Arrays.asList("-Dfile.encoding=UTF-8","-Djava.io.tmpdir="+tmp,"-cp", cp,
                    host == null ? "picker.Standalone" : "picker.HostProbe", file.toString()));
            Files.write(tmp.resolve("case.json"), c.toString().getBytes(StandardCharsets.UTF_8));
            Path log = tmp.resolve("worker.log");
            Process p = new ProcessBuilder(args).directory(tmp.toFile()).redirectErrorStream(true).redirectOutput(log.toFile()).start();
            if (!p.waitFor(host == null ? 20 : 45, TimeUnit.SECONDS)) {
                p.destroyForcibly().waitFor();
                System.err.println("未验证：执行超时，可能有阻塞或等待输入的窗口。"); return 2;
            }
            Path output = tmp.resolve("report.json");
            if (!Files.exists(output)) {
                if (host == null) throw new IOException("验证进程未完成\n" + read(log));
                System.err.println("未验证：宿主进程未能完成检查\n" + read(log));
                return 2;
            }
            JSONObject r = new JSONObject(read(output));
            System.out.println(r.toString(2));
            JSONArray errors = r.optJSONArray("errors"), skipped = r.optJSONArray("unverified");
            int status = errors != null && errors.length()>0 ? 1 : skipped != null && skipped.length()>0 ? 2 : p.exitValue();
            if (errors != null && errors.length()>0) System.err.println("出错样例 " + c);
            JSONObject expected = c.optJSONObject("expect");
            if (expected != null) for (String k : expected.keySet()) {
                if (!r.has(k) && skipped != null && skipped.length()>0) {
                    System.err.println("未验证期望字段 " + k);
                    continue;
                }
                Object want = expected.get(k), got = r.opt(k);
                if (want instanceof JSONArray ? !(got instanceof JSONArray && ((JSONArray)want).similar(got)) : !want.equals(got)) {
                    System.err.println(file + " " + callbackFor(k,want,got,c) + " · " + k + " 不匹配\n输入 " + c + "\n期望 " + JSONObject.valueToString(want)
                            + "\n实际 " + (got == null ? "（无结果）" : JSONObject.valueToString(got)));
                    status = 1;
                }
            }
            return status;
        } finally {
            try (Stream<Path> children = Files.walk(tmp)) {
                for (Path p : (Iterable<Path>)children.sorted(Comparator.reverseOrder())::iterator) Files.deleteIfExists(p);
            }
        }
    }
    static void saveReport(JSONObject r) throws IOException {
        Files.write(Paths.get("report.json"), r.toString().getBytes(StandardCharsets.UTF_8));
    }
    static int run(String[] args) throws Exception {
        if (args.length == 0 || "--help".equals(args[0])) { System.out.println(USAGE); return 0; }
        if (args.length < 2) throw new IllegalArgumentException(USAGE);
        Path file = Paths.get(args[1]).toAbsolutePath().normalize();
        if (!file.getFileName().toString().endsWith(".lua")) throw new IllegalArgumentException("格式文件扩展名应为 .lua");
        if (args[0].equals("new")) {
            if (args.length != 4 || !args[2].equals("--name") || args[3].trim().isEmpty()) throw new IllegalArgumentException(USAGE);
            String template = resource("point-list.lua");
            String text = template.replace("\"Lua 点色列表设置\"", literal(args[3]+"设置"));
            int pos = text.indexOf("name = \"Lua 点色列表\"");
            text = text.substring(0,pos) + "name = " + literal(args[3]) + text.substring(pos+"name = \"Lua 点色列表\"".length());
            Files.createDirectories(file.getParent());
            Files.write(file, text.getBytes(StandardCharsets.UTF_8), StandardOpenOption.CREATE_NEW);
            System.out.println(file); return 0;
        }
        if (!args[0].equals("check")) throw new IllegalArgumentException(USAGE);
        file = file.toRealPath();
        Path host = null, fixture = null;
        for (int i=2;i<args.length;i+=2) {
            if (i+1 == args.length) throw new IllegalArgumentException(USAGE);
            if (args[i].equals("--case")) fixture = Paths.get(args[i+1]);
            else if (args[i].equals("--host")) {
                try { host = hostJar(args[i+1]); }
                catch (IOException e) { System.err.println("未验证：" + e.getMessage()); return 2; }
            }
            else throw new IllegalArgumentException(USAGE);
        }
        String raw = fixture == null ? resource("default-cases.json") : read(fixture);
        JSONTokener tokener = new JSONTokener(raw);
        Object data = tokener.nextValue();
        if (tokener.nextClean() != 0 || !(data instanceof JSONObject || data instanceof JSONArray))
            throw new IllegalArgumentException("样例必须是 JSON 对象或对象数组");
        JSONArray cases = data instanceof JSONObject ? new JSONArray().put(data) : (JSONArray)data;
        if (cases.length()==0) throw new IllegalArgumentException("样例数组为空");
        int status = 0;
        for (int i=0; i<cases.length(); i++) {
            JSONObject c = cases.getJSONObject(i);
            System.out.println((host == null ? "独立 LuaJ" : "真实宿主 " + host) + " · " + file + " · " + c.optString("name", ""+(i+1)));
            int result = check(file,c,host);
            if (result == 1 || status == 0) status = result;
        }
        return status;
    }
    public static void main(String[] args) {
        try { System.exit(run(args)); }
        catch (FileAlreadyExistsException e) { System.err.println("文件已存在：" + e.getFile()); System.exit(1); }
        catch (Exception e) { System.err.println(e.toString()); System.exit(1); }
    }
}
