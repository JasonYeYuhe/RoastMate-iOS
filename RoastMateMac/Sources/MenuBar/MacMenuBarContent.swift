#if os(macOS)
import SwiftUI
import SwiftData

struct MacMenuBarContent: View {
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @State private var viewModel = RoastGeneratorViewModel()

    private var styles: [StylePreset] { StyleCatalog.shared.byTier(.free) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("mac.menubar.quick_roast")
                    .font(.headline)
                Spacer()
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Image(systemName: "macwindow")
                }
                .buttonStyle(.borderless)
                .help(String(localized: "mac.menubar.open_window"))
            }

            TextEditor(text: $viewModel.situation)
                .frame(minHeight: 70, idealHeight: 80)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.08))
                )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(styles) { style in
                        StyleChip(
                            style: style,
                            isSelected: viewModel.selectedStyleId == style.id,
                            isLocked: false
                        ) {
                            viewModel.selectedStyleId = style.id
                        }
                    }
                }
            }

            HStack {
                Button {
                    Task { await viewModel.generate(context: context, locale: locale) }
                } label: {
                    Label("generator.generate", systemImage: "flame.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(viewModel.situation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || viewModel.state == .loading)
            }

            resultsArea
        }
        .padding(14)
        .frame(width: 340)
    }

    @ViewBuilder
    private var resultsArea: some View {
        switch viewModel.state {
        case .idle:
            EmptyView()
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
        case .results:
            if let session = viewModel.currentSession {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach((session.results ?? []).sorted { $0.generatedAt < $1.generatedAt }, id: \.id) { result in
                        RoastCard(text: result.text, style: StyleCatalog.shared.style(id: result.styleId))
                    }
                }
            }
        case .error(let message):
            Text(message)
                .font(.callout)
                .foregroundStyle(.orange)
        }
    }
}
#endif
