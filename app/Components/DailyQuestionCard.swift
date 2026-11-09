import SwiftUI
import UIKit

/// The one question shown on the Today feed each day. Answered inline; once
/// answered it reveals the note and offers the entry it was drawn from.
struct DailyQuestionCard: View {
    let question: QuizQuestion
    let answer: DailyAnswer?
    /// The entry behind the question, when it is in the loaded catalog.
    let linkedEvent: HistoricalEvent?
    let onAnswer: (Int) -> Void

    private var revealed: Bool { answer != nil }

    /// Year options are short enough to sit side by side.
    private var usesCompactOptions: Bool {
        question.options.allSatisfy { $0.count <= 6 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Text(question.prompt)
                .font(.system(size: 19, weight: .semibold, design: .serif))
                .foregroundStyle(Color("TextPrimary"))
                .kerning(-0.2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            options

            if let answer {
                result(for: answer)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(surface)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color("AccentWarm").opacity(0.22), lineWidth: 0.6)
        )
        .shadow(color: Color("AccentWarm").opacity(0.10), radius: 14, x: 0, y: 6)
        .animation(.snappy(duration: 0.24), value: answer)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color("AccentWarm"))

            Text("TODAY'S QUESTION")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(Color("TextPrimary"))

            Spacer()

            Text(question.kicker)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(Color("TextTertiary"))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    @ViewBuilder
    private var options: some View {
        if usesCompactOptions {
            HStack(spacing: 8) {
                ForEach(question.options.indices, id: \.self) { index in
                    optionButton(index, compact: true)
                }
            }
        } else {
            VStack(spacing: 8) {
                ForEach(question.options.indices, id: \.self) { index in
                    optionButton(index, compact: false)
                }
            }
        }
    }

    private func optionButton(_ index: Int, compact: Bool) -> some View {
        let isCorrect = index == question.correctIndex
        let isChosen = index == answer?.choice
        let dimmed = revealed && !isCorrect && !isChosen

        return Button {
            guard !revealed else { return }
            UIImpactFeedbackGenerator(style: isCorrect ? .light : .rigid).impactOccurred()
            onAnswer(index)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(question.options[index])
                    .font(.system(size: compact ? 15 : 15.5, weight: revealed && isCorrect ? .semibold : .regular, design: .serif))
                    .foregroundStyle(Color("TextPrimary").opacity(dimmed ? 0.45 : 1))
                    .multilineTextAlignment(compact ? .center : .leading)
                    .fixedSize(horizontal: false, vertical: true)

                if !compact {
                    Spacer(minLength: 0)
                }

                if revealed && isCorrect {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: compact ? 13 : 16))
                        .foregroundStyle(Color("AccentWarm"))
                } else if revealed && isChosen {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: compact ? 13 : 16))
                        .foregroundStyle(Color("TextTertiary"))
                }
            }
            .padding(.horizontal, compact ? 8 : 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: compact ? .center : .leading)
            .background(Color("BackgroundWarm"), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        Color("AccentWarm").opacity(revealed && isCorrect ? 0.85 : 0.18),
                        lineWidth: revealed && isCorrect ? 1.4 : 0.6
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(revealed)
        .accessibilityLabel(optionAccessibilityLabel(index, isCorrect: isCorrect, isChosen: isChosen))
    }

    private func optionAccessibilityLabel(_ index: Int, isCorrect: Bool, isChosen: Bool) -> String {
        let option = question.options[index]
        guard revealed else { return option }
        if isCorrect {
            return isChosen ? "\(option), your answer, correct" : "\(option), the correct answer"
        }
        return isChosen ? "\(option), your answer, not correct" : option
    }

    private func result(for answer: DailyAnswer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(answer.correct ? "Well placed." : "Not this time.")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(answer.correct ? Color("AccentWarm") : Color("TextSecondary"))

            Text(question.note)
                .font(.system(size: 14, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(Color("TextSecondary"))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                if let linkedEvent {
                    NavigationLink(value: linkedEvent) {
                        HStack(spacing: 6) {
                            Text("Read the entry")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(Color("AccentWarm"))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Color("AccentWarm").opacity(0.10), in: Capsule())
                        .overlay(Capsule().stroke(Color("AccentWarm").opacity(0.22), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)

                Text("A new question tomorrow.")
                    .font(.system(size: 12, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Color("TextTertiary"))
            }
        }
    }

    private var surface: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color("CardBackground"))

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color("AccentWarm").opacity(0.12), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

#Preview {
    DailyQuestionCard(
        question: QuizQuestion(
            id: 0,
            kicker: "PLACE THE YEAR",
            prompt: "Alan Turing is born",
            options: ["1898", "1905", "1912", "1921"],
            correctIndex: 2,
            note: "Alan Turing, English mathematician and computer scientist."
        ),
        answer: DailyAnswer(choice: 1, correct: false),
        linkedEvent: nil,
        onAnswer: { _ in }
    )
    .padding()
    .background(Color("BackgroundWarm"))
}
