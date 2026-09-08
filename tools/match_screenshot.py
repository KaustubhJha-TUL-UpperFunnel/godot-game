from PIL import Image
import numpy as np

screenshot = Image.open(r"C:\Users\User\.cursor\projects\d-startup-ideas-godot-game\assets\c__Users_User_AppData_Roaming_Cursor_User_workspaceStorage_88b32af5fcd142c832096acb667d9dae_images_Screenshot_2026-09-08_204146-b44c2e8f-56de-463e-b492-7807eee03ad1.png").convert("RGB")
map1 = Image.open("descent/assets/maps/map_01_fire_vertical.png").convert("RGB")

print("Screenshot size:", screenshot.size)
print("Map1 size:", map1.size)

# The screenshot has the teal collider drawn over it, but the posts and brick on the left are visible
# Let's find where the post with the finial on top is in map1!
# In screenshot, there is a post on stone pillar at left, post with rope railing...
