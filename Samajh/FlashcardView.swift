import SwiftUI

// MARK: - Card model

enum FlashCard: Identifiable {
    case word(LyricToken)
    case line(LyricLineModel)

    var id: String {
        switch self {
        case .word(let t): return "w-\(t.surface)"
        case .line(let l): return "l-\(l.lineId)"
        }
    }
}

private func buildDeck(from lesson: LyricLesson) -> [FlashCard] {
    var seenSurfaces = Set<String>()
    var seenLines = Set<String>()
    var cards: [FlashCard] = []

    for section in lesson.sections {
        for line in section.lines {
            if seenLines.insert(line.text.target).inserted {
                cards.append(.line(line))
            }
            for token in line.tokens ?? [] {
                if seenSurfaces.insert(token.surface).inserted {
                    cards.append(.word(token))
                }
            }
        }
    }
    return cards.shuffled()
}

// MARK: - Main view

struct FlashcardView: View {
    let lesson: LyricLesson

    @State private var cards: [FlashCard] = []
    @State private var index = 0
    @State private var lineMode: LineMode = .natural

    enum LineMode: String, CaseIterable {
        case wordByWord = "Word"
        case direct = "Direct"
        case natural = "Natural"
    }

    var body: some View {
        VStack(spacing: 0) {
            if !cards.isEmpty {
                progressBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            }

            TabView(selection: $index) {
                ForEach(Array(cards.enumerated()), id: \.offset) { i, card in
                    CardPage(card: card, lineMode: $lineMode)
                        .tag(i)
                        .padding(.horizontal, 20)
                }
                endScreen
                    .tag(cards.count)
                    .padding(.horizontal, 20)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.25), value: index)
        }
        .navigationTitle("Flashcards")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if cards.isEmpty {
                cards = buildDeck(from: lesson)
            }
        }
    }

    // MARK: Progress bar

    private var progressBar: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.15))
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * CGFloat(min(index, cards.count)) / CGFloat(max(cards.count, 1)))
                        .animation(.easeInOut(duration: 0.3), value: index)
                }
            }
            .frame(height: 4)
            Text("\(min(index, cards.count)) / \(cards.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: End screen

    private var endScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Done!")
                .font(.largeTitle.bold())
            Text("\(cards.count) cards reviewed")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Shuffle & Restart") {
                cards = buildDeck(from: lesson)
                index = 0
                lineMode = .natural
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Individual card page

private struct CardPage: View {
    let card: FlashCard
    @Binding var lineMode: FlashcardView.LineMode

    @State private var isRevealed = false

    var body: some View {
        VStack {
            Spacer()
            cardView
            Spacer()
            if !isRevealed {
                Text("Tap to reveal • swipe to skip")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 16)
            } else {
                Text("Swipe for next card")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 16)
            }
        }
    }

    private var speakText: String {
        switch card {
        case .word(let t): return t.surface
        case .line(let l): return l.text.target
        }
    }

    private var cardView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                cardTypeChip
                Spacer()
                Button {
                    TTSPlayer.shared.speak(speakText)
                } label: {
                    Image(systemName: "speaker.wave.2")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 16)

            cardFront

            if isRevealed {
                Divider().padding(.vertical, 16)
                cardBack
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isRevealed else { return }
            withAnimation(.easeIn(duration: 0.18)) { isRevealed = true }
        }
    }

    private var cardTypeChip: some View {
        let label: String
        switch card { case .word: label = "Word"; case .line: label = "Line" }
        return Text(label.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.gray.opacity(0.12)))
    }

    @ViewBuilder
    private var cardFront: some View {
        switch card {
        case .word(let token):
            VStack(alignment: .leading, spacing: 6) {
                Text(token.surface)
                    .font(.system(size: 36, weight: .semibold))
                Text(token.roman)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        case .line(let line):
            VStack(alignment: .leading, spacing: 6) {
                Text(line.text.target)
                    .font(.title3.weight(.medium))
                Text(line.text.roman)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var cardBack: some View {
        switch card {
        case .word(let token):
            Text(token.gloss)
                .font(.title2)
                .foregroundStyle(.primary)
        case .line(let line):
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    ForEach(FlashcardView.LineMode.allCases, id: \.self) { mode in
                        Button {
                            lineMode = mode
                        } label: {
                            Text(mode.rawValue)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(lineMode == mode
                                              ? Color.accentColor.opacity(0.2)
                                              : Color.gray.opacity(0.12))
                                )
                                .foregroundStyle(lineMode == mode ? Color.accentColor : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                let text: String = {
                    switch lineMode {
                    case .wordByWord: return line.text.wordByWord ?? ""
                    case .direct:     return line.text.direct ?? ""
                    case .natural:    return line.text.natural ?? ""
                    }
                }()

                Text(text.isEmpty ? "—" : text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .id(lineMode)
            }
        }
    }
}
