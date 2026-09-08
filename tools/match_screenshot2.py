from PIL import Image
import numpy as np

# Let's crop Map 1 around the upper bridge and around the lower bridge and compare with screenshot
map1 = Image.open("descent/assets/maps/map_01_fire_vertical.png")
# Upper bridge: x=700..1200, y=380..500
# Lower bridge: x=800..1200, y=700..850

map1.crop((700, 350, 1150, 520)).save("tools/_debug_match_upper.png")
map1.crop((800, 700, 1200, 860)).save("tools/_debug_match_lower.png")
print("Saved crops.")
