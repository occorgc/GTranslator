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
        self.defaultTargetLanguage = UserDefaults.standard.string(forKey: "defaultTargetLanguage") ?? "English"
        self.autoCopyToClipboard = UserDefaults.standard.bool(forKey: "autoCopyToClipboard")
        self.ocrApiKey = UserDefaults.standard.string(forKey: "ocrApiKey") ?? ""
        
        // Set default values on first launch
        if self.apiKey.isEmpty {
            self.apiKey = "" // The user will need to provide their own API key
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
        "English", "Italian", "French", "German", "Spanish", "Portuguese", 
        "Russian", "Chinese", "Japanese", "Korean", "Arabic", "Hindi", 
        "Polish", "Dutch", "Swedish", "Greek", "Turkish", "Hebrew", 
        "Thai", "Vietnamese", "Indonesian", "Malay", "Ukrainian"
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            Form {
                Section(header: Text("Gemini API")) {
                    SecureField("Gemini API Key", text: $preferences.apiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    HStack {
                        Button(action: {
                            preferences.apiKey = ""
                        }) {
                            Text("Clear")
                        }
                        .disabled(preferences.apiKey.isEmpty)
                        
                        Spacer()
                        
                        Button(action: {
                            isApiKeySaved = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                isApiKeySaved = false
                            }
                        }) {
                            Text("Save")
                        }
                        .disabled(preferences.apiKey.isEmpty)
                    }
                    
                    if isApiKeySaved {
                        Text("API key saved!")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                Section(header: Text("OCR API (Vision)")) {
                    SecureField("OCR API Key", text: $preferences.ocrApiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    HStack {
                        Button(action: {
                            preferences.ocrApiKey = ""
                        }) {
                            Text("Clear")
                        }
                        .disabled(preferences.ocrApiKey.isEmpty)
                        
                        Spacer()
                        
                        Button(action: {
                            isOCRApiKeySaved = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                isOCRApiKeySaved = false
                            }
                        }) {
                            Text("Save")
                        }
                        .disabled(preferences.ocrApiKey.isEmpty)
                    }
                    
                    if isOCRApiKeySaved {
                        Text("OCR API key saved!")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                Section(header: Text("General Settings")) {
                    Picker("Default language", selection: $preferences.defaultTargetLanguage) {
                        ForEach(allLanguages, id: \.self) { language in
                            Text(language)
                        }
                    }
                    
                    Toggle("Automatically copy to clipboard", isOn: $preferences.autoCopyToClipboard)
                }
            }
            .padding()
        }
        .frame(width: 380, height: 480)
    }
}