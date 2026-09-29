"""Generate the painted scene backdrops with a local text-to-image model.

Z-Image-Turbo (8-bit MLX) via `mlxgen`. Flat-vector style so the art sits
behind the Kenney sprites without competing: muted colors, empty center.
Each seed is the candidate picked from a batch; the same prompt + seed + size
reproduces it, so prompts are kept verbatim — reordering one changes the art.
Fishing gets separate sky and water images: the model can't be told where the
horizon goes, but the scene's waterline is a fixed fraction of its height.
JPEG output: backdrops are opaque, and PNG would be ~4 MB vs ~260 KB.

    python3 tools/make_backgrounds.py [name ...]
"""
import os
import subprocess
import sys
import tempfile

from PIL import Image

OUT = "/Users/ricky/git/game/SmallGame/Resources/Backgrounds/"
MODEL = "/Users/ricky/git/mlx-dir/models/AbstractFramework/z-image-turbo-8bit"
STEPS = 8

FLAT = "flat vector illustration mobile game background"
TAIL = ("simple clean shapes, soft gradients, subtle texture, muted low-contrast colors, "
        "calm uncluttered center area for gameplay, no characters, no people, no animals, "
        "no text, no logo, no UI")

# name: (width, height, seed, prompt)
BACKDROPS = {
    "bg_tower": (768, 1664, 5,
                 ("portrait, open night sky high above the city, deep indigo at the top fading to "
                  "violet at the bottom, crescent moon in an upper corner, soft layered clouds "
                  "drifting at the left and right edges, tiny stars, low distant city skyline "
                  "silhouette only along the very bottom edge, wide empty sky in the middle, "
                  f"no towers, no tall buildings, {FLAT}, {TAIL}")),
    "bg_shaft": (768, 1664, 11,
                 ("dark underground cave shaft going deep down, rough dark stone walls at the far "
                  "left and right edges, charcoal and deep moss green palette, faint hanging roots, "
                  "a few small glowing teal crystals on the walls, center mostly empty dark space, "
                  f"{FLAT}, portrait, {TAIL}")),
    "bg_snowball": (768, 1664, 42,
                    ("snowy winter field in daytime, pale icy blue sky, row of snow covered pine "
                     "trees and soft hills along the upper quarter, wide flat open snow field below, "
                     f"gentle falling snowflakes, pastel palette, {FLAT}, portrait, {TAIL}")),
    "bg_fishing_sky": (1024, 576, 11,
                       ("landscape, bright daytime sky over a calm sea, soft light blue gradient, "
                        "a few fluffy white clouds, small distant green islands sitting on the "
                        f"horizon along the very bottom edge, {FLAT}, {TAIL}")),
    "bg_fishing_water": (768, 1200, 42,
                         ("portrait, underwater view of a calm tropical sea from surface to sandy "
                          "sea floor, gentle wavy water surface along the very top edge, sunlight "
                          "rays from the top, blue gradient getting darker downward, seaweed and "
                          "coral silhouettes only along the bottom edge, a few tiny bubbles, "
                          f"{FLAT}, {TAIL}")),
    "bg_defense": (768, 1664, 2,
                   ("portrait, top-down view of a sunny elementary schoolyard lawn, soft bright "
                    "grass with a faint mowing texture, a strip of red running track along the very "
                    "top edge, a few tiny white flowers and pebbles near the left and right edges, "
                    f"wide open empty lawn in the middle, {FLAT}, {TAIL}")),
    "bg_swarm": (768, 1664, 2,
                 ("portrait, top-down view of a grassy park field on a summer evening, dusky blue "
                  "green grass, a few small bushes and stones along the edges, soft warm glow of "
                  "street lamps in the corners, wide open empty grass in the middle, "
                  f"{FLAT}, {TAIL}")),
}


def generate(name, width, height, seed, prompt):
    with tempfile.TemporaryDirectory() as tmp:
        png = os.path.join(tmp, f"{name}.png")
        subprocess.run(["mlxgen", "generate", "--model", MODEL, "--prompt", prompt,
                        "--steps", str(STEPS), "--seed", str(seed),
                        "--width", str(width), "--height", str(height), "--output", png],
                       check=True)
        Image.open(png).convert("RGB").save(os.path.join(OUT, f"{name}.jpg"), quality=85)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name in sys.argv[1:] or BACKDROPS:
        width, height, seed, prompt = BACKDROPS[name]
        generate(name, width, height, seed, prompt)
        print(f"  {name}.jpg")
