# 📝 Guide: Training Your App to Recognize YOUR Handwriting

## Overview
Your CBT Journal app now has **personalized handwriting recognition** that learns and improves over time. This guide shows you how to make it work better for YOUR specific writing style.

## 🎯 Three-Layer Recognition System

Your app uses three complementary techniques:

1. **Vision Framework** (Apple's OCR) - Fast, hardware-accelerated text detection
2. **Custom Vocabulary** - Tells Vision which words to expect
3. **Handwriting Corrections Dictionary** - Maps YOUR specific OCR errors to correct words
4. **Apple Intelligence LLM** - Uses context to correct remaining errors

## 🔧 How to Improve Recognition Over Time

### Step 1: Identify Your Handwriting Patterns

After scanning a journal page:

1. Expand **"Détails techniques"** at the bottom
2. Read the **"Texte OCR brut"** section
3. Compare it to what you actually wrote
4. Note recurring errors

**Example:**
```
You wrote: "Excellente journée"
Vision read: "Ellente journée"
→ Your letter "x" looks like "l" to Vision
```

### Step 2: Add Words to Custom Vocabulary

Open `ContentView.swift` and find this section (around line 195):

```swift
request.customWords = [
    // === ADD YOUR OWN WORDS BELOW ===
    // Look at your journal and add words you write often
]
```

Add words you use frequently:

```swift
request.customWords = [
    // ... existing words ...
    
    // Your personal activities
    "bricolage",
    "jardinage", 
    "méditation",
    
    // Your emotions
    "anxieux",
    "serein",
    "énervé",
    
    // People you mention
    "Sophie",
    "Marc",
    
    // Places
    "Paris",
    "bureau",
]
```

**When to use:** Words you write often that are spelled correctly but Vision doesn't recognize.

### Step 3: Add to Handwriting Corrections Dictionary

Find this section (around line 100):

```swift
private let handwritingCorrectionsDict: [String: String] = [
    // === ADD YOUR OWN PATTERNS HERE ===
]
```

Add YOUR specific OCR errors:

```swift
private let handwritingCorrectionsDict: [String: String] = [
    // ... existing corrections ...
    
    // Your personal patterns (what Vision sees → what it should be)
    "Ellente": "Excellente",  // You write "x" like "ll"
    "parl": "parlé",           // You drop accent marks
    "travai": "travail",       // You write "l" that looks like "i"
    "c": "à",                  // Your "à" looks like "c"
    "el": "et",                // Your "t" looks like "l"
]
```

**When to use:** When Vision consistently misreads specific letter combinations in YOUR handwriting.

### Step 4: Test and Iterate

1. Save your changes
2. Scan the same page again
3. Check if accuracy improved
4. Repeat the process

## 💡 Pro Tips for Better Recognition

### Writing Tips

1. **Date formatting**: Write dates clearly at the top
   - ✅ "Lundi 13 janvier 2026"
   - ❌ "13/1" (ambiguous)

2. **Consistent abbreviations**: Vision learns patterns
   - If you write "déj" for "déjeuner", add it to customWords
   - Stick to the same abbreviation every time

3. **Physical writing**:
   - Use lined paper or a template
   - Avoid overlapping text
   - Leave space between lines
   - Don't write in margins

4. **Photography**:
   - Good lighting (natural daylight is best)
   - Straight-on angle (not at an angle)
   - No shadows on the page
   - Sharp focus (tap to focus on phone)

### Understanding Confidence Scores

In the app, you'll see an "OCR Confidence" percentage:

- **80-100%**: 🟢 Excellent - Vision is very confident
- **60-80%**: 🟡 Good - Some ambiguous words
- **Below 60%**: 🔴 Poor - Many errors, add more corrections

## 📊 How the Corrections Work

### Before Corrections:
```
OCR Output: "Ellente mui, bevé c 6H, Spori an midi"
Confidence: 65%
```

### After Adding Corrections:
```swift
"Ellente": "Excellente"
"mui": "nuit"
"bevé": "levé"
"c": "à"
"Spori": "Sport"
"an": "au"
```

### LLM Receives:
```
"Excellente nuit, levé à 6H, Sport au midi"
Confidence: 95% (effective)
```

## 🧠 How Apple Intelligence Helps

The LLM receives THREE inputs:

1. **Raw OCR text** - What Vision initially detected
2. **Text with alternatives** - Multiple candidates for low-confidence words
3. **Your personal corrections** - Your handwriting-specific patterns

The LLM then:
- Applies your corrections first
- Uses context to choose between alternatives
- Intelligently infers missing words
- Preserves your personal writing style

## 📈 Building Your Personal Dictionary Over Time

### Week 1: Foundation (5-10 corrections)
Focus on the most common errors you see repeatedly.

### Week 2-4: Expansion (20-30 corrections)
Add domain-specific words (emotions, activities, places).

### Month 2+: Refinement (50+ corrections)
Fine-tune edge cases and rare words.

**Result**: After a month of use, you should see 85-95%+ effective accuracy!

## 🔬 Advanced: Exporting Your Corrections

If you want to back up your corrections or share between devices, you can:

1. Copy your `personalHandwritingCorrections` dictionary
2. Save to a JSON file:

```swift
// Add this method to TextRecognitionViewModel
func exportCorrections() -> Data? {
    try? JSONEncoder().encode(handwritingCorrectionsDict)
}

func importCorrections(from data: Data) {
    // Load corrections from file
}
```

## 🆘 Troubleshooting

### "Vision finds no text"
- ✅ Check image preprocessing settings
- ✅ Ensure good lighting in photo
- ✅ Make sure handwriting is dark enough

### "Corrections not working"
- ✅ Check spelling in corrections dictionary
- ✅ Use lowercase for most entries (unless proper nouns)
- ✅ Look at raw OCR to see exact what Vision detected

### "Still seeing same errors"
- ✅ Vision might be reading it differently each time
- ✅ Check "Text with alternatives" for multiple candidates
- ✅ Consider rewriting that word more clearly in future entries

## 🎓 Example: Complete Workflow

1. **Write entry**: "Lundi 13 janvier - Excellente journée! Levé à 6h, sport au midi."

2. **Scan & check raw OCR**: "Lundi 13 jammer - Ellente journée! bevé c 6h, Spori an midi."

3. **Identify patterns**:
   - "jammer" → "janvier"
   - "Ellente" → "Excellente"
   - "bevé" → "levé"
   - "c" → "à"
   - "Spori" → "Sport"
   - "an" → "au"

4. **Add to dictionary**:
```swift
private let handwritingCorrectionsDict: [String: String] = [
    "jammer": "janvier",
    "Ellente": "Excellente",
    "bevé": "levé",
    "c": "à",
    "Spori": "Sport",
    "an": "au",
]
```

5. **Scan again**: Now reads perfectly!

6. **Next entries**: These same patterns will be automatically corrected.

## 🚀 Summary

Your app learns YOUR handwriting by:
1. Teaching Vision which words to expect (customWords)
2. Mapping your specific OCR errors (corrections dictionary)
3. Using LLM intelligence to fix remaining issues

**The more you use it and add corrections, the smarter it gets!**

Start small, add corrections as you notice patterns, and watch your accuracy improve over time. 🎯
