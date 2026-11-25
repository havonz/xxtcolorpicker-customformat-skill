package picker;

import com._1func.*;
import com.sun.net.httpserver.HttpServer;
import org.json.*;
import org.luaj.vm2.*;
import org.luaj.vm2.lib.jse.CoerceJavaToLua;

import java.awt.*;
import java.awt.datatransfer.Clipboard;
import java.awt.event.*;
import java.lang.reflect.*;
import java.net.InetSocketAddress;
import java.nio.file.*;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;
import org.luaj.vm2.lib.VarArgFunction;
import javax.swing.*;

public class HostProbe {
    public static class WindowProbe extends XXTColorPickerMainWnd {
        @Override public void hideSplash() {} // The native launcher is absent in the isolated JVM.
    }
    static WindowProbe window;
    static final LuaTable audit = Standalone.auditReport();
    static final JSONObject output = new JSONObject();
    static Field field(Class<?> type, String name) throws NoSuchFieldException {
        while (type != null) {
            try {
                Field f = type.getDeclaredField(name);
                f.setAccessible(true);
                return f;
            } catch (NoSuchFieldException e) { type=type.getSuperclass(); }
        }
        throw new NoSuchFieldException(name);
    }
    static void open() throws Exception {
        // If the list is empty the host falls back to its packaged X_Y_Color, even after a bad import.
        Path formats=Paths.get("scripts/colorpicker/customformats");
        Files.createDirectories(formats);
        Path baseline=Files.createTempFile(formats,"validator-baseline-", ".lua");
        Files.write(baseline,PickerFormat.resource("point-list.lua").getBytes("UTF-8"));
        Toolkit tk=Toolkit.getDefaultToolkit();
        Clipboard clip=new Clipboard("picker-format");
        field(tk.getClass(),"clipboard").set(tk,clip);
        if (tk.getSystemClipboard()!=clip) throw new IllegalStateException("未验证：当前 Toolkit 无法隔离剪贴板");
        Files.write(Paths.get("XXTColorPicker.config.dat"), "{\"Options\":{\"UsingJC\":true}}".getBytes("UTF-8"));
        XXTColorPickerMainWnd.runArgs=new String[0];
        XXTColorPickerMainWnd.lafColor="light";
        Class<?> wnd=XXTColorPickerMainWnd.class;
        field(wnd,"isMac").set(null,System.getProperty("os.name").startsWith("Mac"));
        System.setProperty("xxtcolorpicker.laf.type","flat");
        System.setProperty("xxtcolorpicker.laf.color","light");
        UIManager.setLookAndFeel("com.formdev.flatlaf.FlatLightLaf");
        Method icons=wnd.getDeclaredMethod("init_ICON",String.class);
        icons.setAccessible(true);
        icons.invoke(null,"light");
        HttpServer server=HttpServer.create(new InetSocketAddress("127.0.0.1",0),0);
        server.start();
        field(wnd,"singletonServer").set(null,server);
        SwingUtilities.invokeAndWait(() -> window=new WindowProbe());
        Object controller=field(wnd,"sessionController").get(window);
        Field restoring=field(controller.getClass(),"restoring");
        long until=System.nanoTime()+15_000_000_000L;
        while (true) {
            boolean[] ready={false};
            SwingUtilities.invokeAndWait(() -> {
                try { ready[0]=!restoring.getBoolean(controller); }
                catch (ReflectiveOperationException e) { throw new IllegalStateException(e); }
            });
            if (ready[0]) break;
            if (System.nanoTime()>until) throw new IllegalStateException("未验证：宿主启动超时");
            Thread.sleep(30);
        }
        ((_1FCPDeviceFinder)field(wnd,"deviceFinder").get(window)).stop();
        tk.addAWTEventListener(event -> {
            if (event.getID()==WindowEvent.WINDOW_OPENED && event.getSource() instanceof Dialog) {
                Dialog dialog=(Dialog)event.getSource();
                audit.get("unverified").set(audit.get("unverified").length()+1,"未验证：弹窗需要人工操作 · "+dialog.getTitle());
                EventQueue.invokeLater(dialog::dispose);
            }
        },AWTEvent.WINDOW_EVENT_MASK);
    }
    static JSONArray rows(JTable table) {
        JSONArray rows=new JSONArray();
        for (int i=0;i<table.getRowCount();i++) {
            JSONArray row=new JSONArray();
            for (int j=0;j<table.getColumnCount();j++) {
                Object value=table.getValueAt(i,j);
                if (value!=null) row.put(j,value.toString());
            }
            rows.put(row);
        }
        return rows;
    }
    static void trackFixtureDependencies(Globals g) {
        Set<String> used=new HashSet<>();
        LuaValue imageSize=g.get("getImageSize");
        Set<String> device=new HashSet<>(Arrays.asList("capture","uploadScriptAndRun","getConnectedDeviceAPI"));
        for (String apiName:Arrays.asList("capture","uploadScriptAndRun","getConnectedDeviceAPI","getImageSize",
                "getPixel","getColor","getColorRGB","getRectPNGData","getRectPNGDataHex","getRectJPEGData","getRectJPEGDataHex")) {
            LuaValue original=g.get(apiName);
            if (!original.isfunction()) continue;
            g.set(apiName,new VarArgFunction() {
                public Varargs invoke(Varargs args) {
                    boolean needsDevice=device.contains(apiName);
                    if (needsDevice || imageSize.call().optint(0)<=0) {
                        String msg="未验证："+apiName+(needsDevice ? " · 用例未连接设备" : " · 仅覆盖无图行为");
                        if (used.add(apiName)) {
                            LuaValue skipped=audit.get("unverified");
                            skipped.set(skipped.length()+1,msg);
                        }
                        if (needsDevice) throw new LuaError(msg);
                    }
                    return original.invoke(args);
                }
            });
        }
    }
    static void run(Path input, JSONObject c) throws Exception {
        String filename=input.getFileName().toString();
        Path directory=Paths.get("scripts/colorpicker/customformats");
        Files.createDirectories(directory);
        // Start without this module so a failed import cannot pass by retaining an earlier version.
        Files.copy(input,directory.resolve(filename));
        JComboBox<?> chooser=window.getCustomFormatChooser();
        JLabel label=Arrays.stream(chooser.getParent().getComponents()).filter(component ->
                component instanceof JLabel && _1FCPUtils._LANG("CustomFormat").equals(((JLabel)component).getText()))
                .map(JLabel.class::cast).findFirst().orElseThrow(() -> new IllegalStateException("未验证：找不到自定格式标签"));
        JMenuItem reload=Arrays.stream(label.getComponentPopupMenu().getComponents()).filter(component ->
                component instanceof JMenuItem && _1FCPUtils._LANG("ReloadCustomFormats").equals(((JMenuItem)component).getText()))
                .map(JMenuItem.class::cast).findFirst().orElseThrow(() -> new IllegalStateException("未验证：此版本缺少重新加载菜单"));
        Globals g=window.getTheLuaState();
        trackFixtureDependencies(g);
        reload.doClick(0);
        LuaValue pkg=g.get("package").get("1func");
        LuaValue formats=pkg.get("customformats");
        String id="scripts.colorpicker.customformats."+filename.substring(0,filename.length()-4);
        LuaValue format=LuaValue.NIL;
        for (int i=1;i<=formats.length();i++) if (id.equals(formats.get(i).get("__module_name").optjstring(""))) {
            chooser.setSelectedIndex(i-1);
            if (chooser.getSelectedIndex()==i-1) format=formats.get(i);
            break;
        }
        if (format.isnil()) throw new IllegalArgumentException(input+" · 宿主重新加载后没有选中该模块，详见宿主日志");
        Varargs control=g.load(PickerFormat.resource("contract.lua"),"@contract.lua").call()
                .invoke(LuaValue.varargsOf(new LuaValue[]{format,PickerFormat.lua(c),audit}));
        try {
            LuaValue settings=control.arg1();
            g.get("saveCustomFormatConfig").call(settings);
            LuaValue callbacks=pkg.get("callbacks");
            String[] keys={"a","s","x","c"};
            for (String key : keys) {
                JSONObject regions=c.optJSONObject("regions");
                JSONArray xy=regions==null ? null : regions.optJSONArray(key);
                int x=xy==null ? 0 : xy.getInt(0), y=xy==null ? 0 : xy.getInt(1);
                if ("a".equals(key)) window.setPosAXY(x,y);
                if ("s".equals(key)) window.setPosSXY(x,y);
                if ("x".equals(key)) window.setPosXXY(x,y);
                if ("c".equals(key)) window.setPosCXY(x,y);
            }
            JSONArray pts=c.getJSONArray("points");
            JSONArray cursor=c.optJSONArray("hover");
            if (cursor==null) cursor=pts.length()>0 ? pts.getJSONArray(0) : new JSONArray("[0,0,0]");
            window.getCurrentMousePos().setXYRGB(cursor.getInt(0),cursor.getInt(1),cursor.getInt(2));
            LuaValue f=format.get("formats");
            boolean bottom=f.get("mouseTrackInfoBottomRule").isfunction(), zoom=f.get("mouseTrackInfoZoomRule").isfunction();
            callbacks.get("onMouseTrack").call();
            if (bottom) output.put("hoverBottom",((JLabel)field(window.getClass(),"imageStatusLeftTips").get(window)).getText());
            if (zoom) output.put("hoverZoom",((JTextArea)field(window.getClass(),"zoomInfoTextArea").get(window)).getText());
            if (pts.length()>0) g.get("reloadPosColors").call(PickerFormat.lua(pts));
            g.get("reloadPasteboard").call();
            JSONArray picked=new JSONArray();
            for (int i=1;i<=pts.length();i++) {
                picked.put(i>10 ? window.getExtraPosColorsRegisterText(i-11) : window.getTextFieldWithIndex(i==10 ? 0 : i).getText());
            }
            output.put("picked",picked).put("pickClipboard",g.get("clipText").call().tojstring());
            ((JButton)field(window.getClass(),"makeScriptsButton").get(window)).doClick(0);
            JTable table=window.getResultsTable();
            output.put("rows",rows(table)).put("generateClipboard",g.get("clipText").call().tojstring());
            JSONArray menus=new JSONArray(), actions=c.optJSONArray("actions");
            if (actions!=null) for (int i=0;i<actions.length();i++) {
                JSONObject a=actions.getJSONObject(i);
                int row=a.getInt("row")-1;
                if (row>=table.getRowCount()) throw new IllegalArgumentException("结果行不存在 "+(row+1));
                boolean menu=a.getString("type").equals("menu");
                MouseEvent event=new MouseEvent(table,MouseEvent.MOUSE_CLICKED,System.currentTimeMillis(),0,
                        2,2,menu ? 1 : 2,menu,menu ? MouseEvent.BUTTON3 : MouseEvent.BUTTON1);
                callbacks.get(menu ? "onResultsTableRightClickCallback":"onResultsTableDoubleClickCallback")
                        .call(CoerceJavaToLua.coerce(event),LuaValue.valueOf(row),LuaValue.valueOf(0));
                if (menu) {
                    JPopupMenu popup=null;
                    for (MenuElement e:MenuSelectionManager.defaultManager().getSelectedPath())
                        if (e instanceof JPopupMenu) popup=(JPopupMenu)e;
                    JSONArray names=new JSONArray();
                    if (popup!=null) for (java.awt.Component item:popup.getComponents()) names.put(((JMenuItem)item).getText());
                    menus.put(names);
                    if (a.has("item")) {
                        int item=a.getInt("item")-1;
                        if (item>=names.length()) throw new IllegalArgumentException("菜单项不存在 "+(item+1));
                        JMenuItem button=(JMenuItem)popup.getComponent(item);
                        MenuSelectionManager.defaultManager().clearSelectedPath();
                        button.doClick(0);
                    } else MenuSelectionManager.defaultManager().clearSelectedPath();
                }
            }
            output.put("menus",menus).put("afterRows",rows(table)).put("clipboard",g.get("clipText").call().tojstring());
        } finally { control.arg(2).call(); }
    }
    public static void main(String[] args) throws Exception {
        try {
            JSONObject c=new JSONObject(PickerFormat.read(Paths.get("case.json")));
            try { open(); } catch (Exception | LinkageError e) {
                throw new IllegalStateException("未验证：宿主初始化失败 · "+e,e);
            }
            SwingUtilities.invokeAndWait(() -> {
                try { run(Paths.get(args[0]),c); }
                catch (Throwable t) { Standalone.record(audit,t); }
            });
            SwingUtilities.invokeAndWait(() -> {
                if (audit.get("errors").length()>0) try {
                    Object log=field(window.getClass(),"logEditor").get(window);
                    output.put("hostLog",((javax.swing.text.JTextComponent)log).getText());
                } catch (Exception ignored) { /* Original validation diagnostic is still available. */ }
            });
        } catch (Throwable t) { Standalone.record(audit,t); }
        JSONObject status=PickerFormat.report(audit);
        for (String k:status.keySet()) output.put(k,status.get(k));
        PickerFormat.saveReport(output);
        System.exit(0);
    }
}
