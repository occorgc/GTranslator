import SwiftUI
import Combine

class PreferencesManager: ObservableObject {
    @Published var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: "apiKey")
        }
    }
    
    @Published var defaultTargetLanguage: String {
        didSet {
            UserDefaults.standard.set(defaultTargetLanguage, forKey: "defaultTargetLanguage")
        }
    }
    
    @Published var autoCopyToClipboard: Bool {
        didSet {
            UserDefaults.standard.set(autoCopyToClipboard, forKey: "autoCopyToClipboard")
        }
    }
    
    @Published var ocrApiKey: String {
        didSet {
            UserDefaults.standard.set(ocrApiKey, forKey: "ocrApiKey")
        }
    }
    
    init() {
        self.apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""
        self.defaultTargetLanguage = UserDefaults.standard.string(forKey: "defaultTargetLanguage") ?? "Italiano"
        self.autoCopyToClipboard = UserDefaults.standard.bool(forKey: "autoCopyToClipboard")
        self.ocrApiKey = UserDefaults.standard.string(forKey: "ocrApiKey") ?? ""
        
        // Imposta valori di default se è il primo avvio
        if self.apiKey.isEmpty {
            self.apiKey = "AIzaSyC7CedU0JuheHSkKv_fquWngcuBZrhAKsk" // Chiave di default (cambiare con la propria)
        }
        if !UserDefaults.standard.bool(forKey: "firstLaunchDone") {
            self.autoCopyToClipboard = true
            UserDefaults.standard.set(true, forKey: "firstLaunchDone")
        }
    }
    
    static let shared = PreferencesManager()
}

struct PreferencesView: View {
    @ObservedObject var preferences = PreferencesManager.shared
    @State private var isApiKeySaved = false
    @State private var isOCRApiKeySaved = false
    
    private let allLanguages = [
        "Italiano", "Inglese", "Francese", "Tedesco", "Spagnolo", "Portoghese", 
        "Russo", "Cinese", "Giapponese", "Coreano", "Arabo", "Hindi", 
        "Polacco", "Olandese", "Svedese", "Greco", "Turco", "Ebraico", 
        "Tailandese", "Vietnamita", "Indonesiano", "Malese", "Ucraino"
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            Form {
                Section(header: Text("API Gemini")) {
                    SecureField("Chiave API Gemini", text: $preferences.apiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    HStack {
                        Button(action: {
                            preferences.apiKey = ""
                        }) {
                            Text("Cancella")
                        }
                        .disabled(preferences.apiKey.isEmpty)
                        
                        Spacer()
                        
                        Button(action: {
                            isApiKeySaved = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                isApiKeySaved = false
                            }
                        }) {
                            Text("Salva")
                        }
                        .disabled(preferences.apiKey.isEmpty)
                    }
                    
                    if isApiKeySaved {
                        Text("Chiave API salvata!")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                Section(header: Text("API OCR (Vision)")) {
                    SecureField("Chiave API OCR", text: $preferences.ocrApiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    HStack {
                        Button(action: {
                            preferences.ocrApiKey = ""
                        }) {
                            Text("Cancella")
                        }
                        .disabled(preferences.ocrApiKey.isEmpty)
                        
                        Spacer()
                        
                        Button(action: {
                            isOCRApiKeySaved = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                isOCRApiKeySaved = false
                            }
                        }) {
                            Text("Salva")
                        }
                        .disabled(preferences.ocrApiKey.isEmpty)
                    }
                    
                    if isOCRApiKeySaved {
                        Text("Chiave API OCR salvata!")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                Section(header: Text("Impostazioni Generali")) {
                    Picker("Lingua predefinita", selection: $preferences.defaultTargetLanguage) {
                        ForEach(allLanguages, id: \.self) { language in
                            Text(language)
                        }
                    }
                    
                    Toggle("Copia automaticamente negli appunti", isOn: $preferences.autoCopyToClipboard)
                }
            }
            .padding()
        }
        .frame(width: 380, height: 480)
    }
}