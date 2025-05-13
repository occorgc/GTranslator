# Gtranslator

A macOS application that provides translation services directly from the menu bar.

This project is a fork of [GTranslator - GNOME Shell Extension](https://github.com/Griguoli09/gnome-shell-gtranslator-extension.git) modified to work on macOS 11+.

The reason for this project? To leverage Gemini's translation capabilities, having everything readily available on your Mac. Furthermore, the distinguishing strength of this project is the possibility of adding "context." For example, when translating technical terms that need proper contextualization for accurate translations.

## Features
- Quick text translation
- Access from the macOS menu bar
- Keyboard shortcut support
- Context-aware translation
- Image text recognition
- Auto-copy translated text
- Multi-language support
- Minimalist and functional design

## System Requirements
- macOS 11.0 or later
- Xcode 13.0 or later for development

## Installation
1. Download the latest version from the repository
2. Compile the project with Xcode or Swift Package Manager
3. Run the application

## Configuration
Before using the application, you need to configure:

1. Get a Gemini API key:
   - Visit [Google AI Studio](https://makersuite.google.com/app/apikey)
   - Create a new project (if necessary)
   - Generate a new API key

2. (Optional) Get a Google Vision API key for OCR features:
   - Visit [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project and enable the Vision API
   - Generate an API key

3. Configure the application:
   - Click on Preferences in the menu
   - Enter your API keys in the appropriate fields
   - Select the default target language

## How to Use
The application launches in the menu bar. Click on the globe icon to open the translation interface.

### Text Translation
1. Click on the Gtranslator icon in the menu bar
2. Enter or paste the text to translate in the input field
3. (Optional) Add context by clicking on the context toggle button
4. Select the target language from the dropdown menu
5. Click "Translate" or use the keyboard shortcut
6. The translated text will be displayed and automatically copied to the clipboard

### Image Translation
1. Copy an image containing text to your clipboard
2. Click on the Gtranslator icon in the menu bar
3. Click "Translate from Clipboard" or use the keyboard shortcut
4. The application will extract text from the image using OCR
5. The extracted text will automatically be translated to your selected language

### Keyboard Shortcuts
- Cmd+T: Translate selected text
- Cmd+V: Translate from clipboard
- Cmd+C: Copy translation result
- Cmd+Delete: Clear all
- Cmd+A: Select all
- Cmd+K: Toggle context
- Cmd+Q: Quit application

## Development
This project was created using Swift and SwiftUI for macOS.

## License
This project is released under the MIT License. See the `LICENSE` file for details.

---

© 2025 Gtranslator