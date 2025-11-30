#!/usr/bin/env python3
"""
Generates iOS app icons for Workouts.

Usage:
    python3 scripts/generate_icon.py

Requirements:
    pip install Pillow
"""

from PIL import Image, ImageDraw
from pathlib import Path
import math

# Color palette - energetic orange/coral for fitness
ORANGE = (255, 107, 53)         # #FF6B35 - energetic orange
ORANGE_LIGHT = (255, 140, 90)   # Lighter orange
ORANGE_DARK = (230, 80, 30)     # Darker orange
DARK_BG = (30, 30, 35)          # Near black
DARK_BG_LIGHT = (50, 50, 58)    # Slightly lighter
ACCENT = (255, 200, 87)         # Gold accent


def create_icon(size: int) -> Image.Image:
    """Create a single icon at the specified size."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # iOS icons are square with rounded corners (handled by iOS)
    # Fill with gradient background
    for y in range(size):
        ratio = y / size
        r = int(DARK_BG[0] + (DARK_BG_LIGHT[0] - DARK_BG[0]) * ratio)
        g = int(DARK_BG[1] + (DARK_BG_LIGHT[1] - DARK_BG[1]) * ratio)
        b = int(DARK_BG[2] + (DARK_BG_LIGHT[2] - DARK_BG[2]) * ratio)
        draw.line([(0, y), (size, y)], fill=(r, g, b, 255))
    
    # Draw stylized dumbbell
    center_x = size // 2
    center_y = size // 2
    
    # Bar dimensions
    bar_width = int(size * 0.5)
    bar_height = max(2, int(size * 0.08))
    
    # Weight dimensions
    weight_width = max(3, int(size * 0.12))
    weight_height = int(size * 0.35)
    
    # Draw center bar with gradient
    bar_left = center_x - bar_width // 2
    bar_top = center_y - bar_height // 2
    for row in range(bar_height):
        ratio = row / max(1, bar_height)
        r = int(ORANGE_DARK[0] + (ORANGE[0] - ORANGE_DARK[0]) * (1 - abs(ratio - 0.5) * 2))
        g = int(ORANGE_DARK[1] + (ORANGE[1] - ORANGE_DARK[1]) * (1 - abs(ratio - 0.5) * 2))
        b = int(ORANGE_DARK[2] + (ORANGE[2] - ORANGE_DARK[2]) * (1 - abs(ratio - 0.5) * 2))
        draw.rectangle(
            [bar_left, bar_top + row, bar_left + bar_width, bar_top + row + 1],
            fill=(r, g, b, 255)
        )
    
    # Draw left weight
    left_weight_x = bar_left - weight_width // 2
    weight_top = center_y - weight_height // 2
    draw_weight(draw, left_weight_x, weight_top, weight_width, weight_height)
    
    # Draw right weight
    right_weight_x = bar_left + bar_width - weight_width // 2
    draw_weight(draw, right_weight_x, weight_top, weight_width, weight_height)
    
    # Draw inner weights (smaller)
    inner_weight_width = int(weight_width * 0.8)
    inner_weight_height = int(weight_height * 0.7)
    inner_weight_top = center_y - inner_weight_height // 2
    
    inner_left_x = bar_left + weight_width
    draw_weight(draw, inner_left_x, inner_weight_top, inner_weight_width, inner_weight_height, lighter=True)
    
    inner_right_x = bar_left + bar_width - weight_width - inner_weight_width
    draw_weight(draw, inner_right_x, inner_weight_top, inner_weight_width, inner_weight_height, lighter=True)
    
    return img


def draw_weight(draw, x, y, width, height, lighter=False):
    """Draw a single weight plate with gradient."""
    base_color = ORANGE_LIGHT if lighter else ORANGE
    dark_color = ORANGE if lighter else ORANGE_DARK
    
    # Round the corners slightly
    corner_radius = max(1, width // 4)
    
    for row in range(height):
        # Vertical gradient for 3D effect
        ratio = row / max(1, height)
        intensity = 1 - abs(ratio - 0.5) * 1.5
        intensity = max(0.3, min(1.0, intensity))
        
        r = int(dark_color[0] + (base_color[0] - dark_color[0]) * intensity)
        g = int(dark_color[1] + (base_color[1] - dark_color[1]) * intensity)
        b = int(dark_color[2] + (base_color[2] - dark_color[2]) * intensity)
        
        # Adjust width for rounded corners at top and bottom
        inset = 0
        if row < corner_radius:
            inset = corner_radius - row
        elif row > height - corner_radius:
            inset = row - (height - corner_radius)
        
        if width - inset * 2 > 0:
            draw.rectangle(
                [x + inset, y + row, x + width - inset, y + row + 1],
                fill=(r, g, b, 255)
            )


def generate_all_icons():
    """Generate icons for all required iOS sizes."""
    script_dir = Path(__file__).parent
    output_dir = script_dir.parent / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    
    # iOS icon sizes: (base_size, scales)
    ios_sizes = [
        (20, [1, 2, 3]),    # Notification
        (29, [1, 2, 3]),    # Settings
        (40, [1, 2, 3]),    # Spotlight
        (60, [2, 3]),       # iPhone App
        (76, [1, 2]),       # iPad App
        (83.5, [2]),        # iPad Pro
        (1024, [1]),        # App Store
    ]
    
    for base_size, scales in ios_sizes:
        for scale in scales:
            actual_size = int(base_size * scale)
            icon = create_icon(actual_size)
            
            # Format filename
            if base_size == 1024:
                filename = f'Icon-App-1024x1024@1x.png'
            elif base_size == 83.5:
                filename = f'Icon-App-83.5x83.5@{scale}x.png'
            else:
                filename = f'Icon-App-{int(base_size)}x{int(base_size)}@{scale}x.png'
            
            output_path = output_dir / filename
            icon.save(output_path, 'PNG')
            print(f'✓ {actual_size}x{actual_size} → {filename}')
    
    print(f'\nIcons saved to: {output_dir}')


if __name__ == '__main__':
    generate_all_icons()

