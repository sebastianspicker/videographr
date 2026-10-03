import LearnContent
import SwiftUI

/// In-app education hub: Methode, Technik, externe Geräte (from pure `LearnCatalog`).
struct LearnRootView: View {
    private let topics = LearnCatalog.allTopics
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    DocumentHeader(
                        eyebrow: "04 · Referenz",
                        title: "Referenzkatalog",
                        summary: "Methode, Technik und externe Geräte für Unterrichtsvideographie. Lokal verfügbar, ohne Netz."
                    )

                    VStack(spacing: 0) {
                        Rule(strong: true)
                        ForEach(Array(topics.enumerated()), id: \.element.id) { index, topic in
                            NavigationLink(value: topic.id) {
                                HStack(alignment: .firstTextBaseline, spacing: 0) {
                                    MarginMark(text: String(format: "%02d", index + 1))
                                        .frame(width: 44, alignment: .leading)
                                    VStack(alignment: .leading, spacing: Space.xs) {
                                        Text(topic.title)
                                            .font(Typeface.section)
                                            .foregroundStyle(Ink.primary)
                                            .multilineTextAlignment(.leading)
                                        Text(topic.subtitle)
                                            .font(Typeface.proseSmall)
                                            .foregroundStyle(Ink.secondary)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: Space.s)
                                    Image(systemName: "arrow.right")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(Ink.tertiary)
                                        .accessibilityHidden(true)
                                }
                                .padding(.vertical, Space.l)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("learn.topic.\(topic.id)")
                            Rule()
                        }
                    }
                }
                .padding(.horizontal, sizeClass == .regular ? Space.gutterRegular : Space.gutterCompact)
                .padding(.top, Space.xl)
                .padding(.bottom, Space.xxxl)
                .frame(maxWidth: Space.measure, alignment: .leading)
                .frame(maxWidth: Space.pageMaximum, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Lernen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .paperSurface()
            .navigationDestination(for: String.self) { id in
                if let topic = LearnCatalog.topic(id: id) {
                    LearnTopicView(topic: topic)
                } else {
                    ContentUnavailableView {
                        Label {
                            Text("Thema nicht gefunden").font(Typeface.heading)
                        } icon: {
                            Image(systemName: "book.closed")
                        }
                    }
                    .paperSurface()
                }
            }
        }
    }
}

/// Renders one catalogue topic with optional research footnotes.
struct LearnTopicView: View {
    let topic: LearnTopic
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                DocumentHeader(
                    eyebrow: "Referenz",
                    title: topic.title,
                    summary: topic.subtitle
                )
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(topic.sections.enumerated()), id: \.element.id) { index, section in
                        ProtocolSection("\(index + 1)", section.heading) {
                            VStack(alignment: .leading, spacing: Space.l) {
                                markdownText(section.body)
                                    .font(Typeface.prose)
                                    .foregroundStyle(Ink.primary)
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                                if let note = section.researchNote {
                                    researchNote(note)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, sizeClass == .regular ? Space.gutterRegular : Space.gutterCompact)
            .padding(.top, Space.xl)
            .padding(.bottom, Space.xxxl)
            .frame(maxWidth: Space.measure, alignment: .leading)
            .frame(maxWidth: Space.pageMaximum, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .paperSurface()
    }

    private func researchNote(_ note: String) -> some View {
        HStack(alignment: .top, spacing: Space.m) {
            Rectangle()
                .fill(Ink.ruleStrong)
                .frame(width: 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.xs) {
                FormLabel("Forschungsnotiz")
                Text(note)
                    .font(Typeface.quote)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func markdownText(_ source: String) -> some View {
        if let markdown = try? AttributedString(
            markdown: source,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(markdown)
        } else {
            Text(source)
        }
    }
}

#Preview {
    LearnRootView()
}

#Preview("Lernen · Große Schrift") {
    LearnRootView()
        .environment(\.dynamicTypeSize, .accessibility3)
}
