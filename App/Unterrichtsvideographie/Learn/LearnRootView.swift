import SwiftUI
import LearnContent

/// In-app education hub: Methode, Technik, externe Geräte (from pure `LearnCatalog`).
struct LearnRootView: View {
    private let topics = LearnCatalog.allTopics

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Methode, Technik und externe Geräte für Unterrichtsvideographien mit Videographr.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Section("Themen") {
                    ForEach(topics) { topic in
                        NavigationLink(value: topic.id) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(topic.title)
                                    .font(.headline)
                                Text(topic.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .accessibilityIdentifier("learn.topic.\(topic.id)")
                    }
                }
            }
            .navigationTitle("Lernen")
            .fieldInstrumentDaySurface()
            .navigationDestination(for: String.self) { id in
                if let topic = LearnCatalog.topic(id: id) {
                    LearnTopicView(topic: topic)
                } else {
                    Text("Thema nicht gefunden")
                }
            }
        }
    }
}

/// Renders one catalogue topic with optional research footnotes.
struct LearnTopicView: View {
    let topic: LearnTopic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(topic.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("learn.topic.detail")
                ForEach(topic.sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.heading)
                            .font(.title3.weight(.semibold))
                        markdownText(section.body)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                        if let note = section.researchNote {
                            Text(note)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
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
