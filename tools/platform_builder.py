import math
import random
import re
from pathlib import Path

def compute_platform_node(x0, y0, x1, y1, one_way=False, group="", depth=16.0):
    dx = x1 - x0
    dy = y1 - y0
    length = math.hypot(dx, dy)
    rot = math.atan2(dy, dx)
    
    # Midpoint of the top edge
    mx = (x0 + x1) * 0.5
    my = (y0 + y1) * 0.5
    
    half_d = depth * 0.5
    pos_x = mx - half_d * math.sin(rot)
    pos_y = my + half_d * math.cos(rot)
    
    return {
        "pos": (round(pos_x, 3), round(pos_y, 3)),
        "rot": round(rot, 6),
        "size": (round(length, 2), round(depth, 1)),
        "one_way": one_way,
        "group": group
    }

print("Sample computation:")
print(compute_platform_node(740, 436, 800, 440, one_way=True, group="upper_bridge"))
