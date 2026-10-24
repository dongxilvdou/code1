# Image prompts / 开场漫画样图

生成方式：内置 image_gen；未使用 API / CLI。所有图均为 AI 生成的风格概念图，不声称是人工原画或完成的游戏动画。

V2 是用户指出初版过于精修后，按“猫先用线条勾勒，再简单上色；场景保留”的要求进行的图像编辑。下列提示词为实际使用版本；其中英文风格描述是美术目标，不代表实际由人工绘制。最终确认仍由用户审阅。

## 1. 初版角色图（留档）

```text
Use case: stylized-concept.
Asset type: original anime/manga character art direction sample for the existing Godot game 哈基米模拟器. Wide landscape 16:9 character presentation, high resolution and carefully finished.
Primary request: Anime-stylize the ACTUAL current game cat shown in reference images 1, 2, 3. Preserve this cat's recognizable anatomy and markings; do not substitute an older calico design.
Input images: Image 1 is the current 3D cat in a three-quarter view, identity reference. Image 2 is its front view, identity reference. Image 3 is its side view, identity reference. Image 4 is ONLY a reference for thick black diagonal comic gutters, cinematic panel framing and restrained anime coloring; do not reproduce its people, text, logo or sci-fi setting.
Subject identity: a slender adult orange-and-white shorthaired domestic tabby, a natural four-legged cat. Rusty ochre/orange crown, ears, back, flanks and ringed tail, subtle brown tabby stripes; white muzzle and narrow white nose blaze, white chin and large white bib, underside and white legs/paws. Olive yellow-green eyes with narrow vertical black pupils. Small pink nose and inner ears. Natural angular feline cheeks, long triangular ears, long lean legs, narrow shoulders, gently curved tail. Keep consistent markings in every view. The cat is not black-and-white and not calico; do not add black fur patches, clothes or collars.
Style/medium: cinematic hand-drawn 2D anime illustration with the grounded daily-life unease and observational framing of Chainsaw Man, deliberate confident black ink contours, subtle irregular fine-line fur accents, restrained cross-hatching, two-tone cel shading, carefully placed hard-edged shadow shapes, delicate sparse grain. Expressive real feline anatomy, subtle cuteness. No 3D render appearance, no painterly airbrushing, no hyperreal fur, no chibi or mascot proportions, no enormous eyes.
Composition: an elegant unified character concept board with four asymmetrical areas divided by thick, clean black diagonal gutters. The large LEFT area covers about 60% and contains a fully visible standing three-quarter cat at paw height, one forepaw lifted in curiosity, all four limbs anatomically clear, tail entirely inside frame, softly grounded on a dark wooden floor. Simple muted warm-gray interior backdrop. The RIGHT side contains three generous sequential close-ups of this same cat: (top) recently awake, wary and listening; (middle) relaxed, eyes half-closed with quiet affection as she remembers being stroked, no humans in this sheet; (bottom) attentive and quietly determined, ears forward. The expressions must remain feline, never human smiles. Each panel is well-separated and polished, with no cropped ears. Prioritize face, white blaze and eyes in readable light.
Lighting/mood: broad warm amber window light from the side, cool muted petrol/slate shadows, gentle rim separation; deep but legible blacks. Intimate, grounded, slightly mysterious, warm memory rather than aggressive horror. Orange-white coat remains its actual local color.
Text: no text, no labels, no speech bubbles, no watermark. Avoid all existing franchise characters or recognizable scene copies. This is original concept art of the supplied cat, not a screenshot and not yet an implemented game animation.
```

## 2. 初版漫画页（留档）

```text
Use case: illustration-story.
Asset type: a polished widescreen 16:9 sample page for an original animated comic opening to the game 哈基米模拟器. This page covers the cat's awakening and realization. It is a story art proposal, not a fake gameplay screenshot.
Input image roles: 1 is the APPROVED-FOR-THIS-SAMPLE character style sheet and identity anchor: copy the same orange-and-white tabby cat, face, coat placement, eyes and hand-drawn line style consistently. 2 is the user supplied COMPOSITION reference: borrow only bold black slanted panel borders, cinematic sequential framing and black dialogue rectangles with large readable white Chinese lettering. Do not include its humans or computer. 3 is an ACTUAL GAME HALLWAY reference: use the white plaster walls, warm wood door frames, narrow corridor, high furniture legs, wood floor, and striped terracotta-and-cream doormat as environmental grounding. IGNORE and REMOVE all game UI, floating labels, text, glowing barriers and stripes in the air from reference 3. The stripes on the real floor mat remain.
Style: fully hand-drawn 2D anime manga drama; grounded adult cat proportions, clean black ink contours, lean linework, restrained cel-shaded hard shadows, selective fine hatching. Everyday quiet unease and carefully observed cinematic framing inspired by Chainsaw Man; no horror gore, no existing franchise characters, no traced source artwork. Colors are cool smoky blue-gray shadows and warm ochre stripes of doorway light. Clear readable local colors, natural contrast, no fog. Not 3D or glossy.
One coherent page, THREE large readable asymmetrical panels. Thick black diagonal gutters separate all panels clearly, keeping a calm reading order top left -> top right -> bottom across.
Panel 1 (upper left, about 40% width and upper 40% height): near-floor first-person view into the quiet unfamiliar house entrance; the wood door is huge to a cat, a floor mat leads to the empty passage, a ceiling lamp far above. No cat visible. A black, gently irregular narration rectangle near the upper left with LARGE precise white Chinese text: “……这是哪里？”
Panel 2 (upper right, about 60% width and upper 40% height): cat first-person view looking DOWN at its own two WHITE front paws on the terracotta-and-cream striped floor mat. Both paws extend naturally from the lower frame toward the floor, anatomically plausible four-legged stance; a small orange ringed tail curls into one corner at a natural distance. No human hands. Another black narration rectangle reads exactly “这双爪子……还有尾巴？”
Panel 3 (bottom full width, about 60% height, diagonal top edge): intimate three-quarter head and upper-body close-up of the SAME orange-and-white cat from image 1 at cat eye level. It is mildly startled and curious, one ear swiveling, eyes olive yellow-green with vertical pupils, white muzzle and nose blaze, pink nose, orange tabby forehead, white bib, no clothing or collar. The cat fills the right two-thirds, while shadowed wooden doorway space on the left carries the largest black narration bubble, exact LARGE white Chinese: “原来，我是一只猫。”
Typography: accurate Simplified Chinese, bold clean comic lettering, safe 5% edge margins, no overlap with the cat's face or paws, all three quotes verbatim and no other text. Narration is internal monologue, not human speech spoken by the animal. Vary the bubble silhouette subtly without visual clutter. No title, no watermark, no logos, no page number, no artificial UI.
Preserve all identity traits from image 1; orange and white only with darker orange-brown tabby stripes, NOT tricolor or black-and-white. Keep ears and whiskers entirely readable in the close-up, no malformed paws, no duplicated limbs.
```

## 3. V2 角色：线稿与简单上色

```text
Edit the provided image. Change ONLY THE CAT'S DRAWING STYLE in all four panels. The user likes the existing scenes: preserve the exact panel layout, black gutters, background architecture, background paintings, floor, framing and poses. Do not restyle or simplify the environments.

用户的明确要求：“将猫画得像《电锯人》动画一样，先用线条勾勒，再简单上色。场景保持现在的样子。” 这是猫的线稿和平涂风格修改，不是进一步精修毛发或灯光。

Redraw the same orange-and-white tabby cat as a genuinely economical, line-led 2D anime character, with the grounded feline anatomy and sparse character rendering of a Chainsaw Man animation frame. Preserve orange/white marking placement, olive-green vertical-pupil eyes, pink nose, long ears, slender adult proportions and all existing poses and expressions. It must still be this individual cat.

The CAT should visibly read as INK DRAWING FIRST, COLOR SECOND:
- Bold confident silhouette contours and finer sparse interior lines, subtle human-drawn line-weight variation and occasional tiny broken lines.
- Simplify the head into clear angular cheek, muzzle and brow shapes. Quiet expressive eyes with simple flat irises, no polished lens-like effects. Ears with one simple inner shape.
- Extremely restrained fur: a few angular tufts at cheek, chest and ear edges only. The inside of white chest and legs should be almost completely blank pale color. NO hair-by-hair marks, NO fine hatching, NO textured fur brush, NO realistic grooming detail.
- Simplify the orange tabby stripes into a small number of broad, graphic rust-brown markings; do not cover the cat in decorative stripe filigree.
- Use only one flat base color and one clearly cut, HARD-EDGED shadow color per fur region: muted ochre orange + dark warm brown, warm off-white + muted gray. No soft blending within the cat, no gradients, no glossy highlights or luminous fur rim lights.
- Thin simple whiskers, a few facial construction lines, minimal paw/toe lines. Paws remain round and feline.
- As a result, the cat should look like a sparse production animation drawing colored with flat paint, then placed against the richer existing background. Detail should be RADICALLY less dense than the input.
- The left full-body cat and three right close-ups must use exactly the same line-art-led flat-color treatment. Do not leave any cat panel in the old highly rendered style.

Preserve original composition, cat identity, natural four-legged anatomy, poses and existing background. No new objects, no text, no logos, no watermark. Do not make a chibi mascot, furry humanoid, photoreal illustration, 3D render, oil painting, or softly shaded digital character. This is a targeted anime-style redraw of the CAT ONLY.
```

## 4. V2 漫画页：只修改猫的画法

```text
Targeted edit. Image 1 is the comic page to edit. Image 2 is the corrected CAT STYLE reference approved as the direction by the user's written request (not a claim of final approval): black ink outlines first, simple flat colors afterwards, like the economical grounded cat drawings in Chainsaw Man animation.
Keep the background scenes, every panel division, dimensions, framing, camera angle, composition, lighting of the ENVIRONMENT and ALL Chinese text in image 1 exactly as they are. The user explicitly likes the scenes. Do not alter any architecture, mat, furniture, black gutter, speech rectangle or text.

Redraw ONLY the cat in the large bottom panel, and the visible paws/tail in the top-right panel, to match image 2's radically simplified line-led anime character treatment.
Keep this same orange-and-white tabby identity, exact original poses, gaze, silhouette and expressions. Pink nose, olive yellow-green vertical-pupil eyes, white muzzle and bib, orange forehead and back, white paws, ringed orange tail.
Use decisive black outline contours, light sparse facial construction lines, simple ear shapes, natural slim feline anatomy. Remove the dense fur strokes completely. Indicate fur with only a few edge notches at the cheeks, chest and ears. Leave the interiors of white fur as near-empty flat paint. Convert the intricate tabby fur markings into a few broad dark-orange/brown painted stripes.
Color the cat with restrained flat ochre, off-white, simple green irises and pink nose; use a SINGLE hard-edged shadow shape where needed. No airbrushing, no soft 3D shading, no luminous rim hairs, no fur texture, no hatch filling, no hair-by-hair rendering, no glossy eye lenses. The line drawing should do most of the work; color should merely fill it.
Preserve the richer environments behind this flat-colored character without restyling the scene. All three original captions must remain perfectly unchanged and readable: “……这是哪里？” / “这双爪子……还有尾巴？” / “原来，我是一只猫。” Nothing else should be added.
No chibi proportions, no extra limbs, no new objects, no other text, no watermark.
```

