from PIL import Image, ImageDraw

img = Image.open("descent/assets/maps/map_01_fire_vertical.png").convert("RGBA")

# Upper bridge: x from 680 to 1250, y from 370 to 480
test_img = img.crop((680, 370, 1250, 480))
draw = ImageDraw.Draw(test_img)

for y in range(370, 480, 10):
    rel_y = y - 370
    draw.line([(0, rel_y), (570, rel_y)], fill=(120, 120, 120, 150), width=1)
    draw.text((5, rel_y - 10), f"y={y}", fill=(255, 255, 0, 255))

for x in range(700, 1250, 50):
    rel_x = x - 680
    draw.line([(rel_x, 0), (rel_x, 110)], fill=(120, 120, 120, 150), width=1)
    draw.text((rel_x + 2, 95), f"x={x}", fill=(0, 255, 255, 255))

test_img.save("tools/_debug_upper_bridge_inspect.png")
print("Saved tools/_debug_upper_bridge_inspect.png")
