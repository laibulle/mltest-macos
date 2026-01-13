//
//  ContentView.swift
//  mltest
//
//  Created by Guillaume BAILLEUL on 13/01/2026.
//

// MARK: - 📝 GUIDE: Training the App to Recognize YOUR Handwriting
//
// This app learns your handwriting patterns over time! Here's how to improve accuracy:
//
// 1. OBSERVE PATTERNS:
//    After each scan, expand "Détails techniques" → check "Texte OCR brut"
//    Note recurring errors (e.g., Vision always reads your "é" as "e")
//
// 2. ADD TO CUSTOM VOCABULARY:
//    In TextRecognitionViewModel, find request.customWords array
//    Add words you write often (especially proper nouns, activities, emotions)
//
// 3. ADD CORRECTION PATTERNS:
//    In personalHandwritingCorrections dictionary
//    Add entries like: "what_vision_sees": "what_it_should_be"
//
// 4. TEST AND REFINE:
//    Scan the same page again after adding corrections
//    The LLM will now know these are YOUR specific handwriting patterns
//
// 5. IMPROVE YOUR WRITING (optional but helpful):
//    - Write dates clearly at the top of each entry
//    - Use consistent abbreviations (Vision learns them)
//    - Avoid overlapping text
//    - Write on lined paper or use a template
//    - Take photos in good lighting, straight-on angle
//
// The more you use this app and add corrections, the better it gets at
// reading YOUR specific handwriting style!

import SwiftUI
import AppKit
import PhotosUI
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import FoundationModels




struct ContentView: View {
    @State private var viewModel = TextRecognitionViewModel()
    @State private var selectedItem: PhotosPickerItem?
    @State private var showImageComparison = true // Toggle for showing preprocessed image
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    modelAvailabilityView
                    imageSelectionSection
                    analysisStatusView
                    errorMessageView
                    analysisResultsView
                }
            }
            .navigationTitle("Journal CBT")
        }
        .onChange(of: selectedItem) { oldValue, newValue in
            Task {
                if let newItem = newValue,
                   let data = try? await newItem.loadTransferable(type: Data.self),
                   let nsImage = NSImage(data: data) {
                    viewModel.selectedImage = nsImage
                    // Preprocess immediately after loading
                    await viewModel.preprocessImage(nsImage)
                }
            }
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var modelAvailabilityView: some View {
        if case .unavailable(let reason) = viewModel.modelAvailability {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Apple Intelligence Not Available")
                        .font(.headline)
                    Text(reason)
                        .font(.caption)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
        }
    }
    
    private var imageSelectionSection: some View {
        VStack(spacing: 12) {
            imagePreviewView
            imageSelectionButtons
            analyzeButton
        }
        .padding()
    }
    
    @ViewBuilder
    private var imagePreviewView: some View {
        if let image = viewModel.selectedImage {
            VStack(spacing: 12) {
                // Toggle for comparison view
                if viewModel.preprocessedImage != nil {
                    Toggle(isOn: $showImageComparison) {
                        HStack(spacing: 4) {
                            Image(systemName: "eye")
                                .font(.caption)
                            Text("Afficher la comparaison")
                                .font(.caption)
                        }
                    }
                    .toggleStyle(.switch)
                    .padding(.horizontal)
                }
                
                if showImageComparison && viewModel.preprocessedImage != nil {
                    // Side-by-side comparison
                    HStack(spacing: 12) {
                        // Original image
                        VStack(spacing: 4) {
                            Text("Original")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 250)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        // Preprocessed image
                        if let preprocessed = viewModel.preprocessedImage {
                            VStack(spacing: 4) {
                                HStack(spacing: 4) {
                                    Text("Prétraité")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Image(systemName: "wand.and.stars")
                                        .font(.caption2)
                                        .foregroundStyle(.purple)
                                }
                                Image(nsImage: preprocessed)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 250)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.purple.opacity(0.5), lineWidth: 2)
                                    )
                            }
                        }
                    }
                    
                    Text("🎨 Image postérisée avec \(viewModel.posterizationLevel) niveaux (≈\(Int(pow(Double(viewModel.posterizationLevel), 3))) couleurs)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    // Show only original when comparison is off
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "doc.text.image")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text("Sélectionnez une entrée de journal manuscrit")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private var imageSelectionButtons: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label("Choisir une photo", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            Button {
                selectImageFromFile()
            } label: {
                Label("Choisir un fichier", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            // Save preprocessed image button
            if viewModel.preprocessedImage != nil {
                Button {
                    savePreprocessedImage()
                } label: {
                    Label("Sauvegarder", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .help("Sauvegarder l'image prétraitée")
            }
        }
    }
    
    @ViewBuilder
    private var analyzeButton: some View {
        if viewModel.selectedImage != nil {
            Button {
                Task {
                    if let image = viewModel.selectedImage {
                        await viewModel.analyzeImage(image)
                    }
                }
            } label: {
                Label("Analyser l'entrée", systemImage: "text.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isAnalyzing)
        }
    }
    
    @ViewBuilder
    private var analysisStatusView: some View {
        if viewModel.isAnalyzing {
            HStack(spacing: 12) {
                ProgressView()
                Text("Analyse du journal en cours...")
                    .font(.subheadline)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var errorMessageView: some View {
        if let error = viewModel.errorMessage {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(error)
                    .font(.subheadline)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var analysisResultsView: some View {
        if let output = viewModel.structuredOutput {
            VStack(alignment: .leading, spacing: 20) {
                resultHeaderView(output: output)
                pageNotesView(output: output)
                Divider()
                journalEntriesView(output: output)
                Divider()
                technicalDetailsView(output: output)
            }
            .padding()
        }
    }
    
    private func resultHeaderView(output: StructuredOutput) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Analyse du journal CBT")
                    .font(.title2)
                    .bold()
                Text("\(output.numberOfDays) jour(s) identifié(s)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Confiance OCR")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.0f%%", output.ocrConfidence * 100))
                    .font(.headline)
                    .foregroundStyle(confidenceColor(output.ocrConfidence))
            }
        }
        .padding()
        .background(Color.blue.opacity(0.08))
        .cornerRadius(12)
    }
    
    private func confidenceColor(_ confidence: Float) -> Color {
        if confidence > 0.8 {
            return .green
        } else if confidence > 0.6 {
            return .orange
        } else {
            return .red
        }
    }
    
    @ViewBuilder
    private func pageNotesView(output: StructuredOutput) -> some View {
        if let pageNotes = output.pageNotes, !pageNotes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "note.text")
                        .foregroundStyle(.blue)
                    Text("Notes générales de la page")
                        .font(.headline)
                }
                Text(pageNotes)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding()
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
            }
        }
    }
    
    private func journalEntriesView(output: StructuredOutput) -> some View {
        ForEach(Array(output.entries.enumerated()), id: \.element.id) { index, entry in
            VStack(alignment: .leading, spacing: 16) {
                entryHeader(index: index, entry: entry)
                JournalEntryView(entry: entry)
            }
            .padding()
            .background(Color.gray.opacity(0.03))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            
            if index < output.entries.count - 1 {
                Divider()
                    .padding(.vertical, 8)
            }
        }
    }
    
    private func entryHeader(index: Int, entry: JournalEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Entrée \(index + 1)")
                    .font(.title3)
                    .bold()
                Text(entry.date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "calendar")
                .foregroundStyle(.blue)
                .font(.title2)
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(10)
    }
    
    private func technicalDetailsView(output: StructuredOutput) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                statisticsView(output: output)
                
                // Show active corrections
                activeCorrectionsPatternsView
                
                rawOCRTextView(output: output)
                lineByLineView
            }
        } label: {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                Text("Détails techniques")
                    .font(.headline)
            }
        }
    }
    
    @ViewBuilder
    private var activeCorrectionsPatternsView: some View {
        if !viewModel.personalHandwritingCorrections.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(.purple)
                    Text("Patterns d'écriture personnalisés actifs")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(viewModel.personalHandwritingCorrections.keys.sorted().prefix(10)), id: \.self) { key in
                        if let value = viewModel.personalHandwritingCorrections[key] {
                            HStack(spacing: 4) {
                                Text("•")
                                    .foregroundStyle(.purple)
                                Text("\"\(key)\"")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.purple)
                                Text("\"\(value)\"")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    if viewModel.personalHandwritingCorrections.count > 10 {
                        Text("... et \(viewModel.personalHandwritingCorrections.count - 10) autres")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                }
                .padding(.leading, 8)
                
                Text("💡 Ajoutez plus de corrections dans le code pour améliorer la précision")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .italic()
                    .padding(.top, 4)
            }
            .padding()
            .background(Color.purple.opacity(0.05))
            .cornerRadius(8)
        }
    }
    
    private func statisticsView(output: StructuredOutput) -> some View {
        VStack(spacing: 8) {
            StatRow(label: "Lignes détectées", value: "\(output.lines.count)")
            StatRow(label: "Mots", value: "\(output.words.count)")
            StatRow(label: "Caractères", value: "\(output.characters)")
            StatRow(label: "Jours analysés", value: "\(output.numberOfDays)")
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func rawOCRTextView(output: StructuredOutput) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Texte OCR brut")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(output.rawOCRText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
        }
    }
    
    private var lineByLineView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Détection ligne par ligne")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            ForEach(Array(viewModel.recognizedTexts.enumerated()), id: \.element.id) { index, item in
                Text("[\(index + 1)] \(item.text)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }
    
    // MARK: - Actions
    
    private func selectImageFromFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        
        if panel.runModal() == .OK, let url = panel.url {
            if let image = NSImage(contentsOf: url) {
                viewModel.selectedImage = image
                // Preprocess immediately after loading
                Task {
                    await viewModel.preprocessImage(image)
                }
            }
        }
    }
    
    private func savePreprocessedImage() {
        guard let image = viewModel.preprocessedImage else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "preprocessed_\(Date().timeIntervalSince1970).png"
        panel.title = "Sauvegarder l'image prétraitée"
        panel.message = "Choisissez où sauvegarder l'image postérisée"
        
        if panel.runModal() == .OK, let url = panel.url {
            if let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try? pngData.write(to: url)
                print("💾 Saved preprocessed image to: \(url.path)")
            }
        }
    }
}

// MARK: - Supporting Views

// View for displaying a single journal entry
struct JournalEntryView: View {
    let entry: JournalEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Exact Transcription (Most Important!)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "doc.plaintext.fill")
                        .foregroundStyle(.blue)
                    Text("Transcription exacte")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Text(entry.exactTranscription)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding()
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
            }
            
            // Clinical Summary
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "stethoscope")
                        .foregroundStyle(.purple)
                    Text("Synthèse clinique")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Text(entry.clinicalSummary)
                    .font(.callout)
                    .textSelection(.enabled)
                    .padding()
                    .background(Color.purple.opacity(0.08))
                    .cornerRadius(8)
            }
            
            // Emotions
            if !entry.emotions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.pink)
                            .font(.caption)
                        Text("Émotions")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    FlowLayout(spacing: 6) {
                        ForEach(entry.emotions, id: \.self) { emotion in
                            Text(emotion)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.pink.opacity(0.15))
                                .foregroundStyle(.pink)
                                .cornerRadius(12)
                        }
                    }
                }
            }
            
            // Tasks
            HStack(spacing: 16) {
                // Completed
                if !entry.tasksCompleted.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text("Accompli")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        ForEach(entry.tasksCompleted, id: \.self) { task in
                            Text("• \(task)")
                                .font(.caption)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Missed
                if !entry.tasksMissed.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            Text("Manqué")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        ForEach(entry.tasksMissed, id: \.self) { task in
                            Text("• \(task)")
                                .font(.caption)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            // Events
            if !entry.significantEvents.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                        Text("Événements")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    ForEach(entry.significantEvents, id: \.self) { event in
                        Text("• \(event)")
                            .font(.caption)
                    }
                }
            }
            
            // People
            if !entry.peopleMentioned.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundStyle(.blue)
                            .font(.caption)
                        Text("Personnes")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    FlowLayout(spacing: 6) {
                        ForEach(entry.peopleMentioned, id: \.self) { person in
                            Text(person)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .cornerRadius(12)
                        }
                    }
                }
            }
            
            // Thoughts
            if !entry.negativeThoughts.isEmpty || !entry.positiveThoughts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pensées")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    if !entry.negativeThoughts.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "cloud.rain.fill")
                                    .foregroundStyle(.gray)
                                    .font(.caption2)
                                Text("Négatives")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(entry.negativeThoughts, id: \.self) { thought in
                                Text("• \(thought)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    if !entry.positiveThoughts.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "sun.max.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.caption2)
                                Text("Positives")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(entry.positiveThoughts, id: \.self) { thought in
                                Text("• \(thought)")
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            
            // Behaviors
            if !entry.behaviors.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "figure.walk")
                            .foregroundStyle(.indigo)
                            .font(.caption)
                        Text("Comportements")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    ForEach(entry.behaviors, id: \.self) { behavior in
                        Text("• \(behavior)")
                            .font(.caption)
                    }
                }
            }
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .bold()
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

#Preview {
    ContentView()
}

