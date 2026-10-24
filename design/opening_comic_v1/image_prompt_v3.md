# V3 纸面漫画猫样例

生成方式：内置 image_gen，参考图编辑。不是人工绘制原稿。

输出：`01_cat_manga_sample_v3.png`。

参考：用户新提供的黑白漫画猫（线条、五官、网点参考）；V2 角色四分格（布局、姿态、当前游戏猫的花纹参考）。

检查：猫改为黑白灰网点和留白；原有四格与姿态保留；背景也被生成工具转成黑白，未严格保持原来的背景颜色。该图作为整体黑白风格候选供审阅，没有接入游戏。剧情与分镜保持原稿。

## 实际生成提示词

```text
Use case: style-transfer / character redraw.
Image 1 is the user's NEW and PRIMARY art-direction reference: a softly drawn black-and-white printed manga cat. Study the actual simple feline face, thin ink contours, economical anatomy, visible paper white, fine printed screentone dots, and dark hatch-shaped tabby markings. This is now the target, superseding the colored anime rendering of image 2.
Image 2 is the existing sample to revise. Preserve its four-panel arrangement, poses, cat identities, framing, background rooms and floor. The user said the existing scenes are fine. REDRAW ONLY THE CATS IN EVERY PANEL in the manner of the cat in image 1. Do not merely lower saturation on the existing rendered cats: genuinely redraw them as an ink-and-screentone manga drawing.

用户要求：猫要像第一张参考中的纸上漫画猫；之前橙色太浓、太鲜艳、太有精修生成图的感觉。优先做轻巧自然的猫咪线稿，轮廓不要画得像写实兽类雕塑，五官简洁，黑白灰为主，只允许极淡的灰褐色印刷套色。

The CAT rendering should be almost monochrome: 95% black ink, warm gray screentone and paper-white. A barely perceptible pale taupe tint may suggest its ginger fur, but NO visible orange/saturated brown filling. White chest, muzzle and paws are mostly untouched paper-white. Tabby crown/back/tail patterns are broad dark-gray to black ink forms broken by sparse little hatching, just like the reference. Eyes are simple line-drawn gray irises with vertical dark pupils, no bright green, glass-like reflection or glowing highlights; nose is a tiny ink shape with a very faint gray-rose tint.
Draw with thin, slightly irregular and tapered black manga lines: a light jaw contour, understated muzzle, simple soft triangular ears, a few small cheek-fur strokes, simple paws with two toe marks. A natural mildly curious cat, gentle roundness to its face like image 1, without becoming chibi or a plush toy. Keep real feline proportions, not oversized expressive human eyes. No heroic sharply sculpted brow, no bulky puffed neck fur. The white belly and chest must feel open and unworked.
Use sparse tiny mechanical halftone/screentone dots and limited short pen hatching ONLY where volume needs suggesting: under the jaw, inner ears, lower belly, rear leg overlap. Most of the form is carried by contour and blank paper, not by shaded volume. Do not use soft airbrush shading, gradient rendering, cel-paint broad smooth shadows, luminous rim lights, reflective fur, dense individual hair detail or digital smoothing. No fake uniformly overlaid paper grain. This should read as an economical cat drawn for the interior page of a printed manga.
The large full-body cat on the left remains standing with one paw lifted, all limbs clear, tail inside the image. Three smaller heads at right retain alert, content/eyes-closed, and quietly determined expressions; all are rendered with the same thin-lines-and-screentone treatment.
Keep cat marking placement and the large white chest from image 2, but render ginger markings as the restrained warm-gray inks described above. Keep existing background architecture, framing, black diagonal gutters and lighting; remove any colored rim light/reflected orange cast on the CAT itself. The cat should sit naturally in its original position, not gain a white rectangular backing around it. The environments stay as image 2, no new plant or windows from reference 1, no copying the entire source cat pose.
Output one 16:9 wide revised concept sheet, no text or watermark.
```
