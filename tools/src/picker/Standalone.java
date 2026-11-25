package picker;

import java.nio.file.*;
import org.luaj.vm2.lib.OneArgFunction;
import org.json.*;
import org.luaj.vm2.*;
import org.luaj.vm2.lib.jse.JsePlatform;

public class Standalone {
    static LuaTable auditReport() {
        LuaTable r = new LuaTable();
        for (String key : new String[]{"executed","notRun","errors","unverified"}) r.set(key,new LuaTable());
        return r;
    }
    static void record(LuaTable r, Throwable err) {
        String message = err.getMessage() == null ? err.toString() : err.getMessage();
        LuaValue list = r.get(message.contains("未验证：") ? "unverified" : "errors");
        if (list.length()==0 || !message.contains(list.get(list.length()).tojstring())) list.set(list.length()+1, message);
    }
    public static void main(String[] args) throws Exception {
        LuaTable r = auditReport();
        try {
            Path file = Paths.get(args[0]);
            Globals g = JsePlatform.standardGlobals();
            String filename=file.getFileName().toString();
            String module="scripts.colorpicker.customformats."+filename.substring(0,filename.length()-4);
            g.load(PickerFormat.resource("standalone.lua"),"@standalone.lua").call().invoke(new LuaValue[]{
                LuaValue.valueOf(PickerFormat.read(file)), LuaValue.valueOf(file.toString()), LuaValue.valueOf(module),
                PickerFormat.lua(new JSONObject(PickerFormat.read(Paths.get("case.json")))),
                LuaValue.valueOf(PickerFormat.resource("compat.lua")), g.load(PickerFormat.resource("contract.lua"),"@contract.lua").call(), r,
                new OneArgFunction() {
                    public LuaValue call(LuaValue name) {
                        try { Class.forName(name.checkjstring(),false,Standalone.class.getClassLoader()); return TRUE; }
                        catch (ClassNotFoundException | LinkageError missing) { return FALSE; }
                    }
                },
                new OneArgFunction() {
                    public LuaValue call(LuaValue path) { return valueOf(new java.io.File(path.checkjstring()).getAbsolutePath()); }
                }
            });
        } catch(Throwable e) { record(r,e); }
        PickerFormat.saveReport(PickerFormat.report(r));
    }
}
