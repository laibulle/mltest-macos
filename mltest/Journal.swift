//
//  Journal.swift
//  mltest
//
//  Created by Guillaume BAILLEUL on 13/01/2026.
//

import FoundationModels
import Foundation

// Structure principale contenant toutes les entrées d'une page scannée
@Generable(description: "Analyse complète d'une page de journal CBT pouvant contenir plusieurs jours")
struct StructuredOutput: Identifiable {
    let id = UUID()
    
    @Guide(description: "Liste de toutes les entrées de journal trouvées sur la page, une par jour", .count(1...7))
    var entries: [JournalEntry]
    
    @Guide(description: "Nombre total de jours différents identifiés sur cette page")
    var numberOfDays: Int
    
    @Guide(description: "Notes globales ou observations générales sur la page entière si pertinent")
    var pageNotes: String?
    
    // Non-generable properties for display
    var lines: [String] = []
    var words: [String] = []
    var characters: Int = 0
    var rawOCRText: String = ""
    var ocrConfidence: Float = 0
}

struct RecognizedText: Identifiable {
    let id = UUID()
    let text: String
    let boundingBox: CGRect?
}


// Une entrée de journal individuelle pour un jour
@Generable(description: "Une entrée de journal CBT pour un jour spécifique")
struct JournalEntry: Identifiable {
    let id = UUID()
    
    @Guide(description: "La date de cette entrée (format: jj/mm/aaaa ou texte comme 'Lundi 13 janvier')")
    var date: String
    
    @Guide(description: "La transcription exacte et fidèle du texte pour cette journée, sans correction ni interprétation")
    var exactTranscription: String
    
    @Guide(description: "Liste des émotions identifiées avec leur intensité si mentionnée")
    var emotions: [String]
    
    @Guide(description: "Liste des tâches ou objectifs accomplis")
    var tasksCompleted: [String]
    
    @Guide(description: "Liste des tâches manquées, reportées ou non accomplies")
    var tasksMissed: [String]
    
    @Guide(description: "Liste des événements significatifs décrits")
    var significantEvents: [String]
    
    @Guide(description: "Liste des personnes mentionnées")
    var peopleMentioned: [String]
    
    @Guide(description: "Pensées négatives ou distorsions cognitives")
    var negativeThoughts: [String]
    
    @Guide(description: "Pensées positives ou recadrages cognitifs")
    var positiveThoughts: [String]
    
    @Guide(description: "Comportements ou actions décrits")
    var behaviors: [String]
    
    @Guide(description: "Brève synthèse clinique pour cette journée (1-2 phrases)")
    var clinicalSummary: String
}
