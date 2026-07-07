import SwiftUI

/// Feed card announcing the weekend quiz; tapping it presents QuizView.
struct QuizCardView: View {
    let quiz: WeeklyQuiz
    let result: QuizResult?
    let streak: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "puzzlepiece.extension")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color("AccentWarm"))

                Text("WEEKEND QUIZ")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(Color("TextPrimary"))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color("AccentWarm").opacity(0.7))
            }

            Text(bodyText)
                .font(.system(size: 15, weight: .regular, design: .serif))
                .foregroundStyle(Color("TextSecondary"))
                .lineSpacing(4)

            if let streakText {
                Text(streakText)
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Color("TextTertiary"))
            }
        }
        .padding(18)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color("CardBackground"))

                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color("AccentWarm").opacity(0.14),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color("AccentWarm").opacity(0.22), lineWidth: 0.6)
        )
        .shadow(color: Color("AccentWarm").opacity(0.10), radius: 14, x: 0, y: 6)
    }

    private var bodyText: String {
        if let result {
            return "You placed \(result.score) of \(result.total) this week. Tap to replay the questions."
        }
        return "Five questions drawn from the archive. No notes, no pressure."
    }

    private var streakText: String? {
        if result != nil {
            return streak >= 2 ? "\(streak) weeks running." : nil
        }
        if streak >= 1 {
            return "Keep your \(streak)-week streak alive."
        }
        return nil
    }
}

/// The weekly quiz itself, presented as a sheet from the Today feed.
struct QuizView: View {
    @EnvironmentObject var quizStore: QuizStore
    @Environment(\.dismiss) private var dismiss

    let quiz: WeeklyQuiz

    @State private var questionIndex = 0
    @State private var selectedOption: Int?
    @State private var score = 0
    @State private var showsSummary = false

    private var question: QuizQuestion {
        quiz.questions[questionIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 22)

            ScrollView {
                Group {
                    if showsSummary {
                        summary
                    } else {
                        questionPage
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 26)
                .padding(.bottom, 40)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(paperBackground.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(Color("TextTertiary").opacity(0.45))
                    .frame(height: 0.6)

                Text("WEEKEND QUIZ · \(quiz.weekKey)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(Color("AccentWarm"))
                    .fixedSize()

                Rectangle()
                    .fill(Color("TextTertiary").opacity(0.45))
                    .frame(height: 0.6)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color("TextTertiary").opacity(0.7))
                }
                .accessibilityLabel("Close quiz")
            }

            if !showsSummary {
                Text("Question \(questionIndex + 1) of \(quiz.questions.count)")
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundStyle(Color("TextSecondary"))
            }
        }
    }

    private var questionPage: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text(question.kicker)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(Color("AccentWarm"))

                Text(question.prompt)
                    .font(.system(size: 23, weight: .semibold, design: .serif))
                    .foregroundStyle(Color("TextPrimary"))
                    .kerning(-0.3)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                ForEach(question.options.indices, id: \.self) { index in
                    optionButton(index)
                }
            }

            if selectedOption != nil {
                VStack(alignment: .leading, spacing: 18) {
                    Text(question.note)
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(Color("TextSecondary"))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: advance) {
                        Text(questionIndex + 1 < quiz.questions.count ? "Next question" : "See how you did")
                            .font(.system(size: 15, weight: .semibold, design: .serif))
                            .foregroundStyle(Color("CardBackground"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color("AccentWarm"), in: Capsule())
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.snappy(duration: 0.24), value: selectedOption)
        .id(questionIndex)
    }

    private func optionButton(_ index: Int) -> some View {
        let revealed = selectedOption != nil
        let isCorrect = index == question.correctIndex
        let isChosen = index == selectedOption

        return Button {
            answer(index)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(question.options[index])
                    .font(.system(size: 16, weight: revealed && isCorrect ? .semibold : .regular, design: .serif))
                    .foregroundStyle(Color("TextPrimary").opacity(revealed && !isCorrect && !isChosen ? 0.45 : 1))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                if revealed && isCorrect {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color("AccentWarm"))
                } else if revealed && isChosen {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(Color("TextTertiary"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color("CardBackground"), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        revealed && isCorrect
                            ? Color("AccentWarm").opacity(0.85)
                            : Color("AccentWarm").opacity(0.16),
                        lineWidth: revealed && isCorrect ? 1.4 : 0.6
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(revealed)
    }

    private var summary: some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color("AccentWarm").opacity(0.30))
                    .frame(width: 24, height: 0.6)

                Image(systemName: "diamond.fill")
                    .font(.system(size: 4))
                    .foregroundStyle(Color("AccentWarm").opacity(0.55))

                Rectangle()
                    .fill(Color("AccentWarm").opacity(0.30))
                    .frame(width: 24, height: 0.6)
            }

            VStack(spacing: 8) {
                Text("You placed \(score) of \(quiz.questions.count)")
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .foregroundStyle(Color("TextPrimary"))
                    .kerning(-0.4)

                Text(scoreLine)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Color("TextSecondary"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            if let streakLine {
                Text(streakLine)
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundStyle(Color("AccentWarm"))
            }

            Button {
                dismiss()
            } label: {
                Text("Back to today")
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundStyle(Color("CardBackground"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color("AccentWarm"), in: Capsule())
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
        .background(Color("CardBackground"), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color("AccentWarm").opacity(0.16), lineWidth: 0.6)
        )
        .onAppear {
            quizStore.recordResult(weekKey: quiz.weekKey, score: score, total: quiz.questions.count)
        }
    }

    private var scoreLine: String {
        switch score {
        case quiz.questions.count:
            return "A perfect edition. The archivists tip their hats."
        case quiz.questions.count - 1:
            return "Sharp eyes. Hardly anything slips past you."
        case quiz.questions.count - 2:
            return "A respectable read of the record."
        default:
            return "The archive won this round. There's always next week."
        }
    }

    private var streakLine: String? {
        let streak = quizStore.streak(asOf: Date())
        guard streak >= 1 else { return nil }
        return streak == 1 ? "One week in the books." : "\(streak) weeks running."
    }

    private func answer(_ index: Int) {
        guard selectedOption == nil else { return }
        selectedOption = index
        if index == question.correctIndex {
            score += 1
        }
        let haptic = UIImpactFeedbackGenerator(style: index == question.correctIndex ? .light : .rigid)
        haptic.impactOccurred()
    }

    private func advance() {
        if questionIndex + 1 < quiz.questions.count {
            questionIndex += 1
            selectedOption = nil
        } else {
            showsSummary = true
        }
    }

    private var paperBackground: some View {
        ZStack {
            Color("BackgroundWarm")

            LinearGradient(
                colors: [
                    Color("AccentWarm").opacity(0.06),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
        }
    }
}

#Preview {
    QuizView(
        quiz: WeeklyQuiz(
            weekKey: "2026-W28",
            questions: [
                QuizQuestion(
                    id: 0,
                    kicker: "PLACE THE YEAR",
                    prompt: "Alan Turing is born",
                    options: ["1898", "1905", "1912", "1921"],
                    correctIndex: 2,
                    note: "Alan Turing, English mathematician and computer scientist."
                )
            ]
        )
    )
    .environmentObject(QuizStore())
}
