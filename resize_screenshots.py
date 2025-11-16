#!/usr/bin/env python3
"""
Resize screenshots to App Store requirements
Target: 1284 × 2778px (iPhone 14 Pro Max)
"""

from PIL import Image
import os

# Source and destination directories
source_dir = 'screenshots'
dest_dir = 'screenshots_appstore'

# Create destination directory
os.makedirs(dest_dir, exist_ok=True)

# Target size for App Store
target_size = (1284, 2778)

# Screenshot files
screenshots = ['gameplay.png', 'preferences.png', 'gameover.png', 'win.png']

print(f"Resizing screenshots to {target_size[0]}x{target_size[1]}px for App Store...")

for filename in screenshots:
    source_path = os.path.join(source_dir, filename)
    dest_path = os.path.join(dest_dir, filename)

    # Open image
    img = Image.open(source_path)
    current_size = img.size

    # Resize image using high-quality Lanczos resampling
    resized_img = img.resize(target_size, Image.Resampling.LANCZOS)

    # Save resized image
    resized_img.save(dest_path, 'PNG', optimize=True)

    print(f"  ✓ {filename}: {current_size[0]}x{current_size[1]} → {target_size[0]}x{target_size[1]}")

print(f"\nAll screenshots resized successfully!")
print(f"App Store ready screenshots saved to: {dest_dir}/")
