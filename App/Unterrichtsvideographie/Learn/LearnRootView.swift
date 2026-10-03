import LearnContent
import SwiftUI

/// In-app education hub: Methode, Technik, externe Geräte (from pure `LearnCatalog`).
struct LearnRootView: View {
    private let topics = LearnCatalog.allTopics

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProvenanceBar(
                    role: .day,
                    segments: ["Evidence-safe", "Referenzkatalog", "Nur lokal"],
                    trailing: BuildIdentity.current.displayVersion
                )
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                    FieldViewHeader(
                        eyebrow: "04 · Referenzkatalog",
                        title: "Lernen",
                        summary: "Methode, Technik und externe Geräte für Unterrichtsvideographien."
                    ) {
                        Label("Lokal verfügbar", systemImage: "books.vertical")
                            .font(.caption)
                            .foregroundStyle(NativeTheme.dayInkTertiary)
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(topics.enumerated()), id: \.element.id) { index, topic in
                            NavigationLink(value: topic.id) {
                                HStack(alignment: .top, spacing: 16) {
                                    Text(String(format: "%02d", index + 1))
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(NativeTheme.accent)
                                        .frame(width: 28, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(topic.title)
                                            .font(.headline)
                                            .foregroundStyle(NativeTheme.dayInk)
                                        Text(topic.subtitle)
                                            .font(.subheadline)
                                            .foregroundStyle(NativeTheme.dayInkTertiary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: 8)
                                    Image(systemName: "arrow.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(NativeTheme.dayInkTertiary)
                                        .accessibilityHidden(true)
                                }
                                .padding(.vertical, 18)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("learn.topic.\(topic.id)")
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(NativeTheme.dayHairline).frame(height: 1)
                            }
                        }
                    }
                    .overlay(alignment: .top) {
                        Rectangle().fill(NativeTheme.dayHairlineStrong).frame(height: 1)
                    }
                }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
                    .frame(maxWidth: 760, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .navigationTitle("Lernen")
            .navigationBarTitleDisplayMode(.inline)
            .fieldInstrumentDaySurface()
            .navigationDestination(for: String.self) { id in
                if let topic = LearnCatalog.topic(id: id) {
                    LearnTopicView(topic: topic)
                } else {
                    ContentUnavailableView("Thema nicht gefunden", systemImage: "book.closed")
                }
            }
        }
    }
}

/// Renders one catalogue topic with optional research footnotes.
struct LearnTopicView: View {
    let topic: LearnTopic

    var body: some View {
        VStack(spacing: 0) {
            ProvenanceBar(
                role: .day,
                segments: ["Evidence-safe", "Referenzkatalog", "Nur lokal"],
                trailing: BuildIdentity.current.displayVersion
            )
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                FieldViewHeader(
                    eyebrow: "04 · Referenz",
                    title: topic.title,
                    summary: topic.subtitle
                ) {
                    EmptyView()
                }
                ForEach(topic.sections) { section in
                    FieldPanel {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(section.heading)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(NativeTheme.dayInk)
                            markdownText(section.body)
                                .font(.body)
                                .foregroundStyle(NativeTheme.dayInkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            if let note = section.researchNote {
                                VStack(alignment: .leading, spacing: 4) {
                                    Label("Forschungsnotiz", systemImage: "info.circle")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(NativeTheme.dayInkSecondary)
                                    Text(note)
                                        .font(.footnote)
                                        .foregroundStyle(NativeTheme.dayInkSecondary)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                }
            }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
        .fieldInstrumentDaySurface()
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
