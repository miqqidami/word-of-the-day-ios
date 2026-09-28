import AVFoundation
import SwiftUI

struct WordDetailView: View {
    let word: Word
    let subtitle: String?

    @StateObject private var speaker = Speaker()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                tipCard
                examples
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(subtitle ?? word.word)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Pill(text: word.partOfSpeech.capitalized)
                Pill(text: word.level)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(word.word)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
                    .textSelection(.enabled)
                Spacer()
                SpeakButton { speaker.speak(word.word) }
            }

            Text(word.meaning)
                .font(.title3)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    private var tipCard: some View {
        Label {
            Text(word.tip)
                .font(.callout)
                .textSelection(.enabled)
        } icon: {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var examples: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Example sentences")
                .font(.headline)

            ForEach(word.examples, id: \.self) { example in
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(example.tr)
                            .font(.body.weight(.medium))
                        Text(example.en)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    SpeakButton { speaker.speak(example.tr) }
                }
                .padding()
                .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }
}

private struct Pill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.red.opacity(0.12), in: Capsule())
            .foregroundStyle(.red)
    }
}

private struct SpeakButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "speaker.wave.2.fill")
                .foregroundStyle(.red)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Pronounce")
    }
}

/// Reads Turkish text aloud with the system tr-TR voice.
@MainActor
private final class Speaker: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "tr-TR")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        synthesizer.speak(utterance)
    }
}
