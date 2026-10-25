"""Outlines the Map builders share (Story 058): a pool of water with rounded, slightly uneven edges in
place of a rectangle. Tooling only; nothing under src/ imports this file."""

import math


def pool_outline(centre, length, width, yaw_degrees=0.0, power=2.6, wobble=0.05, points=40, seed=0):
    """A closed outline in the Map's (x, z): a superellipse `width` across and `length` along its
    local z, turned by yaw_degrees (Godot's sense, as tscn.transform()), its edge pushed in and out
    by up to `wobble` of its size so it does not look drawn with a compass. The same seed gives the
    same outline."""
    yaw = math.radians(yaw_degrees)
    along = (math.sin(yaw), math.cos(yaw))
    across = (math.cos(yaw), -math.sin(yaw))
    out = []
    for i in range(points):
        t = 2.0 * math.pi * i / points
        c, s = math.cos(t), math.sin(t)
        # Superellipse: |x|^p + |z|^p = 1.
        x = math.copysign(abs(c) ** (2.0 / power), c)
        z = math.copysign(abs(s) ** (2.0 / power), s)
        bump = 1.0 + wobble * (math.sin(3 * t + seed) * 0.6 + math.sin(5 * t + 2 * seed) * 0.4)
        lx, lz = x * width / 2.0 * bump, z * length / 2.0 * bump
        out.append((centre[0] + across[0] * lx + along[0] * lz, centre[1] + across[1] * lx + along[1] * lz))
    return out
