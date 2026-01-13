# OCR Accuracy Improvements

This document outlines the improvements made to enhance Vision OCR accuracy for handwritten journal analysis.

## 🎯 Key Improvements

### 1. **Image Preprocessing** 
Before OCR, the image is now enhanced using Core Image filters:

- **Exposure Adjustment**: Slight brightness boost (+0.5 EV) to handle dim/underexposed photos
- **Contrast Enhancement**: 20% contrast increase to make text stand out from background
- **Sharpening**: Luminance sharpening (0.7) to improve text edge definition
- **Noise Reduction**: Minimal noise reduction to clean up grainy images without losing detail

**Result**: Cleaner, more readable text for Vision to process.

### 2. **Advanced Vision Settings**

```swift
request.recognitionLevel = .accurate           // Use most accurate (but slower) model
request.usesLanguageCorrection = true          // Apply language-aware corrections
request.recognitionLanguages = ["fr-FR", "en-US"]  // Prioritize French & English
request.automaticallyDetectsLanguage = true    // Detect language per text block
request.minimumTextHeight = 0.0                // Detect even very small text
```

**Result**: Better detection of French handwriting with fewer language-related errors.

### 3. **Text Sorting by Position**

Observations are now sorted top-to-bottom, left-to-right:

```swift
let sortedObservations = observations.sorted { obs1, obs2 in
    let y1 = 1.0 - obs1.boundingBox.midY  // Vision uses bottom-left origin
    let y2 = 1.0 - obs2.boundingBox.midY
    
    if abs(y1 - y2) < 0.05 {  // Same line? Sort horizontally
        return obs1.boundingBox.minX < obs2.boundingBox.minX
    }
    return y1 < y2  // Different lines? Sort vertically
}
```

**Result**: Text flows naturally in reading order, preserving journal structure.

### 4. **Multiple OCR Candidates**

Now capturing up to 5 alternatives per text block:

```swift
let candidates = observation.topCandidates(5)

if confidence < 0.9 {
    // Include alternatives for uncertain words
    textWithAlternatives += "[\(text) OR \(alt1) OR \(alt2)] "
}
```

**Result**: LLM can choose the best candidate based on context.

### 5. **Enhanced LLM Prompt**

The LLM now receives:
- **Primary text**: Best OCR guess
- **Alternatives**: For low-confidence words (< 90%)
- **Instructions**: Explicitly told to correct OCR errors while preserving personal writing style

```
TEXTE OCR (avec alternatives pour mots incertains) :
Mardi 6 [jammer OR janvier OR jamier] 2026
[Ellente OR Excellente OR Bellente] nuit, [bevé OR levé OR beve] à 6H.
```

**Result**: LLM intelligently corrects "jammer" → "janvier" but preserves personal abbreviations.

### 6. **Better Confidence Tracking**

```swift
print("  📄 Text: \"\(text)\" (confidence: \(String(format: "%.2f", confidence)))")
```

**Result**: Better debugging and ability to trigger alternative handling only when needed.

## 📊 Expected Improvements

### Before:
```
OCR Output: "Mardi 6 jammer 2026 Ellente mui, bevé c 6H"
Confidence: 0.50 (50%)
```

### After:
```
OCR Output (with preprocessing): "Mardi 6 janvier 2026 Excellente nuit, levé à 6H"
Confidence: 0.75-0.85 (75-85%)
LLM Correction: Intelligently fixes remaining errors while preserving style
```

## 🔧 Technical Details

### Image Preprocessing Pipeline

1. **Input**: Original NSImage from camera/photo library
2. **Convert**: NSImage → CGImage → CIImage
3. **Filter Chain**:
   - CIExposureAdjust (EV: +0.5)
   - CIColorControls (Contrast: 1.2x)
   - CISharpenLuminance (Sharpness: 0.7)
   - CINoiseReduction (Level: 0.02)
4. **Output**: Enhanced CIImage → CGImage → NSImage
5. **Fallback**: If preprocessing fails, uses original image

### Vision OCR Configuration

- **Hardware Acceleration**: Uses GPU when available via CIContext
- **Latest Model**: Attempts to use VNRecognizeTextRequestRevision3 on macOS 14+
- **Language Priority**: French first, English second, auto-detect as fallback

### LLM Intelligence Layer

The LLM is now instructed to:
1. ✅ Correct obvious OCR errors (jammer → janvier)
2. ✅ Use context to choose between alternatives
3. ✅ Preserve personal writing style and abbreviations
4. ❌ NOT invent content not in the original
5. ❌ NOT create phantom journal entries

## 🧪 Testing Recommendations

Test with various challenging scenarios:

1. **Poor Lighting**: Underexposed or overexposed photos
2. **Low Contrast**: Pencil on white paper, faded ink
3. **Small Text**: Tiny handwriting
4. **Messy Handwriting**: Quick scribbles, unclear letters
5. **Mixed Languages**: French with English words
6. **Rotated/Skewed**: Photos taken at an angle

## 🎯 Further Improvements (Future)

Potential enhancements:
- [ ] Auto-rotation detection and correction
- [ ] Perspective correction for angled photos
- [ ] Adaptive binarization for different paper types
- [ ] Custom Vision model fine-tuned on journal handwriting
- [ ] User feedback loop to improve LLM corrections over time

## 📚 References

- [Vision Framework - Apple Developer](https://developer.apple.com/documentation/vision)
- [VNRecognizeTextRequest - Apple Developer](https://developer.apple.com/documentation/vision/vnrecognizetextrequest)
- [Core Image Filter Reference](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Reference/CoreImageFilterReference/)
