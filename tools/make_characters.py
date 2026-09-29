"""Generate the character sprites: a Taiwanese schoolkid hero and his rival.

Two local models, because one can't do both jobs:
- Z-Image-Turbo draws each character's standing pose from text.
- Qwen-Image-Edit redraws that stand into the other poses. Prompting each
  pose from scratch gives a different kid every time; editing the stand keeps
  the face, clothes and outline identical.
Both paint on flat green, and a chroma key turns that into alpha — no matting
model is installed, and the thick outlines key cleanly.

Every pose lands on one canvas, feet on the bottom edge: scenes draw the
sprite into a fixed rect that doubles as the hitbox. The edit model neither
keeps the input resolution nor the character's size in frame, so each pose
states how much of the canvas height it should fill (a crouch is shorter
than a stand) instead of inheriting a scale from its source pixels.
Qwen-Image-Edit takes ~12 min per pose on an M5 Max; the whole run ~38 min.

    python3 tools/make_characters.py
"""
import os
import subprocess
import tempfile

import numpy as np
from PIL import Image

OUT = "/Users/ricky/git/game/SmallGame/Resources/Sprites/"
MODELS = "/Users/ricky/git/mlx-dir/models/AbstractFramework/"
CANVAS = (192, 252)  # ~0.76 aspect, the scenes' 26x34 pt player rect; 3x the 56 pt menu icon

STYLE = ("single 2D mobile game character sprite, full body from head to shoes, centered, "
         "facing the viewer, chibi proportions with big head, flat vector illustration, clean "
         "thick dark outline, simple cel shading, bright friendly colors, solid flat pure green "
         "background, no ground, no shadow, no text")
KEEP = ("Keep the exact same character design, face, clothes, colors, thick dark outline and "
        "flat vector style. Full body visible, same scale, same solid flat pure green "
        "background, no ground, no shadow, no text.")

# character: (seed, prompt) for the text-to-image stand
STANDS = {
    "player": (3, ("a cheerful Taiwanese elementary school boy wearing a soft round yellow cloth "
                   "school hat with a short brim all around, white short sleeve school shirt with "
                   "a collar, navy blue shorts, white socks, black sneakers, standing relaxed with "
                   f"arms at his sides, {STYLE}")),
    "enemy": (29, ("a mischievous rival kid wearing a blue knit beanie with a white pom pom, puffy "
                   "blue winter jacket, blue scarf, dark pants, black boots, standing relaxed with "
                   f"arms at his sides, {STYLE}")),
}

# sprite name: (character, None for the stand itself or (seed, edit prompt),
#               fraction of the canvas height the pose fills)
POSES = {
    "player_stand": ("player", None, 0.85),
    "player_jump": ("player", (2, ("Make this same boy jump in the air: both arms raised up high, "
                                   "knees bent with feet tucked up, excited open-mouth smile. "
                                   f"{KEEP}")), 1.0),
    "player_duck": ("player", (2, ("Make this same boy crouch down low, charging up to jump: knees "
                                   "deeply bent, body lowered, arms pulled back, determined face. "
                                   f"{KEEP}")), 0.8),
    "enemy_stand": ("enemy", None, 0.85),
    "enemy_hit": ("enemy", (1, ("Make this same kid get hit by a snowball: leaning back off "
                                "balance, eyes squeezed shut as X marks, white snow splattered on "
                                f"his face and jacket. {KEEP}")), 0.8),
}


def mlxgen(model, output, prompt, seed, steps, extra):
    subprocess.run(["mlxgen", "generate", "--model", MODELS + model, "--prompt", prompt,
                    "--seed", str(seed), "--steps", str(steps), "--output", output, *extra],
                   check=True)


def draw_stand(character, output):
    """Text-to-image stand; make_icon.py reuses it so the icon kid is this kid."""
    seed, prompt = STANDS[character]
    mlxgen("z-image-turbo-8bit", output, prompt, seed, 8, ["--width", "768", "--height", "1024"])


def key_green(img):
    """Flat green background -> alpha. Greenness (G above both R and B) is
    measured against the background's own, so the soft drop shadow the model
    paints anyway keys out with it; edge pixels get partial alpha and have
    the green spill pulled out so outlines don't glow."""
    rgb = np.asarray(img.convert("RGB")).astype(np.float32)
    greenness = rgb[..., 1] - np.maximum(rgb[..., 0], rgb[..., 2])
    border = np.concatenate([greenness[0], greenness[-1], greenness[:, 0], greenness[:, -1]])
    bg = np.median(border)
    lo, hi = bg * 0.25, bg * 0.6
    alpha = np.clip((hi - greenness) / (hi - lo), 0, 1)
    rgb[..., 1] = np.minimum(rgb[..., 1], np.maximum(rgb[..., 0], rgb[..., 2]))
    rgba = np.dstack([rgb, alpha * 255]).round().astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def place(sprite, height):
    """Scale to `height` of the canvas and stand it on the canvas floor."""
    sprite = sprite.crop(sprite.getchannel("A").point(lambda a: 255 if a > 25 else 0).getbbox())
    scale = CANVAS[1] * height / sprite.height
    size = (round(sprite.width * scale), round(sprite.height * scale))
    if size[0] > CANVAS[0] or size[1] > CANVAS[1]:
        fit = min(CANVAS[0] / size[0], CANVAS[1] / size[1])
        print(f"    pose overflows the canvas, shrunk to {fit:.0%}")
        size = (round(size[0] * fit), round(size[1] * fit))
    # Premultiplied resize: straight-alpha resampling drags the keyed-out
    # background color into the edge pixels.
    sprite = sprite.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
    canvas = Image.new("RGBA", CANVAS)
    canvas.alpha_composite(sprite, ((CANVAS[0] - size[0]) // 2, CANVAS[1] - size[1]))
    return canvas


if __name__ == "__main__":
    with tempfile.TemporaryDirectory() as tmp:
        stands = {}
        for character in STANDS:
            stands[character] = os.path.join(tmp, f"{character}.png")
            draw_stand(character, stands[character])
        for name, (character, edit, height) in POSES.items():
            raw = stands[character]
            if edit is not None:
                seed, prompt = edit
                raw = os.path.join(tmp, f"{name}.png")
                mlxgen("qwen-image-edit-2511-8bit", raw, prompt, seed, 20,
                       ["--image", stands[character]])
            place(key_green(Image.open(raw)), height).save(os.path.join(OUT, f"{name}.png"))
            print(f"  {name}.png")
