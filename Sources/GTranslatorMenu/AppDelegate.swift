import Cocoa
import SwiftUI

// Definizione dei comandi per scorciatoie da tastiera
enum KeyboardShortcut: String {
    case translate = "t"            // Cmd+T
    case translateClipboard = "v"   // Cmd+V
    case copyResult = "c"           // Cmd+C
    case clearAll = "delete"        // Cmd+Delete
    case toggleContext = "k"        // Cmd+K
    case openPreferences = ","      // Cmd+,
    case quit = "q"                 // Cmd+Q
    case selectAll = "a"            // Cmd+A
}

class PopoverDelegate: NSObject, NSPopoverDelegate {
    var windowController: NSWindowController?
    
    // Questo metodo viene chiamato quando il popover sta per chiudersi
    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        // Permettiamo sempre la chiusura quando richiesto esplicitamente 
        // ma non quando scatenato da clic esterni
        if let reason = NSApp.currentEvent, reason.type == .leftMouseDown {
            // Se viene chiamato a causa di un clic esterno, impediamo la chiusura
            return false
        }
        return true
    }
    
    // Questo metodo viene chiamato quando il popover si è effettivamente chiuso
    func popoverDidClose(_ notification: Notification) {
        windowController = nil
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    var statusBarItem: NSStatusItem!
    var popover: NSPopover!
    var preferencesWindow: NSWindow?
    var popoverDelegate = PopoverDelegate()
    var eventMonitor: Any?
    var keyboardMonitor: Any?
    var closeOnNextClick = false
    
    // Eventi da notificare all'interfaccia
    let translateNotification = Notification.Name("TranslateShortcut")
    let translateClipboardNotification = Notification.Name("TranslateClipboardShortcut")
    let copyResultNotification = Notification.Name("CopyResultShortcut")
    let clearAllNotification = Notification.Name("ClearAllShortcut")
    let toggleContextNotification = Notification.Name("ToggleContextShortcut")
    let selectAllNotification = Notification.Name("SelectAllShortcut")
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Imposta l'app come UI Element (solo barra dei menu, no Dock)
        NSApp.setActivationPolicy(.accessory)
        
        // Inizializza le preferenze all'avvio
        _ = PreferencesManager.shared
        
        // Crea l'interfaccia SwiftUI
        let contentView = MenuBarView()
        
        // Configura il popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 580)
        popover.behavior = .applicationDefined
        popover.contentViewController = NSHostingController(rootView: contentView)
        popover.delegate = popoverDelegate
        
        // Configura l'icona della barra dei menu
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusBarItem.button {
            button.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "Translate")
            
            // Configura l'azione per il clic primario (sinistro)
            button.action = #selector(handleButtonAction(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Configura il monitor degli eventi per gestire i clic esterni
        setupEventMonitor()
        
        // Configura il monitor per le scorciatoie da tastiera
        setupKeyboardMonitor()
        
        // Crea il menu principale dell'applicazione con le scorciatoie da tastiera
        setupApplicationMenu()
    }
    
    func setupEventMonitor() {
        // Monitoriamo sia clic sinistro che destro
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.popover.isShown else { return event }
            
            // Controlla se il clic è fuori dal popover
            if let contentView = self.popover.contentViewController?.view,
               let window = contentView.window,
               !contentView.frame.contains(contentView.convert(event.locationInWindow, from: nil)) {
                
                // Se è il secondo clic fuori, allora chiudiamo il popover
                if self.closeOnNextClick {
                    self.popover.performClose(nil)
                    self.closeOnNextClick = false
                } else {
                    // Al primo clic fuori, settiamo la flag per chiudere al prossimo clic
                    self.closeOnNextClick = true
                }
            }
            
            return event
        }
    }
    
    // Setup del monitor per le scorciatoie da tastiera
    func setupKeyboardMonitor() {
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            // Gestisci le combinazioni Cmd+tasto
            if event.modifierFlags.contains(.command) {
                if let key = event.charactersIgnoringModifiers?.lowercased() {
                    switch key {
                    case KeyboardShortcut.translate.rawValue: // Cmd+T (Traduci)
                        if self.popover.isShown {
                            NotificationCenter.default.post(name: self.translateNotification, object: nil)
                            return nil
                        }
                        
                    case KeyboardShortcut.translateClipboard.rawValue: // Cmd+V (Traduci dagli appunti)
                        // Verifica se siamo in un campo di testo (in tal caso lascia funzionare normalmente)
                        if let firstResponder = NSApp.keyWindow?.firstResponder, 
                           (firstResponder.isKind(of: NSText.self) || 
                            firstResponder.isKind(of: NSTextView.self) || 
                            firstResponder.isKind(of: NSTextField.self)) {
                            return event // Lascia che il sistema gestisca l'incolla nel campo di testo
                        }
                        
                        if self.popover.isShown {
                            NotificationCenter.default.post(name: self.translateClipboardNotification, object: nil)
                            return nil
                        }
                        
                    case KeyboardShortcut.copyResult.rawValue: // Cmd+C (Copia risultato)
                        // Verifica se siamo in un campo di testo con selezione (in tal caso lascia funzionare normalmente)
                        if let firstResponder = NSApp.keyWindow?.firstResponder {
                            if let textView = firstResponder as? NSTextView, !textView.selectedRanges.isEmpty {
                                return event // C'è testo selezionato, lascia che il sistema gestisca la copia
                            }
                            if let textField = firstResponder as? NSTextField, textField.currentEditor() != nil {
                                return event // Il campo di testo è in modifica, lascia che il sistema gestisca
                            }
                        }
                        
                        if self.popover.isShown {
                            NotificationCenter.default.post(name: self.copyResultNotification, object: nil)
                            return nil
                        }
                        
                    case KeyboardShortcut.selectAll.rawValue: // Cmd+A (Seleziona tutto)
                        // Sempre per i campi di testo, lascia che il sistema gestisca la selezione
                        if let firstResponder = NSApp.keyWindow?.firstResponder,
                           (firstResponder.isKind(of: NSText.self) || 
                            firstResponder.isKind(of: NSTextView.self) || 
                            firstResponder.isKind(of: NSTextField.self)) {
                            return event
                        }
                        
                        if self.popover.isShown {
                            NotificationCenter.default.post(name: self.selectAllNotification, object: nil)
                            return nil
                        }
                        
                    case KeyboardShortcut.clearAll.rawValue, "\u{8}": // Cmd+Delete/Backspace (Pulisci tutto)
                        if self.popover.isShown {
                            NotificationCenter.default.post(name: self.clearAllNotification, object: nil)
                            return nil
                        }
                        
                    case KeyboardShortcut.toggleContext.rawValue: // Cmd+K (Mostra/Nascondi contesto)
                        if self.popover.isShown {
                            NotificationCenter.default.post(name: self.toggleContextNotification, object: nil)
                            return nil
                        }
                        
                    case KeyboardShortcut.openPreferences.rawValue: // Cmd+, (Preferenze)
                        self.showPreferences()
                        return nil
                        
                    case KeyboardShortcut.quit.rawValue: // Cmd+Q (Esci)
                        NSApplication.shared.terminate(nil)
                        return nil
                        
                    default:
                        break
                    }
                }
            }
            
            return event
        }
    }
    
    // Configurazione del menu dell'applicazione con le scorciatoie
    func setupApplicationMenu() {
        let mainMenu = NSMenu()
        
        // Menu Applicazione
        let appMenuItem = NSMenuItem(title: "GTranslator", action: nil, keyEquivalent: "")
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Preferenze", action: #selector(showPreferences), keyEquivalent: KeyboardShortcut.openPreferences.rawValue))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Esci", action: #selector(NSApplication.terminate(_:)), keyEquivalent: KeyboardShortcut.quit.rawValue))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        // Menu Modifica
        let editMenuItem = NSMenuItem(title: "Modifica", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Modifica")
        editMenu.addItem(NSMenuItem(title: "Traduci", action: #selector(handleTranslateAction), keyEquivalent: KeyboardShortcut.translate.rawValue))
        editMenu.addItem(NSMenuItem(title: "Traduci dagli appunti", action: #selector(handleTranslateClipboardAction), keyEquivalent: KeyboardShortcut.translateClipboard.rawValue))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Copia risultato", action: #selector(handleCopyResultAction), keyEquivalent: KeyboardShortcut.copyResult.rawValue))
        editMenu.addItem(NSMenuItem(title: "Pulisci tutto", action: #selector(handleClearAllAction), keyEquivalent: KeyboardShortcut.clearAll.rawValue))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Mostra/Nascondi contesto", action: #selector(handleToggleContextAction), keyEquivalent: KeyboardShortcut.toggleContext.rawValue))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        
        NSApplication.shared.mainMenu = mainMenu
    }
    
    @objc func handleButtonAction(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        
        if event.type == .rightMouseUp {
            // Clic destro: mostra il menu contestuale
            let menu = createContextMenu()
            statusBarItem.menu = menu
            statusBarItem.button?.performClick(nil)
            statusBarItem.menu = nil
        } else {
            // Clic sinistro: mostra il popover
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
                // Reset della flag quando il popover viene aperto
                closeOnNextClick = false
            }
        }
    }
    
    // Gestori delle azioni da tastiera
    @objc func handleTranslateAction() {
        NotificationCenter.default.post(name: translateNotification, object: nil)
    }
    
    @objc func handleTranslateClipboardAction() {
        NotificationCenter.default.post(name: translateClipboardNotification, object: nil)
    }
    
    @objc func handleCopyResultAction() {
        NotificationCenter.default.post(name: copyResultNotification, object: nil)
    }
    
    @objc func handleClearAllAction() {
        NotificationCenter.default.post(name: clearAllNotification, object: nil)
    }
    
    @objc func handleToggleContextAction() {
        NotificationCenter.default.post(name: toggleContextNotification, object: nil)
    }
    
    private func createContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        
        menu.addItem(NSMenuItem(title: "Preferenze", action: #selector(showPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Esci", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        return menu
    }
    
    @objc func showPreferences() {
        if preferencesWindow == nil {
            // Crea una nuova istanza di PreferencesView con un controllo manuale di chiusura
            let preferencesView = PreferencesView().onDisappear {
                // Questo si attiva quando la vista SwiftUI scompare
                self.preferencesWindow?.close()
                self.preferencesWindow = nil
            }
            
            let hostingController = NSHostingController(rootView: preferencesView)
            
            // Crea una finestra standard con i controlli appropriati
            preferencesWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            
            preferencesWindow?.center()
            preferencesWindow?.title = "Preferenze GTranslator"
            preferencesWindow?.contentViewController = hostingController
            
            // Importante: imposta il delegate per gestire correttamente gli eventi di chiusura
            preferencesWindow?.delegate = self
            
            // La finestra sarà rilasciata quando viene chiusa
            preferencesWindow?.isReleasedWhenClosed = true
        }
        
        // Mostra e attiva la finestra
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        // Quando la finestra delle preferenze viene chiusa, la reimposta a nil
        if notification.object as? NSWindow == preferencesWindow {
            preferencesWindow = nil
        }
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Consenti sempre la chiusura quando l'utente lo richiede
        return true
    }
    
    deinit {
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        if let keyboardMonitor = keyboardMonitor {
            NSEvent.removeMonitor(keyboardMonitor)
        }
    }
}