import SwiftUI
import SwiftData

/// Multi-turn argument rehearsal. The AI plays the "other side" of a
/// conversation the user wants to practice. User responds; AI continues
/// in character. Pro feature.
struct ArgumentSimulatorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @State private var viewModel = ArgumentSimulatorViewModel()
    @State private var showPaywall = false
    @State private var userInput: String = ""

    private var isPro: Bool { StoreService.shared.isPro }

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.phase {
            case .setup:
                setupView
            case .running:
                transcriptView
                inputBar
            }
        }
        .navigationTitle("feature.argument.title")
        .sheet(isPresented: $showPaywall) {
            PaywallView(isPresented: $showPaywall)
        }
        .onAppear {
            if !isPro { showPaywall = true }
        }
    }

    private var setupView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "person.2.wave.2")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("feature.argument.empty_title").font(.headline)
                        Text("feature.argument.empty_subtitle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("Pro")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange.opacity(0.18)))
                        .foregroundStyle(.orange)
                }

                TextEditor(text: $viewModel.setup)
                    .frame(minHeight: 130)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.08)))
                    .overlay(alignment: .topLeading) {
                        if viewModel.setup.isEmpty {
                            Text("feature.argument.placeholder")
                                .foregroundStyle(.tertiary)
                                .padding(14)
                                .allowsHitTesting(false)
                        }
                    }

                VStack(alignment: .leading, spacing: 8) {
                    Text("generator.style_label").font(.subheadline.weight(.semibold))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(StyleCatalog.shared.all) { style in
                                StyleChip(
                                    style: style,
                                    isSelected: viewModel.styleId == style.id,
                                    isLocked: false
                                ) {
                                    viewModel.styleId = style.id
                                }
                            }
                        }
                    }
                }

                Button {
                    Task { await viewModel.startArgument(context: context, locale: locale) }
                } label: {
                    HStack {
                        if viewModel.isThinking {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text("argument.start")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.setup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || viewModel.isThinking
                          || !isPro)

                if let error = viewModel.error {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                        Text(error).font(.callout)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.12)))
                }
            }
            .padding()
        }
    }

    private var transcriptView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.turns) { turn in
                        turnBubble(turn)
                            .id(turn.id)
                    }
                    if viewModel.isThinking {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("generator.loading").font(.caption).foregroundStyle(.secondary)
                        }
                        .id("thinking")
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.turns.count) { _, _ in
                withAnimation { proxy.scrollTo(viewModel.turns.last?.id, anchor: .bottom) }
            }
        }
        .safeAreaInset(edge: .top) {
            HStack {
                Text("argument.live")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(Color.orange.opacity(0.18)))
                    .foregroundStyle(.orange)
                Spacer()
                Button {
                    viewModel.endArgument()
                } label: {
                    Label("argument.end", systemImage: "stop.circle")
                        .font(.footnote)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(.bar)
        }
    }

    private func turnBubble(_ turn: ArgumentTurn) -> some View {
        HStack(alignment: .bottom) {
            if turn.role == .user { Spacer(minLength: 40) }
            VStack(alignment: turn.role == .user ? .trailing : .leading, spacing: 3) {
                Text(turn.role == .ai ? "argument.role.them" : "argument.role.you")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(turn.text)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(turn.role == .user
                                  ? Color.orange.opacity(0.18)
                                  : Color.secondary.opacity(0.10))
                    )
                    .foregroundStyle(.primary)
            }
            if turn.role == .ai { Spacer(minLength: 40) }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("argument.input_placeholder", text: $userInput, axis: .vertical)
                .lineLimit(1...4)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.10)))
            Button {
                let text = userInput
                userInput = ""
                Task { await viewModel.userReply(text: text, context: context, locale: locale) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
            }
            .disabled(userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                      || viewModel.isThinking)
        }
        .padding()
        .background(.bar)
    }
}
