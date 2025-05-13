import SwiftUI
import UniformTypeIdentifiers

struct DragAndDropView: View {
    var onFileDropped: (URL) -> Void
    @State private var isActive = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.blue : Color.gray.opacity(0.5), lineWidth: isActive ? 2 : 1)
                .background(Color.gray.opacity(0.1).cornerRadius(8))
            
            VStack(spacing: 8) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.largeTitle)
                    .foregroundColor(isActive ? .blue : .gray)
                
                Text("Drop a file or image here")
                    .font(.caption)
                    .foregroundColor(isActive ? .blue : .gray)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .frame(height: 100)
        .onDrop(of: [.fileURL], isTargeted: $isActive) { providers in
            guard let provider = providers.first else { return false }
            
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { (data, error) in
                if let error = error {
                    print("Error loading data: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data as? Data,
                      let path = String(data: data, encoding: .utf8),
                      let url = URL(string: path) else {
                    return
                }
                
                DispatchQueue.main.async {
                    self.onFileDropped(url)
                }
            }
            
            return true
        }
    }
}

// Header View
struct HeaderView: View {
    @Binding var showPreferences: Bool
    
    var body: some View {
        HStack {
            Text("Gtranslator")
                .font(.headline)
            
            Spacer()
            
            Button(action: {
                showPreferences = true
            }) {
                Image(systemName: "gear")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
        .padding(.horizontal)
    }
}

// Language selectors
struct LanguageSelectionView: View {
    @Binding var sourceLanguage: String
    @Binding var targetLanguage: String
    var allLanguages: [String]
    
    var body: some View {
        HStack {
            Picker("Da", selection: $sourceLanguage) {
                ForEach(allLanguages, id: \.self) { language in
                    Text(language)
                }
            }
            .frame(width: 120)
            
            Image(systemName: "arrow.right")
                .foregroundColor(.secondary)
            
            Picker("A", selection: $targetLanguage) {
                ForEach(allLanguages.filter { $0 != "Auto" }, id: \.self) { language in
                    Text(language)
                }
            }
            .frame(width: 120)
            .onChange(of: targetLanguage) { newValue in
                // Updates default language in preferences
                PreferencesManager.shared.defaultTargetLanguage = newValue
            }
            .onAppear {
                // Sets default language from preferences at startup
                targetLanguage = PreferencesManager.shared.defaultTargetLanguage
            }
        }
        .padding(.horizontal)
    }
}

// Input area
struct InputTextView: View {
    @Binding var text: String
    
    var body: some View {
        TextEditor(text: $text)
            .frame(height: 80)
            .padding(4)
            .background(Color(.textBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal)
    }
}

// Context area
struct ContextView: View {
    @Binding var showContextField: Bool
    @Binding var context: String
    
    var body: some View {
        VStack {
            Button(action: {
                showContextField.toggle()
            }) {
                HStack {
                    Image(systemName: showContextField ? "minus" : "plus")
                        .font(.caption)
                    Text(showContextField ? "Hide context" : "Add context")
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if showContextField {
                TextEditor(text: $context)
                    .frame(height: 60)
                    .padding(4)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .transition(.opacity)
            }
        }
    }
}

// Bottoni di traduzione
struct TranslationButtonsView: View {
    @Binding var textToTranslate: String
    @Binding var translatedText: String
    @Binding var sourceLanguage: String
    @Binding var targetLanguage: String
    @Binding var showContextField: Bool
    @Binding var context: String
    var translatorService: TranslatorService
    var onTranslateFromClipboard: () -> Void  // Callback for paste action
    
    var body: some View {
        HStack {
            Button(action: {
                translateText()
            }) {
                Text("Translate")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(textToTranslate.isEmpty || translatorService.isLoading)
            
            Button(action: {
                onTranslateFromClipboard()  // Uses callback instead of local method
            }) {
                Text("From clipboard")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(translatorService.isLoading)
        }
        .padding(.horizontal)
    }
    
    private func translateText() {
        translatorService.translate(
            text: textToTranslate,
            from: sourceLanguage,
            to: targetLanguage,
            context: showContextField ? context : nil
        ) { result in
            handleTranslationResult(result)
        }
    }
    
    private func handleTranslationResult(_ result: String?) {
        if let translated = result {
            translatedText = translated
            // Copia automaticamente negli appunti se abilitato
            if PreferencesManager.shared.autoCopyToClipboard {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(translated, forType: .string)
            }
        } else if let error = translatorService.errorMessage {
            translatedText = "Error: \(error)"
        } else {
            translatedText = "Error during translation"
        }
    }
}

// Results area
struct ResultView: View {
    @Binding var translatedText: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Result:")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .font(.caption)
                .foregroundColor(.secondary)
            
            ScrollView {
                Text(translatedText)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                    .padding(8)
            }
            .background(Color(.textBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .frame(height: 100) // Altezza fissa per la scroll view
            .padding(.horizontal)
        }
    }
}

// Action buttons at the bottom
struct ActionButtonsView: View {
    @Binding var translatedText: String
    @Binding var textToTranslate: String
    @Binding var showExtractedText: Bool
    var translatorService: TranslatorService
    
    var body: some View {
        HStack {
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(translatedText, forType: .string)
            }) {
                Image(systemName: "doc.on.doc")
                Text("Copy")
            }
            .disabled(translatedText.isEmpty)
            
            Spacer()
            
            Button(action: {
                // Clear all fields
                textToTranslate = ""
                translatedText = ""
                translatorService.extractedText = ""
                showExtractedText = false
            }) {
                Image(systemName: "trash")
                Text("Clear")
            }
            .disabled(textToTranslate.isEmpty && translatedText.isEmpty)
            
            Spacer()
            
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Image(systemName: "xmark.circle")
                Text("Quit")
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

// Vista principale
struct MenuBarView: View {
    @StateObject private var translatorService = TranslatorService()
    @State private var textToTranslate: String = ""
    @State private var translatedText: String = ""
    @State private var sourceLanguage: String = "Auto"
    @State private var targetLanguage: String = "Italiano"
    @State private var showContextField: Bool = false
    @State private var context: String = ""
    @State private var showPreferences: Bool = false
    @State private var showExtractedText: Bool = false
    @State private var extractionSource: String = ""
    
    private var allLanguages: [String] {
        Array(translatorService.supportedLanguages.keys).sorted()
    }
    
    var body: some View {
        VStack {
            if showPreferences {
                // Mostra la vista preferenze integrata
                VStack {
                    HStack {
                        Button(action: {
                            showPreferences = false
                        }) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 14))
                            Text("Indietro")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                    
                    PreferencesView()
                        .padding(.top, -10)
                }
            } else {
                // Primo gruppo di elementi (parte superiore)
                topSection
                
                // Secondo gruppo di elementi (parte centrale)
                middleSection
                
                // Terzo gruppo di elementi (parte inferiore)
                bottomSection
            }
        }
        .frame(width: 380)
        .onAppear {
            // Registra l'osservatore per le notifiche di testo estratto da immagini
            setupNotificationObservers()
        }
        .onDisappear {
            // Rimuovi l'osservatore quando la vista scompare
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    private func setupNotificationObservers() {
        // Osservatore per testo estratto da immagini
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TextExtractedFromImage"),
            object: nil,
            queue: .main
        ) { notification in
            if let extractedText = notification.object as? String {
                // Imposta il testo estratto e mostra la vista
                self.textToTranslate = extractedText
                self.showExtractedText = true
                self.extractionSource = "immagine negli appunti"
            }
        }
        
        // Osservatore per mostrare le preferenze da altre fonti (menu contestuale, shortcut)
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ShowPreferencesView"),
            object: nil,
            queue: .main
        ) { _ in
            self.showPreferences = true
        }
        
        // Osservatori per le scorciatoie da tastiera
        let appDelegate = NSApplication.shared.delegate as? AppDelegate
        
        // Traduci (Cmd+T)
        NotificationCenter.default.addObserver(
            forName: appDelegate?.translateNotification ?? Notification.Name("TranslateShortcut"),
            object: nil,
            queue: .main
        ) { _ in
            self.translate()
        }
        
        // Traduci dagli appunti (Cmd+V)
        NotificationCenter.default.addObserver(
            forName: appDelegate?.translateClipboardNotification ?? Notification.Name("TranslateClipboardShortcut"),
            object: nil,
            queue: .main
        ) { _ in
            self.translateFromClipboard()
        }
        
        // Copia risultato (Cmd+C)
        NotificationCenter.default.addObserver(
            forName: appDelegate?.copyResultNotification ?? Notification.Name("CopyResultShortcut"),
            object: nil,
            queue: .main
        ) { _ in
            self.copyResultToClipboard()
        }
        
        // Pulisci tutto (Cmd+Delete)
        NotificationCenter.default.addObserver(
            forName: appDelegate?.clearAllNotification ?? Notification.Name("ClearAllShortcut"),
            object: nil,
            queue: .main
        ) { _ in
            self.clearAll()
        }
        
        // Mostra/Nascondi contesto (Cmd+K)
        NotificationCenter.default.addObserver(
            forName: appDelegate?.toggleContextNotification ?? Notification.Name("ToggleContextShortcut"),
            object: nil,
            queue: .main
        ) { _ in
            self.showContextField.toggle()
        }
        
        // Seleziona tutto (Cmd+A)
        NotificationCenter.default.addObserver(
            forName: appDelegate?.selectAllNotification ?? Notification.Name("SelectAllShortcut"),
            object: nil,
            queue: .main
        ) { _ in
            NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
        }
    }
    
    // Funzioni per gestire le azioni delle scorciatoie
    func translate() {
        guard !textToTranslate.isEmpty && !translatorService.isLoading else { return }
        
        translatorService.translate(
            text: textToTranslate,
            from: sourceLanguage,
            to: targetLanguage,
            context: showContextField ? context : nil
        ) { result in
            handleTranslationResult(result)
        }
    }
    
    func translateFromClipboard() {
        guard !translatorService.isLoading else { return }
        
        // Prima otteniamo il testo dagli appunti e lo mostriamo nel campo di input
        if let string = NSPasteboard.general.string(forType: .string), !string.isEmpty {
            // Aggiorna il campo di input con il testo copiato
            textToTranslate = string
            
            // Diamo all'utente la possibilità di vedere e modificare il testo prima di tradurlo
            return
        }
        
        // Se non c'è testo, ma ad esempio un'immagine, continuiamo con l'estrazione OCR
        translatorService.translateFromClipboard(
            to: targetLanguage,
            context: showContextField ? context : nil
        ) { result in
            handleTranslationResult(result)
        }
    }
    
    func copyResultToClipboard() {
        guard !translatedText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(translatedText, forType: .string)
    }
    
    func clearAll() {
        textToTranslate = ""
        translatedText = ""
        translatorService.extractedText = ""
        showExtractedText = false
    }
    
    private func handleTranslationResult(_ result: String?) {
        if let translated = result {
            translatedText = translated
            // Copia automaticamente negli appunti se abilitato
            if PreferencesManager.shared.autoCopyToClipboard {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(translated, forType: .string)
            }
        } else if let error = translatorService.errorMessage {
            translatedText = "Errore: \(error)"
        } else {
            translatedText = "Errore durante la traduzione"
        }
    }
    
    // Sezione superiore (Header, Selector, Input)
    private var topSection: some View {
        VStack(spacing: 12) {
            HeaderView(showPreferences: $showPreferences)
            
            LanguageSelectionView(
                sourceLanguage: $sourceLanguage,
                targetLanguage: $targetLanguage,
                allLanguages: allLanguages
            )
            
            InputTextView(text: $textToTranslate)
        }
    }
    
    // Sezione centrale (Drag & Drop, Testo estratto, Contesto, Lingua rilevata)
    private var middleSection: some View {
        VStack(spacing: 12) {
            DragAndDropView { url in
                translatorService.extractTextFromDraggedFile(url: url) { extractedText in
                    if let text = extractedText {
                        textToTranslate = text
                        showExtractedText = true
                    }
                }
            }
            .padding(.horizontal)
            
            if showExtractedText && !translatorService.extractedText.isEmpty {
                extractedTextView
            }
            
            ContextView(showContextField: $showContextField, context: $context)
            
            if sourceLanguage == "Auto" && translatorService.detectedLanguage != "Auto" {
                Text("Lingua rilevata: \(translatorService.detectedLanguage)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }
        }
    }
    
    // Sezione inferiore (Bottoni, Loader, Errore, Risultato, Azioni)
    private var bottomSection: some View {
        VStack(spacing: 12) {
            TranslationButtonsView(
                textToTranslate: $textToTranslate,
                translatedText: $translatedText,
                sourceLanguage: $sourceLanguage,
                targetLanguage: $targetLanguage,
                showContextField: $showContextField,
                context: $context,
                translatorService: translatorService,
                onTranslateFromClipboard: translateFromClipboard
            )
            
            Group {
                if translatorService.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                        .frame(height: 20)
                } else {
                    Spacer()
                        .frame(height: 20)
                }
            }
            
            if let errorMessage = translatorService.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }
            
            ResultView(translatedText: $translatedText)
            
            ActionButtonsView(
                translatedText: $translatedText,
                textToTranslate: $textToTranslate,
                showExtractedText: $showExtractedText,
                translatorService: translatorService
            )
        }
    }
    
    // Vista per il testo estratto
    private var extractedTextView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Testo estratto da \(extractionSource):")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(translatorService.extractedText)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color(NSColor.systemBlue).opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
        .transition(.opacity)
    }
}