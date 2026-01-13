# 🎨 Quick Start: Posterized Color Processing

## What Changed?

Your app now uses **posterized color** instead of grayscale for OCR preprocessing.

### Old Approach:
- Convert to grayscale → Lose all color information
- Result: Black and white only

### New Approach:
- Posterize to 64 colors → Keep color but with extreme contrast
- Result: High-contrast "retro" look with vivid colors (black, red, blue, yellow, green, purple, white)

---

## 🎯 Why This Is Better

1. **Color preservation**: If you use different colored pens (blue for tasks, red for emotions), that information is kept
2. **Extreme contrast**: Almost binary per RGB channel = very sharp text edges
3. **Noise reduction**: Limited palette (64 vs 16.7M colors) = less noise
4. **Better OCR**: Vision gets cleaner, more distinct input

---

## ⚙️ Easy Tuning

Open `ContentView.swift` and find these three lines (around line 150):

```swift
private let posterizationLevel: Int = 4   // Fewer colors
private let contrastLevel: Double = 2.0   // More contrast
private let gammaLevel: Double = 0.4      // More binary
```

### Quick Presets:

**Too blurry? Want MORE binary:**
```swift
private let posterizationLevel: Int = 3   // Only 27 colors
private let contrastLevel: Double = 2.5   // Maximum contrast
private let gammaLevel: Double = 0.3      // Very binary
```

**Too harsh? Want SOFTER effect:**
```swift
private let posterizationLevel: Int = 6   // 216 colors
private let contrastLevel: Double = 1.8   // Moderate contrast
private let gammaLevel: Double = 0.5      // Less binary
```

**Using highlighters or multiple ink colors? Keep MORE colors:**
```swift
private let posterizationLevel: Int = 8   // 512 colors
private let contrastLevel: Double = 1.5   // Gentle contrast
private let gammaLevel: Double = 0.6      // Subtle binarization
```

---

## 📊 What Each Setting Does

### posterizationLevel (2-8)
Controls how many colors per RGB channel.

| Value | Total Colors | Visual Effect |
|-------|-------------|---------------|
| 2 | 8 | Pure primary colors only (Black, Red, Green, Blue, Cyan, Magenta, Yellow, White) |
| 3 | 27 | Very posterized, comic-book style |
| **4** | **64** | ✅ **Default** - Good balance |
| 6 | 216 | Subtle posterization, more gradation |
| 8 | 512 | Barely noticeable effect |

### contrastLevel (1.5-2.5)
How much to separate lights from darks.

| Value | Effect |
|-------|--------|
| 1.5 | Strong contrast |
| **2.0** | ✅ **Default** - Very strong |
| 2.5 | Maximum contrast (may lose detail) |

### gammaLevel (0.3-0.6)
How "binary" the result looks.

| Value | Effect |
|-------|--------|
| 0.3 | Extreme - pure blacks and whites |
| **0.4** | ✅ **Default** - Almost binary |
| 0.5 | Strong binarization |
| 0.6 | Moderate effect |

---

## 🧪 Recommended Combinations

### For Clean Handwriting (single pen color):
```swift
posterizationLevel: 3   // 27 colors
contrastLevel: 2.5      // Maximum
gammaLevel: 0.3         // Very binary
```
**Result:** Almost pure black on white, maximum clarity

### For Mixed Pen Colors (blue, black, red):
```swift
posterizationLevel: 4   // 64 colors (DEFAULT)
contrastLevel: 2.0      // Very strong
gammaLevel: 0.4         // Almost binary
```
**Result:** Distinct colors, high contrast

### For Highlighters + Multiple Pens:
```swift
posterizationLevel: 6   // 216 colors
contrastLevel: 1.8      // Strong
gammaLevel: 0.5         // Moderate binary
```
**Result:** More color variety preserved

---

## 🎨 Visual Examples

### With Default Settings (4/2.0/0.4):

**Input:** Photo of handwritten journal with black pen on white paper
**Output:** 
- Paper becomes pure white (#FFFFFF)
- Text becomes jet black (#000000)
- Any blue pen becomes vivid blue (#0000FF)
- Any red markings become bright red (#FF0000)
- Only ~64 total colors in entire image

**Effect:** Looks like a high-contrast digital scan or comic book art

---

## 🔬 Testing Your Settings

After changing the values:

1. **Build and run** the app
2. **Scan the same page** you scanned before
3. **Check console logs** - you'll see:
   ```
   🎨 Posterized to ~27 colors (3 levels per channel)
   🎨 Applied super aggressive contrast (level: 2.5) with color boost
   ⚡️ Applied extreme gamma adjustment (level: 0.3) for binary-like appearance
   ```
4. **Compare OCR confidence** - aim for 80%+ in "Confiance OCR"
5. **Check "Texte OCR brut"** in Détails techniques - fewer errors = better settings

---

## 💡 Pro Tips

1. **Start extreme, then back off**: Try `3/2.5/0.3` first. If it's too harsh, increase each value.

2. **Match your paper**: 
   - Clean white paper → Lower values (more extreme)
   - Aged/yellowed paper → Higher values (preserve more detail)

3. **Match your pen**:
   - Single black pen → Go extreme
   - Multiple colors → Keep more colors

4. **Check preprocessing in Photos app**: The processed image is used for OCR. If it looks good to your eyes, it'll probably be good for Vision.

5. **Console is your friend**: Watch the emoji logs during processing to see what's happening.

---

## 🎯 Summary

**Default (balanced):**
```swift
posterizationLevel: 4   // 64 colors
contrastLevel: 2.0      // Very strong contrast
gammaLevel: 0.4         // Almost binary
```

**More extreme (for clean writing):**
```swift
posterizationLevel: 3   // 27 colors
contrastLevel: 2.5      // Maximum contrast
gammaLevel: 0.3         // Very binary
```

**Less extreme (for color journals):**
```swift
posterizationLevel: 6   // 216 colors
contrastLevel: 1.8      // Strong contrast
gammaLevel: 0.5         // Moderate binary
```

**Test, observe, adjust!** The perfect settings depend on your handwriting style and paper quality.

---

## 📚 More Info

See `IMAGE_PREPROCESSING_EXPLAINED.md` for detailed technical explanation of how posterization works and what each filter does.
