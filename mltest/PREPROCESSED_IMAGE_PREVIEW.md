# 🖼️ Preprocessed Image Preview Feature

## Overview

Your app now displays the preprocessed (posterized) image side-by-side with the original, so you can see exactly what Vision Framework is analyzing!

## Features

### 1. **Side-by-Side Comparison** 👀

After clicking "Analyser l'entrée", you'll see:
- **Left**: Your original photo
- **Right**: The posterized/preprocessed version with a purple border

This lets you:
- See how aggressive the posterization is
- Verify text is still readable after processing
- Understand why OCR confidence is high/low
- Tune the preprocessing settings visually

### 2. **Toggleable View** 🔄

Use the **"Afficher la comparaison"** toggle to:
- **ON** (default): Show both images side-by-side
- **OFF**: Show only the original image (cleaner view)

### 3. **Color Count Badge** 🎨

Below the images, you'll see:
```
🎨 Image postérisée avec 4 niveaux (≈64 couleurs)
```

This tells you exactly how many colors are in the processed image.

### 4. **Save Preprocessed Image** 💾

New **"Sauvegarder"** button appears after analysis.

**Why save the preprocessed image?**
- Compare results with different settings
- Use it for training/debugging
- Share examples with others
- Document your preprocessing tuning journey

**What gets saved:**
- PNG format (lossless)
- Full resolution preprocessed image
- The exact image that Vision analyzed
- Filename: `preprocessed_[timestamp].png`

## Usage Guide

### Basic Workflow:

1. **Select an image** (photo or file)
2. **Click "Analyser l'entrée"**
3. **Wait for processing** (~5-10 seconds)
4. **View comparison**:
   - Original on left
   - Posterized on right
5. **Check the effect**:
   - Is text crisp and readable?
   - Are colors vivid?
   - Is background pure white?
6. **If needed**: Adjust `posterizationLevel`, `contrastLevel`, `gammaLevel` in code and re-analyze

### Example Observations:

**Good preprocessing:**
```
✅ Text: Jet black, sharp edges
✅ Background: Pure white
✅ Blue pen: Vivid blue (#0000FF)
✅ Confidence: 85%+
```

**Too aggressive:**
```
❌ Text: Some letters merged together
❌ Background: Some spots remain gray
❌ Effect: Lost detail
→ Increase posterizationLevel from 3 to 4
```

**Too soft:**
```
⚠️ Text: Still grayish, not pure black
⚠️ Background: Still has noise/texture
⚠️ Confidence: 60-70%
→ Decrease posterizationLevel from 6 to 4
→ Increase contrastLevel from 1.5 to 2.0
```

## Visual Indicators

### Original Image:
- Gray border (subtle)
- Label: "Original"
- Shows your actual photo

### Preprocessed Image:
- **Purple border** (thicker, stands out)
- Label: "Prétraité ✨" (with sparkle icon)
- Shows what Vision sees

### Info Badge:
```
🎨 Image postérisée avec [N] niveaux (≈[X] couleurs)
```

Example interpretations:
- `4 niveaux (≈64 couleurs)` → **Default** - good balance
- `3 niveaux (≈27 couleurs)` → **Extreme** - comic book style
- `6 niveaux (≈216 couleurs)` → **Moderate** - subtle effect

## Tuning Tips by Visual Inspection

### If Background Looks Grayish:
**Problem**: Not enough contrast
**Solution**:
```swift
private let contrastLevel: Double = 2.5  // Increase from 2.0
private let gammaLevel: Double = 0.3     // Decrease from 0.4
```

### If Text Looks Blurry:
**Problem**: Too much posterization blending
**Solution**:
```swift
private let posterizationLevelValue: Int = 5  // Increase from 4
```

### If Colors Look Washed Out:
**Problem**: Not enough color separation
**Solution**:
```swift
private let posterizationLevelValue: Int = 3  // Decrease to 3
// This creates more distinct color bands
```

### If Text is Lost/Merged:
**Problem**: Too aggressive processing
**Solution**:
```swift
private let posterizationLevelValue: Int = 6  // Increase to preserve detail
private let gammaLevel: Double = 0.5          // Less binarization
```

## Advanced: Comparing Different Settings

Want to test different preprocessing settings?

1. **Analyze with current settings**
2. **Save preprocessed image** → `preprocessed_1.png`
3. **Change settings in code** (e.g., posterizationLevel: 3)
4. **Analyze same image again**
5. **Save preprocessed image** → `preprocessed_2.png`
6. **Open both in Preview** to compare side-by-side
7. **Check OCR confidence** for each
8. **Choose best settings!**

## What You Should See

### Perfect Preprocessing (4 levels, default settings):

**Original Photo:**
- White paper with some yellowing
- Black ballpoint pen
- Some shadows from lighting
- Camera grain visible

**Preprocessed Result:**
- Pure white background (#FFFFFF)
- Jet black text (#000000)
- Maybe 2-3 gray shades for pen pressure variation
- No shadows
- No grain
- Razor-sharp text edges
- Total: ~64 distinct colors

### Expected Color Palette:

With `posterizationLevel: 4`, you get 4³ = 64 colors:

| Color | RGB Value | Example Use |
|-------|-----------|-------------|
| Black | (0, 0, 0) | Most text |
| Dark Gray | (85, 85, 85) | Light pen strokes |
| Mid Gray | (170, 170, 170) | Shadows (if any) |
| White | (255, 255, 255) | Paper background |
| Red | (255, 0, 0) | Red pen highlights |
| Blue | (0, 0, 255) | Blue pen |
| Green | (0, 255, 0) | Green highlighter |
| Yellow | (255, 255, 0) | Yellow highlights |

Plus ~56 other combinations of these RGB levels.

## Keyboard Shortcuts (Future Enhancement)

*Could add:*
- **Cmd+S**: Save preprocessed image
- **Cmd+T**: Toggle comparison view
- **Cmd+[/]**: Cycle through preprocessing presets

## Troubleshooting

### "Prétraité" image not showing?
- **Issue**: Analysis hasn't completed yet
- **Wait**: Processing takes 5-10 seconds
- **Check**: Look for "Analyse complete" in console

### Preprocessed image looks identical to original?
- **Issue**: Settings too subtle
- **Solution**: Use more extreme settings (posterizationLevel: 3, gammaLevel: 0.3)

### Can't see both images side-by-side?
- **Issue**: Window too narrow
- **Solution**: Expand window width or turn off comparison toggle

### "Sauvegarder" button not appearing?
- **Issue**: Must analyze image first
- **Solution**: Click "Analyser l'entrée" and wait for completion

## Summary

The preprocessed image preview gives you:

✅ **Visual feedback** on preprocessing quality  
✅ **Comparison** between original and processed  
✅ **Confidence** in your settings  
✅ **Ability to save** for documentation  
✅ **Toggle** for cleaner view when not needed  

This makes tuning the posterization settings much easier - you can SEE the effect before checking OCR results!

**Pro Tip**: The preprocessed image is what Vision Framework analyzes. If it looks good to your eyes (crisp text, high contrast), it'll probably work well for OCR! 👁️
