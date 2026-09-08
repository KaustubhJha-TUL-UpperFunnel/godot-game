import math

def check_exact(x0, y0, x1, y1, depth=18.0):
    dx = x1 - x0
    dy = y1 - y0
    length = math.hypot(dx, dy)
    rot = math.atan2(dy, dx)
    
    half_depth = depth * 0.5
    cx = (x0 + x1) * 0.5
    cy = (y0 + y1) * 0.5 + half_depth
    
    hx = length * 0.5
    ax = cx - hx * math.cos(rot)
    ay = cy - hx * math.sin(rot) - half_depth
    bx = cx + hx * math.cos(rot)
    by = cy + hx * math.sin(rot) - half_depth
    
    print(f"Target: ({x0:.1f}, {y0:.1f}) -> ({x1:.1f}, {y1:.1f})")
    print(f"Computed nav: ({ax:.1f}, {ay:.1f}) -> ({bx:.1f}, {by:.1f})")
    print(f"Errors: {abs(ax-x0):.6f}, {abs(ay-y0):.6f}, {abs(bx-x1):.6f}, {abs(by-y1):.6f}")

check_exact(865, 781, 940, 802)
check_exact(940, 802, 1010, 826)
check_exact(1010, 826, 1090, 818)
check_exact(1090, 818, 1163, 795)
