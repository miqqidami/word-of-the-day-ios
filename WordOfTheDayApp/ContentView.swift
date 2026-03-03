import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = HomeViewModel(provider: CompositeWordProvider())
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.scenePhase) private var scenePhase

    private var effectiveColorScheme: ColorScheme {
        viewModel.selectedTheme.preferredColorScheme ?? systemColorScheme
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        Picker("Language", selection: $viewModel.selectedLanguage) {
                            ForEach(LanguageOption.allCases) { language in
                                Text(language.displayName).tag(language)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: viewModel.selectedLanguage) { _, newValue in
                            viewModel.onLanguageChanged(newValue)
                        }

                        Picker("Difficulty", selection: $viewModel.selectedDifficulty) {
                            ForEach(LearningDifficulty.allCases) { difficulty in
                                Text(difficulty.displayName).tag(difficulty)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: viewModel.selectedDifficulty) { _, newValue in
                            viewModel.onDifficultyChanged(newValue)
                        }

                        Picker("Theme", selection: $viewModel.selectedTheme) {
                            ForEach(AppTheme.allCases) { theme in
                                Text(theme.displayName).tag(theme)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: viewModel.selectedTheme) { _, newValue in
                            viewModel.onThemeChanged(newValue)
                        }

                        Button {
                            Task {
                                await viewModel.refreshWord(
                                    for: viewModel.selectedLanguage,
                                    difficulty: viewModel.selectedDifficulty
                                )
                            }
                        } label: {
                            if viewModel.isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Get New Word")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isLoading)

                        if let word = viewModel.currentWord {
                            WordCardView(
                                entry: word,
                                isDarkMode: effectiveColorScheme == .dark
                            )

                            if word.language != viewModel.selectedLanguage || word.difficulty != viewModel.selectedDifficulty {
                                Text("Settings changed. Tap Get New Word to apply them now.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } else {
                            Text("Tap Get New Word to fetch your first word.")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 8)
                        }

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Word of the Day")
            .task {
                await viewModel.ensureDailyWord()
            }
            .onChange(of: scenePhase) { _, newValue in
                guard newValue == .active else { return }
                Task {
                    await viewModel.ensureDailyWord()
                }
            }
        }
        .preferredColorScheme(viewModel.selectedTheme.preferredColorScheme)
    }

    private var backgroundGradient: LinearGradient {
        if effectiveColorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.1, blue: 0.12),
                    Color(red: 0.04, green: 0.05, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                Color(red: 0.96, green: 0.97, blue: 0.98),
                Color(red: 0.93, green: 0.95, blue: 0.97)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct WordCardView: View {
    let entry: WordEntry
    let isDarkMode: Bool

    @State private var exampleIndex = 0

    private var examples: [ExampleSentence] {
        if entry.exampleSentences.isEmpty {
            return [
                ExampleSentence(
                    sentence: "No examples available.",
                    englishTranslation: "No examples available."
                )
            ]
        }
        return entry.exampleSentences
    }

    private var currentExample: ExampleSentence {
        examples[min(exampleIndex, max(examples.count - 1, 0))]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(entry.language?.displayName ?? "Language")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(entry.difficulty?.displayName ?? "Difficulty")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(entry.word)
                .font(.system(size: 34, weight: .bold, design: .rounded))

            if let transliteration = entry.transliteration,
               !transliteration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(transliteration)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Meaning")
                    .font(.subheadline.weight(.semibold))
                Text(entry.englishMeaning.cleanedForDisplay)
                    .font(.body)
                    .textSelection(.enabled)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Characteristics")
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 8) {
                    InfoPill(label: "POS", value: entry.characteristics.partOfSpeech)
                    InfoPill(label: "CEFR", value: entry.characteristics.cefrLevel)
                    InfoPill(label: "Register", value: entry.characteristics.register)
                }

                Text(entry.characteristics.usageTip)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Example")
                    .font(.subheadline.weight(.semibold))

                Text(currentExample.sentence.cleanedForDisplay)
                    .font(.body)
                    .textSelection(.enabled)

                Text(currentExample.englishTranslation.cleanedForDisplay)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                HStack {
                    Button("Previous") {
                        exampleIndex = max(exampleIndex - 1, 0)
                    }
                    .disabled(exampleIndex == 0)

                    Spacer()

                    Text("\(min(exampleIndex + 1, examples.count)) / \(examples.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Next") {
                        exampleIndex = min(exampleIndex + 1, examples.count - 1)
                    }
                    .disabled(exampleIndex >= examples.count - 1)
                }
                .buttonStyle(.bordered)
            }

            Text("Updated \(entry.fetchedAt.formatted(.dateTime.hour().minute()))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(cardBorder, lineWidth: 1)
        )
        .onChange(of: entry.fetchedAt) { _, _ in
            exampleIndex = 0
        }
    }

    private var cardFill: Color {
        if isDarkMode {
            return Color(red: 0.12, green: 0.14, blue: 0.16)
        }
        return Color(red: 0.98, green: 0.99, blue: 1.0)
    }

    private var cardBorder: Color {
        if isDarkMode {
            return Color.white.opacity(0.12)
        }
        return Color.black.opacity(0.08)
    }
}

private struct InfoPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
        .clipShape(Capsule())
    }
}

#Preview {
    ContentView()
}

private extension String {
    var cleanedForDisplay: String {
        var output = self
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "+", with: " ")

        output = output.replacingOccurrences(
            of: "%\\s+([0-9A-Fa-f]{2})",
            with: "%$1",
            options: .regularExpression
        )
        output = output.replacingOccurrences(of: "%20", with: " ")

        for _ in 0..<3 {
            if let decoded = output.removingPercentEncoding {
                output = decoded
            }
        }

        output = output.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
