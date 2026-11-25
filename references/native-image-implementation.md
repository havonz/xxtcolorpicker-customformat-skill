# 取色器中的图像接口实现

以下摘录来自 XXTColorPicker 提交 `e80bdab` 的 `src/com/_1func/`。参数及调用示例见[图像接口与 Java 调用](image-and-java.md)。

## LuaJ 注册与 PNG 输出

`XXTColorPickerMainWnd.java`

```java
_G.set("thresholdImageData", new TwoArgFunction() {
    @Override
    public LuaValue call(LuaValue arg1, LuaValue arg2) {
        final byte[] inputData = arg1.checkstring().m_bytes;
        final int threshold = arg2.checknumber().toint();
        final boolean useOtsu;
        if (threshold < 0) {
            useOtsu = true;
        } else {
            useOtsu = false;
        }
        try {
            final ByteArrayOutputStream bs = new ByteArrayOutputStream();
            final ImageOutputStream imOut = ImageIO.createImageOutputStream(bs);
            final BufferedImage bi = _1FCPUtils.loadImage(inputData);
            final BufferedImage thresholdImage = _1FCPUtils.thresholdWithOpenCVStyle(bi, Math.max(threshold, 0), useOtsu);
            ImageIO.write(thresholdImage, "png", imOut);
            return LuaValue.valueOf(bs.toByteArray());
        } catch (final Exception e) {
            throw new LuaError("Error in 'thresholdImageData': the data cannot be accessed.");
        }
    }
});
_G.set("binaryzationImageData", new TwoArgFunction() {
    @Override
    public LuaValue call(LuaValue arg1, LuaValue arg2) {
        final byte[] inputData = arg1.checkstring().m_bytes;
        final LuaTable tab = arg2.checktable();
        final boolean isWhiteBackground = tab.get("white_background").toboolean();
        final boolean isCSimMode = tab.get("csim_mode").toboolean();
        final Function<BufferedImage, BufferedImage> binaryzation;
        if (isCSimMode) {
            final ColorSimilarityAlgorithm colorSimilarityAlgorithm;
            if (tab.get("csim_algorithm").isint()) {
                switch (tab.get("csim_algorithm").toint()) {
                    case 1:
                        colorSimilarityAlgorithm = ColorSimilarityAlgorithm.Manhattan;
                        break;
                    case 2:
                        colorSimilarityAlgorithm = ColorSimilarityAlgorithm.Euclidean;
                        break;
                    default:
                        colorSimilarityAlgorithm = ColorSimilarityAlgorithm.Default;
                        break;
                }
            } else {
                colorSimilarityAlgorithm = ColorSimilarityAlgorithm.Default;
            }
            final Vector<ColorSim> colorSims = new Vector<>();
            for (int i = 1; i <= tab.length(); i+=1) {
                int color = tab.get(i).get(1).toint();
                int sim = tab.get(i).get(2).toint();
                colorSims.add(new ColorSim(color, sim));
            }
            binaryzation = new Function<BufferedImage, BufferedImage>() {
                @Override
                public BufferedImage apply(BufferedImage bi) {
                    return _1FCPUtils.binaryzationCS(bi, colorSims, colorSimilarityAlgorithm, isWhiteBackground);
                }
            };
        } else {
            final Vector<ColorOffset> colorOffsets = new Vector<>();
            for (int i = 1; i <= tab.length(); i+=1) {
                int color = tab.get(i).get(1).toint();
                int offset = tab.get(i).get(2).toint();
                colorOffsets.add(new ColorOffset(color, offset));
            }
            binaryzation = new Function<BufferedImage, BufferedImage>() {
                @Override
                public BufferedImage apply(BufferedImage bi) {
                    return _1FCPUtils.binaryzationCO(bi, colorOffsets, isWhiteBackground);
                }
            };
        }
        try {
            final ByteArrayOutputStream bs = new ByteArrayOutputStream();
            final ImageOutputStream imOut = ImageIO.createImageOutputStream(bs);
            final BufferedImage bi = _1FCPUtils.loadImage(inputData);
            ImageIO.write(binaryzation.apply(bi), "png", imOut);
            return LuaValue.valueOf(bs.toByteArray());
        } catch (final NullPointerException e) {
            throw new LuaError("Error in 'binaryzationImageData': invalid image data.");
        } catch (final Exception e) {
            throw new LuaError("Error in 'binaryzationImageData': the data cannot be accessed.");
        }
    }
});
```

## 输入解码和 ICC 转换

`_1FCPUtils.java`

```java
public static BufferedImage loadImage(byte[] bytes) throws IOException {
    BufferedImage image = ImageIO.read(new ByteArrayInputStream(bytes));
    try {
        ICC_Profile iccProfile = Imaging.getIccProfile(bytes);
        if (iccProfile != null) {
            return colorTools.convertBetweenIccProfiles(image, iccProfile, ICCP_SRGB);
        }
    } catch (Exception ignored) {
    }
    return colorTools.convertTosRgb(image);
}
```

## 相似度计算、Otsu 阈值和前景匹配

`_1FCPUtils.java`

```java
private static final double EUCLIDEAN_MAX_RGB_DISTANCE = 441.6729559f; // Math.sqrt(255 * 255 * 3);

public static double compareColorEuclidean(int rgb1, int rgb2) {
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

public static int compareColorManhattanFast(int rgb1, int rgb2) {
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

public static int compareColorXXT(int rgb1, int rgb2) {
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

public static BufferedImage thresholdWithOpenCVStyle(BufferedImage src, int threshold, boolean useOtsu) {
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

public static BufferedImage binaryzationCO(BufferedImage bi, Vector<ColorOffset> colorOffsets, boolean whiteBackground) {
    final int frontColor;
    final int backColor;
    if (whiteBackground) {
        frontColor = Color.BLACK.getRGB();
        backColor = Color.WHITE.getRGB();
    } else {
        frontColor = Color.WHITE.getRGB();
        backColor = Color.BLACK.getRGB();
    }
    int width = bi.getWidth();
    int height = bi.getHeight();
    BufferedImage binary = new BufferedImage(width, height, BufferedImage.TYPE_BYTE_BINARY);
    for (int x = 0; x < width; x++) {
        for (int y = 0; y < height; y++) {
            int rgb = bi.getRGB(x, y);
            int r = (rgb >> 16) & 0xff;
            int g = (rgb >> 8) & 0xff;
            int b = rgb & 0xff;
            boolean isFront = false;
            for (ColorOffset colorOffset : colorOffsets) {
                int targetR = colorOffset.colorR;
                int targetG = colorOffset.colorG;
                int targetB = colorOffset.colorB;
                int targetOffsetR = colorOffset.offsetR;
                int targetOffsetG = colorOffset.offsetG;
                int targetOffsetB = colorOffset.offsetB;
                if (r >= targetR - targetOffsetR && r <= targetR + targetOffsetR &&
                        g >= targetG - targetOffsetG && g <= targetG + targetOffsetG &&
                        b >= targetB - targetOffsetB && b <= targetB + targetOffsetB) {
                    isFront = true;
                    break;
                }
            }
            if (isFront) {
                binary.setRGB(x, y, frontColor);
            } else {
                binary.setRGB(x, y, backColor);
            }
        }
    }
    return binary;
}

public static BufferedImage binaryzationCS(BufferedImage bi, Vector<ColorSim> colorSims, ColorSimilarityAlgorithm colorSimilarityAlgorithm, boolean whiteBackground) {
    final int frontColor;
    final int backColor;
    if (whiteBackground) {
        frontColor = Color.BLACK.getRGB();
        backColor = Color.WHITE.getRGB();
    } else {
        frontColor = Color.WHITE.getRGB();
        backColor = Color.BLACK.getRGB();
    }
    int width = bi.getWidth();
    int height = bi.getHeight();
    BufferedImage binary = new BufferedImage(width, height, BufferedImage.TYPE_BYTE_BINARY);
    if (colorSimilarityAlgorithm == ColorSimilarityAlgorithm.Default) {
        for (int x = 0; x < width; x++) {
            for (int y = 0; y < height; y++) {
                int rgb = bi.getRGB(x, y);
                boolean isFront = false;
                for (ColorSim colorSim : colorSims) {
                    int targetColor = colorSim.getColor();
                    double targetSim = colorSim.getSim();
                    if (compareColorXXT(rgb, targetColor) >= targetSim) {
                        isFront = true;
                        break;
                    }
                }
                if (isFront) {
                    binary.setRGB(x, y, frontColor);
                } else {
                    binary.setRGB(x, y, backColor);
                }
            }
        }
    } else if (colorSimilarityAlgorithm == ColorSimilarityAlgorithm.Manhattan) {
        for (int x = 0; x < width; x++) {
            for (int y = 0; y < height; y++) {
                int rgb = bi.getRGB(x, y);
                boolean isFront = false;
                for (ColorSim colorSim : colorSims) {
                    int targetColor = colorSim.getColor();
                    double targetSim = colorSim.getSim();
                    if (compareColorManhattanFast(rgb, targetColor) >= targetSim) {
                        isFront = true;
                        break;
                    }
                }
                if (isFront) {
                    binary.setRGB(x, y, frontColor);
                } else {
                    binary.setRGB(x, y, backColor);
                }
            }
        }
    } else if (colorSimilarityAlgorithm == ColorSimilarityAlgorithm.Euclidean) {
        for (int x = 0; x < width; x++) {
            for (int y = 0; y < height; y++) {
                int rgb = bi.getRGB(x, y);
                boolean isFront = false;
                for (ColorSim colorSim : colorSims) {
                    int targetColor = colorSim.getColor();
                    double targetSim = colorSim.getSim();
                    if (compareColorEuclidean(rgb, targetColor) >= targetSim) {
                        isFront = true;
                        break;
                    }
                }
                if (isFront) {
                    binary.setRGB(x, y, frontColor);
                } else {
                    binary.setRGB(x, y, backColor);
                }
            }
        }
    }
    return binary;
}
```

## RGB 色偏拆分

`ColorOffset.java`

```java
package com._1func;

public class ColorOffset {
    private int color;
    private int offset;

    public int colorR;
    public int colorG;
    public int colorB;

    public int offsetR;
    public int offsetG;
    public int offsetB;

    public ColorOffset(int color, int offset) {
        this.color = color;
        this.offset = offset;

        this.colorR = (color >> 16) & 0xFF;
        this.colorG = (color >> 8) & 0xFF;
        this.colorB = color & 0xFF;

        this.offsetR = (offset >> 16) & 0xFF;
        this.offsetG = (offset >> 8) & 0xFF;
        this.offsetB = offset & 0xFF;
    }

    public int getColor() {
        return color;
    }

    public int getOffset() {
        return offset;
    }
}
```
