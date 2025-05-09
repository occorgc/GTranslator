import Foundation
import AppKit
import Vision
import UniformTypeIdentifiers

class TranslatorService: ObservableObject {
    private let geminiBaseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
    private let visionBaseURL = "https://vision.googleapis.com/v1/images:annotate"
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var extractedText: String = ""
    @Published var supportedLanguages: [String: String] = [:]
    
    private var languageDetectionTask: URLSessionDataTask?
    @Published var detectedLanguage: String = "Auto"
    
    init() {
        // Inizializza le lingue supportate
        initSupportedLanguages()
    }
    
    // Traduzione di testo normale
    func translate(text: String, from sourceLanguage: String, to targetLanguage: String, context: String? = nil, completion: @escaping (String?) -> Void) {
        isLoading = true
        errorMessage = nil
        
        // Se il testo è vuoto, non fare la richiesta
        if text.isEmpty {
            DispatchQueue.main.async {
                self.isLoading = false
                completion("")
            }
            return
        }
        
        // Se la lingua sorgente è "Auto", proviamo a rilevarla
        if sourceLanguage == "Auto" && text.count > 5 {
            detectLanguage(text: text) { detectedLang in
                let sourceLang = detectedLang ?? "Auto"
                self.performTranslation(text: text, from: sourceLang, to: targetLanguage, context: context, completion: completion)
            }
        } else {
            performTranslation(text: text, from: sourceLanguage, to: targetLanguage, context: context, completion: completion)
        }
    }
    
    private func performTranslation(text: String, from sourceLanguage: String, to targetLanguage: String, context: String? = nil, completion: @escaping (String?) -> Void) {
        // Crea il prompt per Gemini in base alla lingua sorgente e destinazione
        var prompt = "Traduci il seguente testo da \(sourceLanguage) a \(targetLanguage):\n\"\(text)\"\n"
        
        // Aggiungi il contesto se fornito
        if let context = context, !context.isEmpty {
            prompt += "\nContesto: \(context)\n"
        }
        
        prompt += "\nRispondi solo con il testo tradotto, senza altre spiegazioni o commenti."
        
        // Costruisci l'URL con la chiave API come parametro di query
        var urlComponents = URLComponents(string: geminiBaseURL)!
        urlComponents.queryItems = [URLQueryItem(name: "key", value: PreferencesManager.shared.apiKey)]
        
        guard let url = urlComponents.url else {
            print("Debug - URL non valido")
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "URL non valido"
                completion(nil)
            }
            return
        }
        
        // Prepara i parametri della richiesta per Gemini API
        let parameters: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": prompt
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.2,
                "topK": 32,
                "topP": 0.95,
                "maxOutputTokens": 1024
            ]
        ]
        
        // Configura la richiesta HTTP
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Serializza i parametri in JSON
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            print("Debug - Errore nella serializzazione: \(error)")
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Errore nella preparazione della richiesta"
                completion(nil)
            }
            return
        }
        
        // Crea e avvia il task
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            // Verifica eventuali errori di connessione
            if let error = error {
                print("Debug - Errore di connessione: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMessage = "Errore di connessione: \(error.localizedDescription)"
                    completion(nil)
                }
                return
            }
            
            // Verifica che ci siano dati nella risposta
            guard let data = data else {
                print("Debug - Nessun dato ricevuto")
                DispatchQueue.main.async {
                    self.errorMessage = "Nessun dato ricevuto dal server"
                    completion(nil)
                }
                return
            }
            
            // Prova a decodificare la risposta JSON di Gemini
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Verifica se c'è un messaggio di errore
                    if let errorInfo = json["error"] as? [String: Any],
                       let errorMessage = errorInfo["message"] as? String {
                        print("Debug - Errore API: \(errorMessage)")
                        
                        DispatchQueue.main.async {
                            self.errorMessage = "Errore API: \(errorMessage)"
                            completion(nil)
                        }
                        return
                    }
                    
                    // Tenta di estrarre il testo tradotto
                    if let candidates = json["candidates"] as? [[String: Any]],
                       let candidate = candidates.first,
                       let content = candidate["content"] as? [String: Any],
                       let parts = content["parts"] as? [[String: Any]],
                       let part = parts.first,
                       let translation = part["text"] as? String {
                        
                        // Rimuovi eventuali virgolette che Gemini potrebbe aver aggiunto
                        let cleanTranslation = translation.trimmingCharacters(in: .whitespacesAndNewlines)
                            .replacingOccurrences(of: "^\"", with: "", options: .regularExpression)
                            .replacingOccurrences(of: "\"$", with: "", options: .regularExpression)
                        
                        print("Debug - Traduzione estratta: \(cleanTranslation)")
                        
                        DispatchQueue.main.async {
                            completion(cleanTranslation)
                        }
                    } else {
                        print("Debug - Formato di risposta JSON inaspettato")
                        DispatchQueue.main.async {
                            self.errorMessage = "Formato di risposta non riconosciuto"
                            completion(nil)
                        }
                    }
                } else {
                    print("Debug - Impossibile convertire la risposta in JSON")
                    DispatchQueue.main.async {
                        self.errorMessage = "Errore nella risposta del servizio"
                        completion(nil)
                    }
                }
            } catch {
                print("Debug - Errore nella decodifica JSON: \(error)")
                DispatchQueue.main.async {
                    self.errorMessage = "Errore di elaborazione: \(error.localizedDescription)"
                    completion(nil)
                }
            }
        }
        
        task.resume()
    }
    
    // Estrazione del testo con Vision API (OCR)
    func extractTextFromImage(imageData: Data, completion: @escaping (String?) -> Void) {
        isLoading = true
        errorMessage = nil
        
        // Utilizza prima Vision framework locale se disponibile per dispositivi recenti
        if #available(macOS 13.0, *) {
            performLocalOCR(imageData: imageData, completion: completion)
            return
        }
        
        // Se la chiave OCR API non è configurata, non possiamo procedere
        if PreferencesManager.shared.ocrApiKey.isEmpty {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Chiave API OCR non configurata"
                completion(nil)
            }
            return
        }
        
        // Codifica l'immagine in base64
        let base64Image = imageData.base64EncodedString()
        
        // Costruisci l'URL con la chiave API come parametro di query
        var urlComponents = URLComponents(string: visionBaseURL)!
        urlComponents.queryItems = [URLQueryItem(name: "key", value: PreferencesManager.shared.ocrApiKey)]
        
        guard let url = urlComponents.url else {
            print("Debug - URL OCR non valido")
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "URL OCR non valido"
                completion(nil)
            }
            return
        }
        
        // Prepara i parametri della richiesta per Vision API
        let parameters: [String: Any] = [
            "requests": [
                [
                    "image": ["content": base64Image],
                    "features": [["type": "TEXT_DETECTION"]]
                ]
            ]
        ]
        
        // Configura la richiesta HTTP
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Serializza i parametri in JSON
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            print("Debug - Errore nella serializzazione OCR: \(error)")
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Errore nella preparazione della richiesta OCR"
                completion(nil)
            }
            return
        }
        
        // Crea e avvia il task
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            // Verifica eventuali errori di connessione
            if let error = error {
                print("Debug - Errore di connessione OCR: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMessage = "Errore di connessione OCR: \(error.localizedDescription)"
                    completion(nil)
                }
                return
            }
            
            // Verifica che ci siano dati nella risposta
            guard let data = data else {
                print("Debug - Nessun dato OCR ricevuto")
                DispatchQueue.main.async {
                    self.errorMessage = "Nessun dato ricevuto dal server OCR"
                    completion(nil)
                }
                return
            }
            
            // Prova a decodificare la risposta JSON di Vision API
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let responses = json["responses"] as? [[String: Any]],
                   let response = responses.first,
                   let textAnnotations = response["textAnnotations"] as? [[String: Any]],
                   let firstAnnotation = textAnnotations.first,
                   let extractedText = firstAnnotation["description"] as? String {
                    
                    print("Debug - Testo estratto: \(extractedText)")
                    
                    DispatchQueue.main.async {
                        self.extractedText = extractedText
                        completion(extractedText)
                    }
                } else {
                    print("Debug - Nessun testo trovato nell'immagine o formato risposta inaspettato")
                    DispatchQueue.main.async {
                        self.errorMessage = "Nessun testo trovato nell'immagine"
                        completion(nil)
                    }
                }
            } catch {
                print("Debug - Errore nella decodifica JSON OCR: \(error)")
                DispatchQueue.main.async {
                    self.errorMessage = "Errore di elaborazione OCR: \(error.localizedDescription)"
                    completion(nil)
                }
            }
        }
        
        task.resume()
    }
    
    // OCR con Gemini 1.5 Flash API
    func extractTextWithGeminiOCR(imageData: Data, completion: @escaping (String?) -> Void) {
        isLoading = true
        errorMessage = nil
        
        // Se la chiave API non è configurata, non possiamo procedere
        if PreferencesManager.shared.apiKey.isEmpty {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Chiave API Gemini non configurata"
                completion(nil)
            }
            return
        }
        
        // Codifica l'immagine in base64
        let base64Image = imageData.base64EncodedString()
        
        // Costruisci l'URL con la chiave API
        var urlComponents = URLComponents(string: geminiBaseURL)!
        urlComponents.queryItems = [URLQueryItem(name: "key", value: PreferencesManager.shared.apiKey)]
        
        guard let url = urlComponents.url else {
            print("Debug - URL OCR Gemini non valido")
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "URL OCR Gemini non valido"
                completion(nil)
            }
            return
        }
        
        // Determina il MIME type dell'immagine
        var mimeType = "image/png"
        if let image = NSImage(data: imageData) {
            if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                // Inizializziamo come PNG per sicurezza
                mimeType = "image/png"
                
                // Se è un JPEG, utilizziamo quel formato (più leggero per l'API)
                if let tiffData = image.tiffRepresentation,
                   let bitmapImage = NSBitmapImageRep(data: tiffData),
                   let jpegData = bitmapImage.representation(using: .jpeg, properties: [:]) {
                    mimeType = "image/jpeg"
                }
            }
        }
        
        // Prepara i parametri per la richiesta Gemini multimodale
        let parameters: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "inline_data": [
                                "mime_type": mimeType,
                                "data": base64Image
                            ]
                        ],
                        [
                            "text": "Estrai tutto il testo presente in questa immagine. Se non trovi testo, rispondi con una stringa vuota o '[NO_TEXT_FOUND]'."
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.1,
                "topK": 32,
                "topP": 0.95,
                "maxOutputTokens": 1024
            ]
        ]
        
        // Configura la richiesta HTTP
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Serializza i parametri in JSON
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            print("Debug - Errore nella serializzazione OCR Gemini: \(error)")
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Errore nella preparazione della richiesta OCR Gemini"
                completion(nil)
            }
            return
        }
        
        // Crea e avvia il task
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            // Verifica eventuali errori di connessione
            if let error = error {
                print("Debug - Errore di connessione OCR Gemini: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMessage = "Errore di connessione OCR Gemini: \(error.localizedDescription)"
                    completion(nil)
                }
                return
            }
            
            // Verifica che ci siano dati nella risposta
            guard let data = data else {
                print("Debug - Nessun dato OCR Gemini ricevuto")
                DispatchQueue.main.async {
                    self.errorMessage = "Nessun dato ricevuto dal server Gemini"
                    completion(nil)
                }
                return
            }
            
            // Prova a decodificare la risposta JSON di Gemini
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Verifica se c'è un messaggio di errore
                    if let errorInfo = json["error"] as? [String: Any],
                       let errorMessage = errorInfo["message"] as? String {
                        print("Debug - Errore API Gemini: \(errorMessage)")
                        
                        DispatchQueue.main.async {
                            self.errorMessage = "Errore API Gemini: \(errorMessage)"
                            completion(nil)
                        }
                        return
                    }
                    
                    // Tenta di estrarre il testo dall'immagine
                    if let candidates = json["candidates"] as? [[String: Any]],
                       let candidate = candidates.first,
                       let content = candidate["content"] as? [String: Any],
                       let parts = content["parts"] as? [[String: Any]],
                       let part = parts.first,
                       let extractedText = part["text"] as? String {
                        
                        // Rimuovi eventuali marker speciali o pulizia del testo
                        let cleanText = extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if cleanText == "[NO_TEXT_FOUND]" || cleanText.isEmpty {
                            print("Debug - Nessun testo trovato nell'immagine")
                            DispatchQueue.main.async {
                                self.errorMessage = "Nessun testo trovato nell'immagine"
                                completion(nil)
                            }
                            return
                        }
                        
                        print("Debug - Testo estratto da Gemini: \(cleanText)")
                        
                        DispatchQueue.main.async {
                            self.extractedText = cleanText
                            completion(cleanText)
                        }
                    } else {
                        print("Debug - Formato di risposta JSON Gemini inaspettato")
                        DispatchQueue.main.async {
                            self.errorMessage = "Formato di risposta Gemini non riconosciuto"
                            completion(nil)
                        }
                    }
                } else {
                    print("Debug - Impossibile convertire la risposta in JSON")
                    DispatchQueue.main.async {
                        self.errorMessage = "Errore nella risposta del servizio Gemini"
                        completion(nil)
                    }
                }
            } catch {
                print("Debug - Errore nella decodifica JSON Gemini: \(error)")
                DispatchQueue.main.async {
                    self.errorMessage = "Errore di elaborazione Gemini: \(error.localizedDescription)"
                    completion(nil)
                }
            }
        }
        
        task.resume()
    }
    
    // OCR locale utilizzando Vision framework
    @available(macOS 13.0, *)
    private func performLocalOCR(imageData: Data, completion: @escaping (String?) -> Void) {
        guard let image = NSImage(data: imageData),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Impossibile processare l'immagine"
                completion(nil)
            }
            return
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            if let error = error {
                print("Debug - Errore OCR locale: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMessage = "Errore OCR locale: \(error.localizedDescription)"
                    completion(nil)
                }
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                DispatchQueue.main.async {
                    self.errorMessage = "Formato risultati OCR inaspettato"
                    completion(nil)
                }
                return
            }
            
            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            if recognizedText.isEmpty {
                DispatchQueue.main.async {
                    self.errorMessage = "Nessun testo trovato nell'immagine"
                    completion(nil)
                }
                return
            }
            
            print("Debug - Testo estratto localmente: \(recognizedText)")
            
            DispatchQueue.main.async {
                self.extractedText = recognizedText
                completion(recognizedText)
            }
        }
        
        // Configurazione per migliorare la precisione
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        do {
            try requestHandler.perform([request])
        } catch {
            print("Debug - Errore nell'esecuzione OCR locale: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Errore nell'esecuzione OCR locale: \(error.localizedDescription)"
                completion(nil)
            }
        }
    }
    
    // Estrazione testo dalle immagini negli appunti
    func extractTextFromClipboardImage(completion: @escaping (String?) -> Void) {
        guard let pasteboard = NSPasteboard.general.pasteboardItems?.first else {
            DispatchQueue.main.async {
                self.errorMessage = "Nessun contenuto trovato negli appunti"
                completion(nil)
            }
            return
        }
        
        // Cerca un'immagine negli appunti
        if let imageData = pasteboard.data(forType: .tiff) ?? 
                         pasteboard.data(forType: .png) ?? 
                         pasteboard.data(forType: NSPasteboard.PasteboardType("public.jpeg")) {
            // Usa Gemini 1.5 Flash per OCR
            extractTextWithGeminiOCR(imageData: imageData, completion: completion)
        } else {
            DispatchQueue.main.async {
                self.errorMessage = "Nessuna immagine trovata negli appunti"
                completion(nil)
            }
        }
    }
    
    // Traduzione diretta dal testo negli appunti
    func translateFromClipboard(to targetLanguage: String, context: String? = nil, completion: @escaping (String?) -> Void) {
        guard let pasteboard = NSPasteboard.general.pasteboardItems?.first else {
            DispatchQueue.main.async {
                self.errorMessage = "Nessun contenuto trovato negli appunti"
                completion(nil)
            }
            return
        }
        
        // Controlla se c'è testo negli appunti
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            translate(text: text, from: "Auto", to: targetLanguage, context: context, completion: completion)
            return
        }
        
        // Altrimenti, prova a vedere se c'è un'immagine
        extractTextFromClipboardImage { [weak self] extractedText in
            guard let self = self else { return }
            
            if let text = extractedText, !text.isEmpty {
                // Aggiorniamo l'interfaccia per mostrare che è stato estratto testo da un'immagine
                print("Debug - Testo estratto con OCR, procedendo con la traduzione")
                
                DispatchQueue.main.async {
                    // Mostreremo questo testo estratto nell'interfaccia
                    self.extractedText = text
                    NotificationCenter.default.post(name: NSNotification.Name("TextExtractedFromImage"), object: text)
                    
                    // Proseguiamo con la traduzione
                    self.translate(text: text, from: "Auto", to: targetLanguage, context: context, completion: completion)
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Nessun testo trovato nell'immagine negli appunti"
                    completion(nil)
                }
            }
        }
    }
    
    // Estrazione e traduzione da un file trascinato
    func extractTextFromDraggedFile(url: URL, completion: @escaping (String?) -> Void) {
        isLoading = true
        errorMessage = nil
        
        // Determina il tipo di file
        let fileType = UTType(filenameExtension: url.pathExtension.lowercased()) ?? .item
        
        // Se è un'immagine
        if fileType.conforms(to: .image) {
            do {
                let imageData = try Data(contentsOf: url)
                // Usa il sistema Gemini OCR invece del vecchio sistema
                extractTextWithGeminiOCR(imageData: imageData) { extractedText in
                    if let text = extractedText {
                        DispatchQueue.main.async {
                            self.extractedText = text
                            // Notifica che abbiamo estratto testo da un'immagine trascinata
                            NotificationCenter.default.post(
                                name: NSNotification.Name("TextExtractedFromImage"), 
                                object: text
                            )
                            completion(text)
                        }
                    } else {
                        completion(nil)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Errore nella lettura del file immagine: \(error.localizedDescription)"
                    completion(nil)
                }
            }
            return
        }
        
        // Se è un file di testo
        if fileType.conforms(to: .text) || fileType.conforms(to: .plainText) {
            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                DispatchQueue.main.async {
                    self.isLoading = false
                    completion(text)
                }
            } catch {
                // Prova con altre codifiche
                do {
                    let text = try String(contentsOf: url, encoding: .isoLatin1)
                    DispatchQueue.main.async {
                        self.isLoading = false
                        completion(text)
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = "Errore nella lettura del file di testo: \(error.localizedDescription)"
                        completion(nil)
                    }
                }
            }
            return
        }
        
        // Se è un PDF
        if fileType.conforms(to: .pdf) {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Il riconoscimento del testo nei PDF non è ancora supportato"
                completion(nil)
            }
            return
        }
        
        // Se arriviamo qui, il formato non è supportato
        DispatchQueue.main.async {
            self.isLoading = false
            self.errorMessage = "Formato file non supportato"
            completion(nil)
        }
    }
    
    // Rileva la lingua del testo
    func detectLanguage(text: String, completion: @escaping (String?) -> Void) {
        // Annulla eventuali richieste precedenti
        languageDetectionTask?.cancel()
        
        // Utilizza Gemini per rilevare la lingua
        var urlComponents = URLComponents(string: geminiBaseURL)!
        urlComponents.queryItems = [URLQueryItem(name: "key", value: PreferencesManager.shared.apiKey)]
        
        guard let url = urlComponents.url else {
            print("Debug - URL rilevamento lingua non valido")
            completion(nil)
            return
        }
        
        let prompt = "Analizza il seguente testo e dimmi solo il nome della lingua in cui è scritto, rispondendo con una sola parola (es. 'Italiano', 'Inglese', ecc.): \"\(text.prefix(100))\""
        
        let parameters: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": prompt
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.1,
                "maxOutputTokens": 10
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            print("Debug - Errore nella serializzazione: \(error)")
            completion(nil)
            return
        }
        
        languageDetectionTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Verifica eventuali errori
            if let error = error {
                print("Debug - Errore nella rilevazione lingua: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("Debug - Nessun dato ricevuto per la rilevazione lingua")
                completion(nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = json["candidates"] as? [[String: Any]],
                   let candidate = candidates.first,
                   let content = candidate["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let part = parts.first,
                   let languageName = part["text"] as? String {
                    
                    let cleanLanguageName = languageName.trimmingCharacters(in: .whitespacesAndNewlines)
                                                        .capitalized
                    
                    print("Debug - Lingua rilevata: \(cleanLanguageName)")
                    
                    DispatchQueue.main.async {
                        self.detectedLanguage = cleanLanguageName
                        completion(cleanLanguageName)
                    }
                } else {
                    print("Debug - Formato di risposta inaspettato per rilevazione lingua")
                    completion(nil)
                }
            } catch {
                print("Debug - Errore nella decodifica JSON per rilevazione lingua: \(error)")
                completion(nil)
            }
        }
        
        languageDetectionTask?.resume()
    }
    
    // Inizializza le lingue supportate
    private func initSupportedLanguages() {
        let languages = [
            "Auto": "auto",
            "Italiano": "it",
            "Inglese": "en",
            "Francese": "fr",
            "Tedesco": "de",
            "Spagnolo": "es",
            "Portoghese": "pt",
            "Russo": "ru",
            "Cinese": "zh",
            "Giapponese": "ja",
            "Coreano": "ko",
            "Arabo": "ar",
            "Hindi": "hi",
            "Polacco": "pl",
            "Olandese": "nl",
            "Svedese": "sv",
            "Greco": "el",
            "Turco": "tr",
            "Ebraico": "he",
            "Tailandese": "th",
            "Vietnamita": "vi",
            "Indonesiano": "id",
            "Malese": "ms",
            "Ucraino": "uk"
        ]
        
        self.supportedLanguages = languages
    }
    
    // Converti il nome della lingua nel relativo codice ISO
    func getLanguageCode(for language: String) -> String {
        return supportedLanguages[language] ?? "en"
    }
    
    // Converti il codice ISO della lingua nel relativo nome
    func getLanguageName(for code: String) -> String {
        for (name, langCode) in supportedLanguages {
            if langCode == code {
                return name
            }
        }
        return "Sconosciuta"
    }
}