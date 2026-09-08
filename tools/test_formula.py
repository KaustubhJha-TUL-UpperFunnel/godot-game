import math

def create_platform_params(x0, y0, x1, y1, depth=18.0):
    dx = x1 - x0
    dy = y1 - y0
    length = math.hypot(dx, dy)
    rot = math.atan2(dy, dx)
    
    # Midpoint on the surface
    mx = (x0 + x1) * 0.5
    my = (y0 + y1) * 0.5
    
    half_depth = depth * 0.5
    # Normal pointing down
    # Perpendicular to (cos(rot), sin(rot)) pointing down is (-sin(rot), cos(rot))
    cx = mx - math.sin(rot) * half_depth
    cy = my + math.cos(rot) * half_depth
    
    # Let's check navigation_segment from level_platform.gd:
    # half = size * 0.5 = (length * 0.5, depth * 0.5)
    # a = transform * (-half.x, 0)
    # b = transform * (half.x, 0)
    # in local coords, (-half.x, 0) transformed is (cx - half.x * cos(rot), cy - half.x * sin(rot))
    # thickness = depth * 0.5
    # a.y -= thickness
    # b.y -= thickness
    hx = length * 0.5
    ax = cx - hx * math.cos(rot)
    ay = cy - hx * math.sin(rot) - half_depth
    bx = cx + hx * math.cos(rot)
    by = cy + hx * math.sin(rot) - half_depth
    
    print(f"Target P0: ({x0:.1f}, {y0:.1f}), P1: ({x1:.1f}, {y1:.1f})")
    print(f"Params: pos=({cx:.2f}, {cy:.2f}), rot={rot:.4f}, size=({length:.2f}, {depth:.2f})")
    print(f"Computed nav segment: A=({ax:.1f}, {ay:.1f}), B=({bx:.1f}, {by:.1f})")
    print(f"Nav segment diff: dA=({ax-x0:.2f}, {ay-y0:.2f}), dB=({bx-x1:.2f}, {by-y1:.2f})")

create_platform_params(865, 781, 940, 802)
create_platform_params(940, 802, 1010, 826)
create_platform_params(1010, 826, 1090, 818)
create_platform_params(1090, 818, 1163, 795)
