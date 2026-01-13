//
//  ViewModel.swift
//  mltest
//
//  Created by Guillaume BAILLEUL on 13/01/2026.
//

import AppKit
import FoundationModels
import Vision

@MainActor
@Observable
class TextRecognitionViewModel {
    var selectedImage: NSImage?
    var preprocessedImage: NSImage? // Store preprocessed image for display
    var isAnalyzing = false
    var recognizedTexts: [RecognizedText] = []
    var structuredOutput: StructuredOutput?
    var errorMessage: String?
    var modelAvailability: ModelAvailability = .unknown
    
    // Make corrections accessible for UI display
    var personalHandwritingCorrections: [String: String] {
        return handwritingCorrectionsDict
    }
    
    // Expose preprocessing settings for UI display
    var posterizationLevel: Int {
        return posterizationLevelValue
    }
    
    private let model = SystemLanguageModel.default
    
    // MARK: - Preprocessing Configuration
    // Adjust these to change the posterization effect
    //
    // 🎨 POSTERIZATION PRESETS:
    //
    // EXTREME (8-27 colors): Great for very clean handwriting
    //   posterizationLevel: 2-3, contrastLevel: 2.5, gammaLevel: 0.3
    //
    // STRONG (64 colors): ✅ DEFAULT - Good balance for most handwriting
    //   posterizationLevel: 4, contrastLevel: 2.0, gammaLevel: 0.4
    //
    // MODERATE (216 colors): For colorful journals with highlighters
    //   posterizationLevel: 6, contrastLevel: 1.8, gammaLevel: 0.5
    //
    // SUBTLE (512 colors): Closer to original, less processed
    //   posterizationLevel: 8, contrastLevel: 1.5, gammaLevel: 0.6
    //
    private let posterizationLevelValue: Int = 4   // 2-8, lower = fewer colors (4 = 64 colors, 3 = 27 colors)
    private let contrastLevel: Double = 2.0   // 1.5-2.5, higher = more extreme
    private let gammaLevel: Double = 0.4      // 0.3-0.6, lower = more binary
    
    // MARK: - Personal Handwriting Corrections
    // This dictionary maps common OCR errors in YOUR handwriting to correct words
    // Build this over time by observing what Vision consistently misreads
    //
    // PRO TIP: After you've added several corrections, you can export them to
    // UserDefaults or a file to persist between app launches or share with other devices
    private let handwritingCorrectionsDict: [String: String] = [
        // === YOUR PERSONAL CORRECTION PATTERNS ===
        // Format: "what_vision_sees": "what_it_should_be"
        
        // Month names (common OCR errors)
        "jammer": "janvier",
        "jamuer": "janvier",
        "jamer": "janvier",
        "fevrier": "février",
        "aout": "août",
        
        // Verbs
        "bevé": "levé",
        "beve": "levé",
        "couhe": "couché",
        "reveile": "réveillé",
        
        // Adjectives/Emotions
        "Ellente": "Excellente",
        "Ballente": "Excellente",
        "Pebit": "Petit",
        "Peit": "Petit",
        
        // Common words
        "mataial": "matériel",
        "matcial": "matériel",
        "mui": "nuit",
        "nui": "nuit",
        "Spori": "Sport",
        "dej": "déjeuner",
        
        // Prepositions/Articles (context-dependent, but common patterns)
        "c": "à",  // When you write "à" quickly
        "an": "au", // Common confusion
        "el": "et", // Common confusion
        
        // === ADD YOUR OWN PATTERNS HERE ===
        // After each scan, check the "Texte OCR brut" section
        // If you see recurring errors, add them here
        // Example:
        // "parl": "parlé",
        // "travai": "travail",
    ]
    
    enum ModelAvailability {
        case unknown
        case available
        case unavailable(String)
    }
    
    init() {
        checkModelAvailability()
    }
    
    func checkModelAvailability() {
        switch model.availability {
        case .available:
            modelAvailability = .available
        case .unavailable(.deviceNotEligible):
            modelAvailability = .unavailable("Device not eligible for Apple Intelligence")
        case .unavailable(.appleIntelligenceNotEnabled):
            modelAvailability = .unavailable("Please enable Apple Intelligence in System Settings")
        case .unavailable(.modelNotReady):
            modelAvailability = .unavailable("Model is downloading or not ready")
        case .unavailable(let other):
            modelAvailability = .unavailable("Model unavailable: \(other)")
        }
    }
    
    func analyzeImage(_ image: NSImage) async {
        print("🔍 Starting LLM-based image analysis...")
        isAnalyzing = true
        errorMessage = nil
        recognizedTexts = []
        structuredOutput = nil
        
        // First check model availability
        guard case .available = modelAvailability else {
            if case .unavailable(let reason) = modelAvailability {
                errorMessage = reason
            } else {
                errorMessage = "Language model is not available"
            }
            isAnalyzing = false
            return
        }
        
        print("✅ Preprocessing image for better OCR accuracy...")
        
        // Step 0: Preprocess the image for better OCR
        guard let preprocessedImage = preprocessImageForOCR(image) else {
            print("❌ Failed to preprocess image")
            errorMessage = "Failed to process image"
            isAnalyzing = false
            return
        }
        
        // Store preprocessed image for UI display
        self.preprocessedImage = preprocessedImage
        
        // Use Vision for initial text detection, then LLM for analysis
        guard let cgImage = preprocessedImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("❌ Failed to convert NSImage to CGImage")
            errorMessage = "Failed to process image"
            isAnalyzing = false
            return
        }
        
        // Step 1: Extract text using Vision with MAXIMUM accuracy settings
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["fr-FR"] // Try both languages
        request.automaticallyDetectsLanguage = false // Let Vision auto-detect
        request.minimumTextHeight = 0.0 // Detect even small text
        
        // Use custom revision for better accuracy if available
        #if compiler(>=5.9)
        if #available(macOS 14.0, *) {
            request.revision = VNRecognizeTextRequestRevision3
        }
        #endif
        
        // IMPORTANT: Custom vocabulary for YOUR handwriting patterns
        // Add words you commonly write that Vision misrecognizes
        if #available(macOS 13.0, *) {
            request.customWords = [
                // === YOUR PERSONAL VOCABULARY ===
                // Add words you use frequently in your journal here
                // This tells Vision "expect to see these words"
                
                // Time/Date words
                "janvier", "février", "mars", "avril", "mai", "juin",
                "juillet", "août", "septembre", "octobre", "novembre", "décembre",
                "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche",
                
                // Emotions you track
                "excellente", "bonne", "mauvaise", "difficile", "reposé", "motivé",
                "anxiété", "stress", "calme", "joie", "tristesse", "colère",
                "fatigué", "énergique", "content", "frustré", "serein",
                
                // Daily activities
                "levé", "couché", "réveillé", "endormi",
                "sport", "travail", "repos", "méditation", "lecture",
                "déjeuner", "dîner", "petit-déjeuner", "collation",
                "promenade", "course", "yoga", "musculation",
                
                // CBT-related terms
                "pensée", "émotion", "comportement", "situation",
                "automatique", "distorsion", "cognitive", "recadrage",
                "objectif", "tâche", "accompli", "progrès",
                
                // Common verbs in your writing
                "commencé", "terminé", "ressenti", "pensé", "fait",
                "essayé", "réussi", "échoué", "continué",
                
                // === ADD YOUR OWN WORDS BELOW ===
                // Look at your journal and add words you write often
                // Example: "bricolage", "courses", "famille", etc.
            ]
            print("📚 Custom vocabulary loaded: \(request.customWords.count) words")
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [
            .ciContext: CIContext(options: [.useSoftwareRenderer: false])
        ])
        
        var extractedText = ""
        var textWithAlternatives = "" // For LLM with alternatives
        var textLocations: [(text: String, box: CGRect)] = []
        var totalConfidence: Float = 0
        var observationCount = 0
        
        do {
            print("🔄 Extracting text with Vision (high accuracy mode)...")
            try handler.perform([request])
            
            guard let observations = request.results, !observations.isEmpty else {
                print("⚠️ No text found in image")
                errorMessage = "Aucun texte trouvé dans l'image"
                isAnalyzing = false
                return
            }
            
            print("📝 Found \(observations.count) text observations")
            
            // Sort observations by vertical position (top to bottom), then horizontal (left to right)
            let sortedObservations = observations.sorted { obs1, obs2 in
                let box1 = obs1.boundingBox
                let box2 = obs2.boundingBox
                
                // Vision uses bottom-left origin, so higher y = higher up
                // We want to read top to bottom, so invert
                let y1 = 1.0 - box1.midY
                let y2 = 1.0 - box2.midY
                
                // If they're on roughly the same line (within 5% of height), sort by x
                if abs(y1 - y2) < 0.05 {
                    return box1.minX < box2.minX
                }
                return y1 < y2
            }
            
            for observation in sortedObservations {
                // Get MANY candidates for better accuracy (up to 10 alternatives)
                let candidates = observation.topCandidates(10)
                guard let topCandidate = candidates.first else { continue }
                
                let text = topCandidate.string
                let confidence = topCandidate.confidence
                let boundingBox = observation.boundingBox
                
                print("  📄 Text: \"\(text)\" (confidence: \(String(format: "%.2f", confidence)))")
                
                // Build text with alternatives for LLM
                extractedText += text + "\n"
                
                // Include MORE alternatives for low-confidence detections
                if candidates.count > 1 && confidence < 0.95 {
                    // Include up to 4 alternatives for very low confidence
                    let numAlternatives = confidence < 0.7 ? 4 : 2
                    let alternatives = candidates.dropFirst().prefix(numAlternatives).map { $0.string }
                    
                    textWithAlternatives += "[\(text)"
                    for alt in alternatives {
                        textWithAlternatives += " OR \(alt)"
                    }
                    textWithAlternatives += "] "
                    
                    print("     ⚠️ Low confidence - Alternatives: \(candidates.dropFirst().prefix(numAlternatives).map { "\($0.string) (\(String(format: "%.2f", $0.confidence)))" }.joined(separator: ", "))")
                } else {
                    textWithAlternatives += text + " "
                }
                
                textLocations.append((text: text, box: boundingBox))
                totalConfidence += confidence
                observationCount += 1
            }
            
            let avgConfidence = observationCount > 0 ? totalConfidence / Float(observationCount) : 0
            print("✅ Extracted text with average confidence: \(String(format: "%.2f", avgConfidence))")
            print("📝 Full extracted text:\n\(extractedText)")
            if !textWithAlternatives.isEmpty {
                print("📝 Text with alternatives for LLM:\n\(textWithAlternatives)")
            }
            
        } catch {
            print("❌ Error extracting text: \(error)")
            errorMessage = "Erreur lors de l'extraction du texte: \(error.localizedDescription)"
            isAnalyzing = false
            return
        }
        
        // Step 2: Analyze with LLM for CBT journal extraction
        do {
            print("🤖 Analyzing CBT journal with Apple Intelligence...")
            
            // Build correction guide from personal dictionary
            let correctionGuide = handwritingCorrectionsDict
                .map { "   • \"\($0.key)\" → \"\($0.value)\"" }
                .joined(separator: "\n")
            
            let instructions = """
            Tu es un assistant expert en thérapie cognitive et comportementale (TCC/CBT) ET en correction d'erreurs OCR de texte manuscrit français.
            Ta mission est d'analyser des entrées de journal manuscrit pour extraire des données cliniquement pertinentes.
            
            RÈGLES CRITIQUES :
            1. CORRECTION OCR INTELLIGENTE : Le texte contient des erreurs OCR de reconnaissance manuscrite. Corrige-les intelligemment :
            
               PATTERNS SPÉCIFIQUES À CETTE ÉCRITURE MANUSCRITE :
            \(correctionGuide)
            
               - Utilise le CONTEXTE pour deviner le bon mot
            
            2. ALTERNATIVES OCR : Quand tu vois [mot1 OR mot2 OR mot3 OR mot4], ce sont plusieurs candidats OCR.
               - Choisis celui qui a le PLUS DE SENS dans le contexte
               - Si aucun n'a de sens, infère le mot logique selon la phrase
               - Privilégie les mots français courants
            
            3. PRÉSERVE LE STYLE : Après correction OCR, préserve :
               - Les abréviations personnelles (si ce ne sont pas des erreurs OCR)
               - Le style d'écriture unique
               - La ponctuation (sauf si clairement incorrecte)
               - Les tournures de phrase
            
            4. ANALYSE CBT : Identifie tous les éléments :
               - Émotions (avec intensité si mentionnée)
               - Pensées automatiques (négatives et positives)
               - Comportements observables
               - Événements significatifs
               - Distorsions cognitives
               - Personnes mentionnées
            
            5. CONTEXTE TEMPOREL : Note la date de l'entrée avec précision
            
            PRIORITÉ : 1) Corriger OCR, 2) Préserver style personnel, 3) Extraire données CBT
            """
            
            let session = LanguageModelSession(instructions: instructions)
            
            // Use text with alternatives more aggressively
            let useAlternatives = !textWithAlternatives.isEmpty && (
                totalConfidence / Float(observationCount) < 0.8 || // Low overall confidence
                textWithAlternatives.contains("[") // Has alternatives
            )
            
            let textToAnalyze = useAlternatives ? textWithAlternatives : extractedText
            
            let prompt = """
            Analyse cette page de journal manuscrit pour la thérapie cognitive et comportementale (CBT).
            
            ⚠️ ATTENTION : Ce texte provient d'OCR sur écriture manuscrite et contient BEAUCOUP d'erreurs.
            Confiance OCR moyenne : \(String(format: "%.0f%%", (totalConfidence / Float(observationCount)) * 100))
            
            TEXTE OCR AVEC ALTERNATIVES :
            \(textToAnalyze)
            
            TEXTE OCR BRUT (référence) :
            \(extractedText)
            
            INSTRUCTIONS DE CORRECTION OCR :
            
            1. CORRECTIONS AUTOMATIQUES - Applique ces corrections SPÉCIFIQUES à cette écriture :
            \(correctionGuide)
            
            2. CHOIX D'ALTERNATIVES [mot1 OR mot2 OR mot3] :
               • Lis TOUTE la phrase pour comprendre le contexte
               • Choisis le mot qui fait le plus de SENS grammaticalement
               • Privilégie les mots français courants et correctement orthographiés
               • Si aucun candidat n'est bon, INFÈRE le mot logique
            
            3. RECONSTRUCTION DE PHRASES :
               • Si une phrase est incohérente, tente de la reconstruire intelligemment
               • Utilise ton intelligence pour "deviner" le sens voulu
               • Garde trace de ton niveau de certitude
            
            4. DÉTECTION DES JOURS :
               • Cherche les marqueurs de date (jour de la semaine, date numérique)
               • UN SEUL marqueur de date = UN SEUL jour (ne crée PAS de jours fantômes)
               • Si tu vois "Mardi 6 janvier", c'est UN SEUL jour, pas deux
               • Crée une entrée séparée UNIQUEMENT si tu vois DEUX dates distinctes
            
            5. POUR CHAQUE JOUR identifié, fournis :
            
               a) DATE : La date corrigée (ex: "Mardi 6 janvier 2026")
               
               b) TRANSCRIPTION EXACTE : Le texte entièrement CORRIGÉ (OCR + orthographe)
                  IMPORTANT : C'est la version LISIBLE et CORRECTE, pas le texte brut OCR
               
               c) ÉMOTIONS : Liste toutes les émotions mentionnées ou implicites
                  Ex: ["Bien reposé", "Motivé", "Content"]
               
               d) TÂCHES ACCOMPLIES : Actions complétées
                  Ex: ["Sport au midi", "Achat de matériel de bricolage"]
               
               e) TÂCHES MANQUÉES : Seulement si explicitement mentionné
               
               f) ÉVÉNEMENTS SIGNIFICATIFS : Faits notables de la journée
               
               g) PERSONNES : Noms ou relations mentionnées
               
               h) PENSÉES NÉGATIVES : Distorsions cognitives, ruminations
               
               i) PENSÉES POSITIVES : Recadrages, pensées constructives
               
               j) COMPORTEMENTS : Actions observables
               
               k) SYNTHÈSE CLINIQUE : Analyse CBT brève (2-3 phrases max)
                  Inclus : humeur générale, patterns comportementaux, observations thérapeutiques
            
            6. NOMBRE DE JOURS : Compte PRÉCISÉMENT
               • 1 date visible → numberOfDays = 1
               • 2 dates visibles → numberOfDays = 2
               • Sois CONSERVATEUR, ne crée pas de jours imaginaires
            
            7. NOTES DE PAGE : Observations générales sur la page
            
            RÈGLES ABSOLUES :
            ✅ Corrige TOUTES les erreurs OCR
            ✅ Rends le texte LISIBLE et CORRECT
            ✅ Préserve le SENS original
            ✅ Ne crée PAS de contenu inventé
            ✅ Sois CONSERVATEUR sur le nombre de jours
            ❌ Ne laisse PAS d'erreurs OCR dans la transcription finale
            """
            
            let response = try await session.respond(to: prompt, generating: StructuredOutput.self)
            var analysisResult = response.content
            
            print("✅ CBT Analysis complete")
            print("📅 Number of days found: \(analysisResult.numberOfDays)")
            print("📄 Number of entries: \(analysisResult.entries.count)")
            
            for (index, entry) in analysisResult.entries.enumerated() {
                print("\n--- Entry \(index + 1) ---")
                print("📅 Date: \(entry.date)")
                print("📝 Transcription length: \(entry.exactTranscription.count) chars")
                print("😊 Emotions: \(entry.emotions)")
                print("✅ Tasks completed: \(entry.tasksCompleted)")
                print("❌ Tasks missed: \(entry.tasksMissed)")
                print("👥 People: \(entry.peopleMentioned)")
            }
            
            if let notes = analysisResult.pageNotes {
                print("\n📋 Page notes: \(notes)")
            }
            
            // Parse the results and add computed properties
            let lines = extractedText.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            var allWords: [String] = []
            
            for line in lines {
                allWords.append(contentsOf: line.components(separatedBy: .whitespaces).filter { !$0.isEmpty })
            }
            
            // Add computed properties to the structured output
            analysisResult.lines = lines
            analysisResult.words = allWords
            analysisResult.characters = extractedText.count
            analysisResult.rawOCRText = extractedText
            analysisResult.ocrConfidence = totalConfidence / Float(observationCount)
            
            // Store recognized texts with locations
            for (text, box) in textLocations {
                recognizedTexts.append(RecognizedText(
                    text: text,
                    boundingBox: box
                ))
            }
            
            structuredOutput = analysisResult
            
            print("✅ Full analysis complete! Lines: \(lines.count), Words: \(allWords.count)")
            
        } catch {
            print("❌ Error analyzing with LLM: \(error)")
            errorMessage = "Erreur lors de l'analyse CBT: \(error.localizedDescription)"
        }
        
        isAnalyzing = false
    }
    
    /// Public convenience to preprocess an image and update `preprocessedImage` for UI
    func preprocessImage(_ image: NSImage) async {
        // Run preprocessing on a background Task if needed; the heavy work is done by Core Image
        if let output = preprocessImageForOCR(image) {
            self.preprocessedImage = output
        } else {
            self.preprocessedImage = nil
        }
    }
    
    // MARK: - Document Detection
    
    /// Detects a document in the image using Vision ML and crops to content boundaries
    private func detectAndCropDocument(_ image: CIImage) -> CIImage? {
        // Convert CIImage to CGImage for Vision request
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            print("❌ Failed to convert CIImage to CGImage for document detection")
            return nil
        }
        
        // Create a high-contrast grayscale version to help rectangle detection
        let rectDetectInput: CGImage = {
            if let gray = CIFilter(name: "CIColorControls") {
                gray.setValue(image, forKey: kCIInputImageKey)
                gray.setValue(0.0, forKey: kCIInputSaturationKey)
                gray.setValue(1.2, forKey: kCIInputContrastKey)
                gray.setValue(0.0, forKey: kCIInputBrightnessKey)
                let out = gray.outputImage ?? image
                return context.createCGImage(out, from: out.extent) ?? cgImage
            }
            return cgImage
        }()
        
        // Create Vision request for document segmentation
        let request = VNDetectDocumentSegmentationRequest()
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            
            guard let segmentationResult = request.results?.first as? VNPixelBufferObservation else {
                print("📄 No document detected by Vision ML")
                return nil
            }
            
            print("📄 Document detected by Vision ML with confidence: \(String(format: "%.2f", segmentationResult.confidence))")
            
            // Try to get the document rectangle for perspective correction first
            let rectangleRequest = VNDetectRectanglesRequest()
            rectangleRequest.minimumAspectRatio = 0.2
            rectangleRequest.maximumAspectRatio = 1.0
            rectangleRequest.minimumSize = 0.2
            rectangleRequest.quadratureTolerance = 20.0
            rectangleRequest.minimumConfidence = 0.3
            rectangleRequest.maximumObservations = 10
            
            let rectHandler = VNImageRequestHandler(cgImage: rectDetectInput, options: [:])
            try rectHandler.perform([rectangleRequest])
            
            if let rectangles = rectangleRequest.results, !rectangles.isEmpty {
                // Score rectangles by area coverage and vertical position (prefer larger, higher ones)
                let scored = rectangles.map { rect -> (VNRectangleObservation, CGFloat) in
                    let box = rect.boundingBox
                    let area = box.width * box.height
                    // Prefer rectangles that cover a large area and are closer to the top (page region)
                    let score = area - (1.0 - box.maxY) * 0.05
                    return (rect, score)
                }.sorted { $0.1 > $1.1 }

                if let best = scored.first?.0, let corrected = applyPerspectiveCorrection(to: image, with: best) {
                    print("📄 Rectangle detected - strict crop applied")
                    return corrected
                }
            }
            
            // Strict contour-based fallback: detect a strong horizontal edge (page bottom)
            if #available(macOS 12.0, *) {
                let contoursRequest = VNDetectContoursRequest()
                contoursRequest.contrastAdjustment = 1.0
                contoursRequest.detectsDarkOnLight = true
                contoursRequest.maximumImageDimension = 1024
                let edgeHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try edgeHandler.perform([contoursRequest])
                    if let observation = contoursRequest.results?.first as? VNContoursObservation {
                        var bottomY: CGFloat = 0
                        // Search for a long, mostly horizontal contour near the lower half
                        for idx in 0..<observation.contourCount {
                            if let contour = try? observation.contour(at: idx) {
                                let points = contour.normalizedPoints
                                guard points.count > 2 else { continue }
                                // Compute bounding box of the contour
                                var minX: CGFloat = 1, maxX: CGFloat = 0, minY: CGFloat = 1, maxY: CGFloat = 0
                                for p in points {
                                    minX = min(minX, CGFloat(p.x))
                                    maxX = max(maxX, CGFloat(p.x))
                                    minY = min(minY, CGFloat(p.y))
                                    maxY = max(maxY, CGFloat(p.y))
                                }
                                let width = maxX - minX
                                let height = maxY - minY
                                // Heuristics: very wide, very short, and low in the image
                                if width > 0.6 && height < 0.06 && minY < 0.8 {
                                    // Map to image coordinates (Vision normalized origin bottom-left)
                                    let yInImage = minY * image.extent.height
                                    bottomY = max(bottomY, yInImage)
                                }
                            }
                        }
                        if bottomY > 0 {
                            let strictRect = CGRect(x: image.extent.origin.x, y: bottomY, width: image.extent.width, height: image.extent.height - bottomY)
                            print("📏 Strict contour crop applied at y=\(Int(bottomY))")
                            return image.cropped(to: strictRect)
                        }
                    }
                } catch {
                    // Ignore and fall back
                }
            }
            
            // Otherwise, crop strictly to the content boundaries using the segmentation result
            print("📄 No clear rectangle - cropping to content boundaries")
            return cropToContentBoundaries(image: image, segmentationResult: segmentationResult)
            
        } catch {
            print("❌ Error detecting document: \(error.localizedDescription)")
            return nil
        }
        
        return nil
    }
    
    /// Applies perspective correction using detected rectangle corners
    private func applyPerspectiveCorrection(to image: CIImage, with observation: VNRectangleObservation) -> CIImage? {
        let imageSize = image.extent.size
        
        let topLeft = CGPoint(
            x: observation.topLeft.x * imageSize.width,
            y: observation.topLeft.y * imageSize.height
        )
        let topRight = CGPoint(
            x: observation.topRight.x * imageSize.width,
            y: observation.topRight.y * imageSize.height
        )
        let bottomLeft = CGPoint(
            x: observation.bottomLeft.x * imageSize.width,
            y: observation.bottomLeft.y * imageSize.height
        )
        let bottomRight = CGPoint(
            x: observation.bottomRight.x * imageSize.width,
            y: observation.bottomRight.y * imageSize.height
        )
        
        print("   Top-left: (\(topLeft.x), \(topLeft.y))")
        print("   Top-right: (\(topRight.x), \(topRight.y))")
        print("   Bottom-left: (\(bottomLeft.x), \(bottomLeft.y))")
        print("   Bottom-right: (\(bottomRight.x), \(bottomRight.y))")
        
        if let perspectiveFilter = CIFilter(name: "CIPerspectiveCorrection") {
            perspectiveFilter.setValue(image, forKey: kCIInputImageKey)
            perspectiveFilter.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
            perspectiveFilter.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
            perspectiveFilter.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
            perspectiveFilter.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")
            
            if let correctedImage = perspectiveFilter.outputImage {
                print("✅ Applied perspective correction (deskewed)")
                return correctedImage
            }
        }
        
        return nil
    }
    
    /// Crops image to content boundaries (top, bottom, left, right edges)
    private func cropToContentBoundaries(image: CIImage, segmentationResult: VNPixelBufferObservation) -> CIImage? {
        let pixelBuffer = segmentationResult.pixelBuffer
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            print("❌ Failed to get pixel buffer base address")
            return nil
        }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)

        // Binary mask: treat > 0 as foreground
        var visited = [Bool](repeating: false, count: width * height)
        var bestMinX = width, bestMaxX = 0, bestMinY = height, bestMaxY = 0
        var bestCount = 0

        // 4-neighborhood flood fill to find largest connected component
        let directions = [(0,1),(1,0),(0,-1),(-1,0)]
        func idx(_ x:Int,_ y:Int) -> Int { y * width + x }

        for y in 0..<height {
            for x in 0..<width {
                let i = idx(x,y)
                if visited[i] { continue }
                let isOn = buffer[y * bytesPerRow + x] > 0
                if !isOn { visited[i] = true; continue }

                // BFS
                var queue: [(Int,Int)] = [(x,y)]
                visited[i] = true
                var count = 0
                var minX = x, maxX = x, minY = y, maxY = y
                while !queue.isEmpty {
                    let (cx, cy) = queue.removeFirst()
                    count += 1
                    minX = min(minX, cx); maxX = max(maxX, cx)
                    minY = min(minY, cy); maxY = max(maxY, cy)
                    for (dx,dy) in directions {
                        let nx = cx + dx, ny = cy + dy
                        if nx < 0 || ny < 0 || nx >= width || ny >= height { continue }
                        let ni = idx(nx, ny)
                        if visited[ni] { continue }
                        if buffer[ny * bytesPerRow + nx] > 0 {
                            visited[ni] = true
                            queue.append((nx, ny))
                        } else {
                            visited[ni] = true
                        }
                    }
                }
                if count > bestCount {
                    bestCount = count
                    bestMinX = minX; bestMaxX = maxX
                    bestMinY = minY; bestMaxY = maxY
                }
            }
        }

        if bestCount == 0 { return nil }

        // Convert mask coordinates to image coordinates (strict, no padding)
        let imageSize = image.extent.size
        let scaleX = imageSize.width / CGFloat(width)
        let scaleY = imageSize.height / CGFloat(height)
        let cropRect = CGRect(
            x: CGFloat(bestMinX) * scaleX,
            y: CGFloat(bestMinY) * scaleY,
            width: CGFloat(bestMaxX - bestMinX + 1) * scaleX,
            height: CGFloat(bestMaxY - bestMinY + 1) * scaleY
        )

        print("📄 Strict segmentation crop (largest component): (\(Int(cropRect.origin.x)), \(Int(cropRect.origin.y))) - \(Int(cropRect.width)) x \(Int(cropRect.height))")
        return image.cropped(to: cropRect)
    }

    /// Detects a solid dark band at the bottom and crops it off
    private func cropBottomBlackBand(from image: CIImage, maxScanHeightRatio: CGFloat = 0.3, luminanceThreshold: CGFloat = 0.12, minBandHeightRatio: CGFloat = 0.03) -> CIImage {
        // Render a downscaled grayscale bitmap for fast scanning
        let extent = image.extent
        let width = Int(extent.width)
        let height = Int(extent.height)
        let maxScanHeight = Int(CGFloat(height) * maxScanHeightRatio)
        let minBandHeight = Int(CGFloat(height) * minBandHeightRatio)

        // Create context and grayscale image
        let context = CIContext(options: [.useSoftwareRenderer: false])
        let colorControls = CIFilter(name: "CIColorControls")!
        colorControls.setValue(image, forKey: kCIInputImageKey)
        colorControls.setValue(0.0, forKey: kCIInputSaturationKey)
        colorControls.setValue(1.0, forKey: kCIInputContrastKey)
        colorControls.setValue(0.0, forKey: kCIInputBrightnessKey)
        let grayImage = colorControls.outputImage ?? image

        // Downscale to manageable size to speed up scanning
        let targetWidth = 512
        let scale = CGFloat(targetWidth) / extent.width
        let targetHeight = max(1, Int(extent.height * scale))
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaled = grayImage.transformed(by: transform)

        guard let cg = context.createCGImage(scaled, from: CGRect(x: 0, y: 0, width: CGFloat(targetWidth), height: CGFloat(targetHeight))) else {
            return image
        }

        // Read pixel data (assume 8-bit RGBA)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = targetWidth * bytesPerPixel
        var data = [UInt8](repeating: 0, count: bytesPerRow * targetHeight)
        guard let bitmapCtx = CGContext(data: &data, width: targetWidth, height: targetHeight, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return image
        }
        bitmapCtx.draw(cg, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        // Scan from bottom up to find contiguous dark rows
        var darkRows = 0
        var bandHeightRows = 0
        let scanLimit = min(maxScanHeight, targetHeight)

        rowLoop: for row in 0..<scanLimit {
            let y = targetHeight - 1 - row
            var avgLuma: CGFloat = 0
            for x in 0..<targetWidth {
                let idx = y * bytesPerRow + x * bytesPerPixel
                let r = CGFloat(data[idx]) / 255.0
                let g = CGFloat(data[idx + 1]) / 255.0
                let b = CGFloat(data[idx + 2]) / 255.0
                // Rec. 709 luma
                avgLuma += 0.2126 * r + 0.7152 * g + 0.0722 * b
            }
            avgLuma /= CGFloat(targetWidth)
            if avgLuma < luminanceThreshold {
                darkRows += 1
            } else {
                // If we already started seeing dark rows and now a light row, stop
                if darkRows > 0 { break rowLoop }
            }
        }

        bandHeightRows = darkRows
        if bandHeightRows <= 0 { return image }

        // Require a minimum band height to avoid cropping legitimate content
        if bandHeightRows < Int(CGFloat(targetHeight) * minBandHeightRatio) { return image }

        // Map band height back to original image space
        let bandHeightInOriginal = Int((CGFloat(bandHeightRows) / CGFloat(targetHeight)) * extent.height)
        let cropRect = CGRect(x: extent.origin.x, y: extent.origin.y + CGFloat(bandHeightInOriginal), width: extent.width, height: extent.height - CGFloat(bandHeightInOriginal))
        print("🪓 Cropping bottom dark band: \(bandHeightInOriginal) px (~\(bandHeightRows) rows at \(targetHeight)px))")
        return image.cropped(to: cropRect)
    }
    
    // MARK: - Image Preprocessing
    
    /// Preprocesses the image to improve OCR accuracy with aggressive enhancements
    ///
    /// Strategy: Page detection + Posterized color + extreme contrast = "retro 16-bit" look
    /// - Detects and crops the document rectangle
    /// - Corrects perspective (deskew)
    /// - Keeps color information (may help OCR distinguish ink colors)
    /// - Uses limited palette (4-64 colors) for high contrast
    /// - Almost binary per channel, but maintains RGB
    ///
    /// Tuning guide:
    /// - inputLevels (Step 3): Lower = fewer colors (3 = 27 colors, 4 = 64, 6 = 216)
    /// - Contrast (Step 4): Higher = more extreme (1.5-2.5 range)
    /// - Gamma (Step 10): Lower = more binary (0.3-0.6 range)
    private func preprocessImageForOCR(_ image: NSImage) -> NSImage? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let cgImage = bitmap.cgImage else {
            return nil
        }
        
        var ciImage = CIImage(cgImage: cgImage)
        var processedImage = ciImage
        
        print("📐 Original image size: \(ciImage.extent.width) x \(ciImage.extent.height)")
        
        // Step 0: Detect and crop the document rectangle
        if let detectedPage = detectAndCropDocument(ciImage) {
            processedImage = detectedPage
            ciImage = detectedPage // Update base image
            print("📄 Document detected and cropped to: \(detectedPage.extent.width) x \(detectedPage.extent.height)")
        } else {
            print("⚠️ No document rectangle detected, using full image")
            
            // Attempt to crop a potential bottom black band
            let croppedForBand = cropBottomBlackBand(from: processedImage)
            if !croppedForBand.extent.equalTo(processedImage.extent) {
                processedImage = croppedForBand
                ciImage = croppedForBand
                print("✂️ Removed bottom black band. New size: \(processedImage.extent.width) x \(processedImage.extent.height)")
            }
        }
        
        // Step 1: Upscale if image is small (improves OCR on low-res photos)
        let minDimension = min(ciImage.extent.width, ciImage.extent.height)
        if minDimension < 1500 {
            let scale = 1500 / minDimension
            print("🔍 Upscaling image by \(String(format: "%.2f", scale))x for better OCR")
            processedImage = processedImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }
        
        // Step 2: POSTERIZE to limited color palette (like 16-bit retro colors)
        // This creates high contrast while preserving color information
        if let posterizeFilter = CIFilter(name: "CIColorPosterize") {
            posterizeFilter.setValue(processedImage, forKey: kCIInputImageKey)
            // Use configurable posterization level
            posterizeFilter.setValue(posterizationLevelValue, forKey: "inputLevels")
            if let output = posterizeFilter.outputImage {
                processedImage = output
                let totalColors = Int(pow(Double(posterizationLevelValue), 3))
                print("🎨 Posterized to ~\(totalColors) colors (\(posterizationLevelValue) levels per channel)")
            }
        }
        
        // Step 3: SUPER aggressive contrast enhancement (keeps color!)
        if let contrastFilter = CIFilter(name: "CIColorControls") {
            contrastFilter.setValue(processedImage, forKey: kCIInputImageKey)
            contrastFilter.setValue(contrastLevel, forKey: kCIInputContrastKey) // Use configurable contrast
            contrastFilter.setValue(0.2, forKey: kCIInputBrightnessKey) // Brighten to see text
            contrastFilter.setValue(1.5, forKey: kCIInputSaturationKey) // BOOST saturation for vibrant colors
            if let output = contrastFilter.outputImage {
                processedImage = output
                print("🎨 Applied super aggressive contrast (level: \(contrastLevel)) with color boost")
            }
        }
        
        // Step 4: Adaptive histogram equalization (improves local contrast)
        if let exposureFilter = CIFilter(name: "CIExposureAdjust") {
            exposureFilter.setValue(processedImage, forKey: kCIInputImageKey)
            exposureFilter.setValue(0.3, forKey: kCIInputEVKey)
            if let output = exposureFilter.outputImage {
                processedImage = output
            }
        }
        
        // Step 5: Strong sharpening for text edges
        if let sharpenFilter = CIFilter(name: "CISharpenLuminance") {
            sharpenFilter.setValue(processedImage, forKey: kCIInputImageKey)
            sharpenFilter.setValue(1.2, forKey: kCIInputSharpnessKey) // More aggressive
            if let output = sharpenFilter.outputImage {
                processedImage = output
                print("✨ Applied strong sharpening")
            }
        }
        
        // Step 6: Unsharp mask for even better edge definition
        if let unsharpFilter = CIFilter(name: "CIUnsharpMask") {
            unsharpFilter.setValue(processedImage, forKey: kCIInputImageKey)
            unsharpFilter.setValue(2.5, forKey: kCIInputRadiusKey)
            unsharpFilter.setValue(0.5, forKey: kCIInputIntensityKey)
            if let output = unsharpFilter.outputImage {
                processedImage = output
                print("🔪 Applied unsharp mask")
            }
        }
        
        // Step 7: Reduce noise while preserving edges
        if let noiseReductionFilter = CIFilter(name: "CINoiseReduction") {
            noiseReductionFilter.setValue(processedImage, forKey: kCIInputImageKey)
            noiseReductionFilter.setValue(0.01, forKey: "inputNoiseLevel")
            noiseReductionFilter.setValue(0.6, forKey: "inputSharpness")
            if let output = noiseReductionFilter.outputImage {
                processedImage = output
                print("🧹 Reduced noise")
            }
        }
        
        // Step 8: Tone curve adjustment (make text MUCH darker, background MUCH lighter)
        // This creates almost binary effect while keeping color
        if let toneCurveFilter = CIFilter(name: "CIToneCurve") {
            toneCurveFilter.setValue(processedImage, forKey: kCIInputImageKey)
            // Extreme S-curve for almost binary result
            toneCurveFilter.setValue(CIVector(x: 0.0, y: 0.0), forKey: "inputPoint0")
            toneCurveFilter.setValue(CIVector(x: 0.25, y: 0.05), forKey: "inputPoint1") // VERY dark shadows
            toneCurveFilter.setValue(CIVector(x: 0.5, y: 0.5), forKey: "inputPoint2")
            toneCurveFilter.setValue(CIVector(x: 0.75, y: 0.95), forKey: "inputPoint3") // VERY bright highlights
            toneCurveFilter.setValue(CIVector(x: 1.0, y: 1.0), forKey: "inputPoint4")
            if let output = toneCurveFilter.outputImage {
                processedImage = output
                print("📈 Applied extreme tone curve for near-binary effect")
            }
        }
        
        // Step 9: Optional - Even MORE aggressive binarization
        // This pushes it to extreme black/white per color channel
        let canApplyBinarization = true // Set to false if it's too aggressive
        if canApplyBinarization {
            if let gammaFilter = CIFilter(name: "CIGammaAdjust") {
                gammaFilter.setValue(processedImage, forKey: kCIInputImageKey)
                gammaFilter.setValue(gammaLevel, forKey: "inputPower") // Use configurable gamma
                if let output = gammaFilter.outputImage {
                    processedImage = output
                    print("⚡️ Applied extreme gamma adjustment (level: \(gammaLevel)) for binary-like appearance")
                }
            }
        }
        
        // Convert back to NSImage with RGB color space (NOT grayscale!)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        let extent = processedImage.extent
        
        guard let outputCGImage = context.createCGImage(processedImage, from: extent) else {
            print("⚠️ Failed to create processed image, using original")
            return image
        }
        
        let outputImage = NSImage(cgImage: outputCGImage, size: NSSize(width: extent.width, height: extent.height))
        print("✅ Image preprocessing complete: \(extent.width) x \(extent.height)")
        
        return outputImage
    }
}

