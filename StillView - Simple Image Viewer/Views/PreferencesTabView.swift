import AppKit
import SwiftUI

/// Pane content hosted by the native macOS settings tab controller.
struct PreferencesTabView: View {
    let selectedTab: Preferences.Tab

    var body: some View {
        Group {
            switch selectedTab {
            case .general:
                GeneralPreferencesView()
            case .intelligence:
                IntelligencePreferencesView()
            case .shortcuts:
                ShortcutsPreferencesView()
            }
        }
        .frame(width: 560, height: selectedTab.contentHeight)
    }
}

/// Startup defaults are kept together so their timing is explicit.
struct GeneralPreferencesView: View {
    @EnvironmentObject private var viewModel: PreferencesViewModel

    var body: some View {
        Form {
            Section {
                Toggle("Show file names", isOn: $viewModel.showFileName)
                Toggle("Open the image inspector", isOn: $viewModel.showImageInfo)
            } header: {
                Text("At launch")
            } footer: {
                Text("Choose what appears when you open StillView.")
            }

            Section {
                LabeledContent("Slide duration") {
                    Stepper(value: $viewModel.slideshowInterval, in: 1...30, step: 1) {
                        Text("\(Int(viewModel.slideshowInterval)) seconds")
                            .monospacedDigit()
                    }
                    .fixedSize()
                    .accessibilityLabel("Slide duration")
                    .accessibilityValue("\(Int(viewModel.slideshowInterval)) seconds")
                }
            } header: {
                Text("Slideshow")
            } footer: {
                Text("Slideshows repeat after the last image. Duration changes apply the next time you open StillView.")
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
    }
}

/// Live image-processing preferences and their privacy implications.
struct IntelligencePreferencesView: View {
    @EnvironmentObject private var viewModel: PreferencesViewModel

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $viewModel.enableAIAnalysis) {
                    Text("AI Insights")
                    Text("Describe images, highlight details, and recognize text on this Mac.")
                }
                .accessibilityLabel("AI Insights")
                .accessibilityHint("Describe images, highlight details, and recognize text on this Mac.")
            } header: {
                Text("Image analysis")
            } footer: {
                Text("Uses Vision and Apple Intelligence on this Mac. Requires Apple Intelligence to be enabled.")
            }

            Section {
                Toggle(isOn: $viewModel.enableImageEnhancements) {
                    Text("Enhance images automatically")
                    Text("Reduce noise, adjust color, and refine cropping when images load.")
                }
                .accessibilityLabel("Enhance images automatically")
                .accessibilityHint("Reduce noise, adjust color, and refine cropping when images load.")
            } header: {
                Text("Image enhancements")
            } footer: {
                Text("Only the displayed image changes. Your original files are preserved.")
            }

            Section {
                LabeledContent {
                    if let privacyURL = URL(string: "https://stillviewapp.com/privacy.html") {
                        Link("Privacy Policy", destination: privacyURL)
                    }
                } label: {
                    Label("Analysis stays on this Mac", systemImage: "lock.shield")
                }
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
    }
}

/// Searchable reference generated from the active keyboard handler.
struct ShortcutsPreferencesView: View {
    @State private var searchText = ""

    private var shortcuts: [String: String] {
        KeyboardHandler.getKeyboardShortcuts()
    }

    private var filteredKeys: [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return shortcuts.keys.filter { key in
            query.isEmpty
                || key.localizedCaseInsensitiveContains(query)
                || (shortcuts[key]?.localizedCaseInsensitiveContains(query) ?? false)
        }.sorted {
            (shortcuts[$0] ?? $0).localizedStandardCompare(shortcuts[$1] ?? $1) == .orderedAscending
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Image commands work when the viewer has focus. Use the menu bar for app commands.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ShortcutSearchField(text: $searchText)
                .frame(height: 24)

            Group {
                if filteredKeys.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("No shortcuts match \(searchText)")
                        .accessibilityHint("Try a different action or key.")
                } else {
                    List {
                        ForEach(filteredKeys, id: \.self) { key in
                            HStack(alignment: .firstTextBaseline, spacing: 16) {
                                Text(shortcuts[key] ?? "")
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 16)
                                Text(key)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .fixedSize()
                            }
                            .padding(.vertical, 4)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: false))
                    .accessibilityLabel("Built-in keyboard shortcuts")
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(20)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

/// Native search provides the standard focus ring, clear button, and Escape behavior.
private struct ShortcutSearchField: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = "Search shortcuts"
        field.setAccessibilityLabel("Search shortcuts")
        field.sendsSearchStringImmediately = true
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text {
            field.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: ShortcutSearchField

        init(parent: ShortcutSearchField) { self.parent = parent }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            parent.text = field.stringValue
        }
    }
}

#Preview("General · Light") {
    PreferencesTabView(selectedTab: .general)
        .environmentObject(PreferencesViewModel())
        .preferredColorScheme(.light)
}

#Preview("Intelligence · Dark") {
    PreferencesTabView(selectedTab: .intelligence)
        .environmentObject(PreferencesViewModel())
        .preferredColorScheme(.dark)
}
