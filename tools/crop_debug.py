from PIL import Image

img = Image.open("tools/_debug_map1_current_platforms.png")
# Upper tier: x: 700 to 1400, y: 350 to 500
crop_upper = img.crop((700, 350, 1400, 500))
crop_upper.save("tools/_debug_map1_upper_platforms.png")

# Lower bridge: x: 800 to 1250, y: 750 to 860
crop_lower = img.crop((800, 750, 1250, 860))
crop_lower.save("tools/_debug_map1_lower_platforms.png")

print("Saved upper and lower crops.")
