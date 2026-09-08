from PIL import Image, ImageDraw

img = Image.open("descent/assets/maps/map_01_fire_vertical.png").convert("RGB")

crop = img.crop((500, 500, 1100, 720))
cw, ch = crop.size

overlay = crop.copy()
draw = ImageDraw.Draw(overlay)

for y in range(500, 720, 10):
    rel_y = y - 500
    draw.line([(0, rel_y), (cw, rel_y)], fill=(100, 100, 100), width=1)
    draw.text((5, rel_y), str(y), fill=(255, 255, 0))

for x in range(500, 1100, 50):
    rel_x = x - 500
    draw.line([(rel_x, 0), (rel_x, ch)], fill=(100, 100, 100), width=1)
    draw.text((rel_x + 2, ch - 15), str(x), fill=(0, 255, 255))

overlay.save("tools/_map1_mid_grid.png")
print("Saved tools/_map1_mid_grid.png")
