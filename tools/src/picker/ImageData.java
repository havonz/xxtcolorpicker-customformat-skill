package picker;

import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import javax.imageio.ImageIO;
import org.luaj.vm2.LuaError;
import org.luaj.vm2.LuaTable;
import org.luaj.vm2.LuaValue;
import org.luaj.vm2.lib.TwoArgFunction;

final class ImageData {
    static LuaTable functions() {
        LuaTable api = new LuaTable();
        api.set("thresholdImageData", new TwoArgFunction() {
            @Override public LuaValue call(LuaValue data, LuaValue value) {
                int threshold = value.checknumber().toint();
                try {
                    return png(thresholdWithOpenCVStyle(decode(data), Math.max(0, threshold), threshold < 0));
                } catch (IOException e) {
                    throw new LuaError("thresholdImageData: " + e.getMessage());
                }
            }
        });
        api.set("binaryzationImageData", new TwoArgFunction() {
            @Override public LuaValue call(LuaValue data, LuaValue options) {
                LuaTable rules = options.checktable();
                try {
                    return png(binaryzation(decode(data), rules));
                } catch (IOException e) {
                    throw new LuaError("binaryzationImageData: " + e.getMessage());
                }
            }
        });
        return api;
    }

    private static BufferedImage decode(LuaValue data) throws IOException {
        try (InputStream in = data.checkstring().toInputStream()) {
            BufferedImage image = ImageIO.read(in);
            if (image == null) throw new IOException("无法解码图像");
            return image;
        }
    }

    private static LuaValue png(BufferedImage image) throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        ImageIO.write(image, "png", out);
        return LuaValue.valueOf(out.toByteArray());
    }

    private static BufferedImage binaryzation(BufferedImage image, LuaTable options) {
        boolean whiteBackground = options.get("white_background").toboolean();
        boolean similarity = options.get("csim_mode").toboolean();
        LuaValue algorithm = options.get("csim_algorithm");
        int method = algorithm.isint() ? algorithm.toint() : 0;
        int[] colors = new int[options.length()];
        int[] limits = new int[colors.length];
        for (int i = 0; i < colors.length; i++) {
            LuaValue rule = options.get(i + 1);
            colors[i] = rule.get(1).toint();
            limits[i] = rule.get(2).toint();
        }

        BufferedImage result = new BufferedImage(image.getWidth(), image.getHeight(), BufferedImage.TYPE_BYTE_BINARY);
        for (int y = 0; y < image.getHeight(); y++) {
            for (int x = 0; x < image.getWidth(); x++) {
                int rgb = image.getRGB(x, y);
                boolean matched = false;
                for (int i = 0; i < colors.length && !matched; i++) {
                    int target = colors[i], limit = limits[i];
                    if (!similarity) {
                        matched = Math.abs(((rgb >> 16) & 255) - ((target >> 16) & 255)) <= ((limit >> 16) & 255)
                                && Math.abs(((rgb >> 8) & 255) - ((target >> 8) & 255)) <= ((limit >> 8) & 255)
                                && Math.abs((rgb & 255) - (target & 255)) <= (limit & 255);
                    } else if (method == 1) {
                        matched = compareColorManhattanFast(rgb, target) >= limit;
                    } else if (method == 2) {
                        matched = compareColorEuclidean(rgb, target) >= limit;
                    } else {
                        matched = compareColorXXT(rgb, target) >= limit;
                    }
                }
                result.setRGB(x, y, matched == whiteBackground ? 0xff000000 : 0xffffffff);
            }
        }
        return result;
    }

    // Keep the host's rounding and integer scale: a one-point difference can change a threshold match.
    private static final double EUCLIDEAN_MAX_RGB_DISTANCE = 441.6729559f; // Math.sqrt(255 * 255 * 3);

    private static double compareColorEuclidean(int rgb1, int rgb2) {
        int r1 = (rgb1 >> 16) & 0xff;
        int g1 = (rgb1 >> 8) & 0xff;
        int b1 = rgb1 & 0xff;
        int r2 = (rgb2 >> 16) & 0xff;
        int g2 = (rgb2 >> 8) & 0xff;
        int b2 = rgb2 & 0xff;
        double dist = Math.sqrt(
                (r1 - r2) * (r1 - r2) +
                        (g1 - g2) * (g1 - g2) +
                        (b1 - b2) * (b1 - b2)
        );
        return (1.f - dist / EUCLIDEAN_MAX_RGB_DISTANCE) * 100.f;
    }

    private static int compareColorManhattanFast(int rgb1, int rgb2) {
        int r0 = (rgb1 >> 16) & 0xFF;
        int g0 = (rgb1 >> 8) & 0xFF;
        int b0 = rgb1 & 0xFF;
        int r1 = (rgb2 >> 16) & 0xFF;
        int g1 = (rgb2 >> 8) & 0xFF;
        int b1 = rgb2 & 0xFF;

        r0 -= r1;
        g0 -= g1;
        b0 -= b1;

        int diff = Math.abs(r0) + Math.abs(g0) + Math.abs(b0);
        // 最大色差为255*3=765
        // return (1.0 - diff / 765.0) * 100.0;
        return ((765 - diff) * 8600) >> 16;
    }

    private static int compareColorXXT(int rgb1, int rgb2) {
        int r1 = (rgb1 >> 16) & 0xFF;
        int g1 = (rgb1 >> 8) & 0xFF;
        int b1 = rgb1 & 0xFF;
        int r2 = (rgb2 >> 16) & 0xFF;
        int g2 = (rgb2 >> 8) & 0xFF;
        int b2 = rgb2 & 0xFF;

        int x = 0xFF - Math.abs(r1 - r2);
        int y = 0xFF - Math.abs(g1 - g2);
        int z = 0xFF - Math.abs(b1 - b2);
        int result = ((x * y * z * 100) >> 24) + 2;
        return result > 2 ? result : 0;
    }

    private static BufferedImage thresholdWithOpenCVStyle(BufferedImage src, int threshold, boolean useOtsu) {
        int width = src.getWidth();
        int height = src.getHeight();

        // 灰度化、统计直方图
        int[] grayValues = new int[width * height];
        int[] histogram = new int[256];
        int idx = 0;
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                int rgb = src.getRGB(x, y);
                int r = (rgb >> 16) & 0xff;
                int g = (rgb >> 8) & 0xff;
                int b = rgb & 0xff;
                int gray = (int)(0.299 * r + 0.587 * g + 0.114 * b + 0.5); // 加0.5四舍五入
                if (gray < 0) gray = 0;
                if (gray > 255) gray = 255;
                grayValues[idx++] = gray;
                histogram[gray]++;
            }
        }

        // Otsu自动阈值
        if (useOtsu) {
            int total = width * height;
            double sum = 0;
            for (int t = 0; t < 256; t++)
                sum += t * histogram[t];

            double sumB = 0;
            int wB = 0;
            int wF = 0;
            double varMax = 0;
            int otsuThreshold = 0;

            for (int t = 0; t < 256; t++) {
                wB += histogram[t];
                if (wB == 0) continue;
                wF = total - wB;
                if (wF == 0) break;
                sumB += (double) (t * histogram[t]);
                double mB = sumB / wB;
                double mF = (sum - sumB) / wF;
                double varBetween = (double) wB * wF * (mB - mF) * (mB - mF);
                if (varBetween > varMax) {
                    varMax = varBetween;
                    otsuThreshold = t;
                }
            }
            threshold = otsuThreshold;
        }

        // 输出为8位灰度，像素值与OpenCV一致（0或255）
        BufferedImage result = new BufferedImage(width, height, BufferedImage.TYPE_BYTE_GRAY);
        idx = 0;
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                int gray = grayValues[idx++];
                int value = (gray > threshold) ? 255 : 0; // OpenCV默认阈值行为
                int rgb = (value << 16) | (value << 8) | value;
                result.setRGB(x, y, rgb);
            }
        }
        return result;
    }
}
