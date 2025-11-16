#!/usr/bin/env python3
"""
Generate app icons for Monsters from the Dot Grid
"""

from PIL import Image, ImageDraw
import os

def create_icon(size):
    """Create an app icon with a dot grid and monster triangle"""
    # Create image with black background
    img = Image.new('RGB', (size, size), color='#000000')
    draw = ImageDraw.Draw(img)

    # Calculate dot spacing based on icon size
    dot_spacing = size // 8
    dot_size = max(2, size // 60)

    # Draw grid dots
    for row in range(9):
        for col in range(9):
            x = col * dot_spacing
            y = row * dot_spacing
            draw.ellipse(
                [x - dot_size, y - dot_size, x + dot_size, y + dot_size],
                fill='#FFFFFF'
            )

    # Draw monster triangle in center
    center = size // 2
    triangle_size = size // 3

    # Triangle points (pointing up)
    points = [
        (center, center - triangle_size // 2),  # Top
        (center - triangle_size // 2, center + triangle_size // 2),  # Bottom left
        (center + triangle_size // 2, center + triangle_size // 2)   # Bottom right
    ]

    draw.polygon(points, fill='#FF00FF')

    return img

# Icon sizes needed for iOS
sizes = {
    'appstore': 1024,
    'iphone_3x': 180,
    'iphone_2x': 120,
    'ipad_2x': 152,
    'ipad': 76,
    'notification_3x': 60,
    'notification_2x': 40,
    'settings_3x': 87,
    'settings_2x': 58,
    'spotlight_3x': 120,
    'spotlight_2x': 80
}

# Create icons directory
icons_dir = 'DotGrid/DotGrid/Assets.xcassets/AppIcon.appiconset'
os.makedirs(icons_dir, exist_ok=True)

print("Generating app icons...")
for name, size in sizes.items():
    icon = create_icon(size)
    filename = f"{icons_dir}/icon_{name}_{size}x{size}.png"
    icon.save(filename, 'PNG')
    print(f"  Created {name}: {size}x{size}px")

print("\nAll icons generated successfully!")
print(f"Icons saved to: {icons_dir}")
