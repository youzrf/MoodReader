import SwiftUI

struct VoiceSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var player: SpeechPlayer

    @State private var voices: [VoiceOption] = []
    @State private var showAllVoices = false

    private var visibleVoices: [VoiceOption] {
        showAllVoices ? voices : Array(voices.prefix(6))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        voiceSection
                        speedSection
                        emotionSection
                        behaviorSection
                        footnote
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 34)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("朗读设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(Palette.accent)
                }
            }
        }
        .tint(Palette.accent)
        .onAppear {
            if voices.isEmpty {
                voices = VoiceCatalog.chineseVoices()
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Voice

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("声音", subtitle: "中文语音")

            VStack(spacing: 0) {
                Button {
                    player.voiceIdentifier = nil
                } label: {
                    voiceRow(
                        name: "自动选择最佳",
                        detail: "优先使用已下载的高级声音",
                        selected: player.voiceIdentifier == nil,
                        badge: nil
                    )
                }
                .buttonStyle(.plain)

                ForEach(visibleVoices) { voice in
                    SoftDivider().padding(.leading, 15)
                    Button {
                        player.voiceIdentifier = voice.id
                    } label: {
                        voiceRow(
                            name: voice.name,
                            detail: "\(voice.languageLabel) · \(voice.language)",
                            selected: player.voiceIdentifier == voice.id,
                            badge: voice.isHighQuality ? voice.qualityLabel : nil
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Palette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Palette.line.opacity(0.7), lineWidth: 0.8)
            )

            if voices.count > 6 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAllVoices.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(showAllVoices ? "收起" : "查看全部 \(voices.count) 个声音")
                        Image(systemName: showAllVoices ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .font(AppFont.rounded(11, weight: .medium))
                    .foregroundStyle(Palette.accent)
                }
            }

            if voices.isEmpty {
                Text("当前设备还没有可用的中文语音。可以在系统设置中下载中文声音后再回来。")
                    .font(AppFont.rounded(11))
                    .foregroundStyle(Palette.inkSoft)
            }
        }
    }

    private func voiceRow(name: String, detail: String, selected: Bool, badge: String?) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(AppFont.rounded(14, weight: selected ? .semibold : .regular))
                        .foregroundStyle(Palette.ink)
                    if let badge {
                        CapsuleTag(text: badge, tint: Palette.sage)
                    }
                }
                Text(detail)
                    .font(AppFont.rounded(10))
                    .foregroundStyle(Palette.inkFaint)
            }
            Spacer()
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 17))
                .foregroundStyle(selected ? Palette.accent : Palette.line)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - Speed

    private var speedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                sectionTitle("语速", subtitle: nil)
                Spacer()
                Text(player.speedLabel)
                    .font(AppFont.rounded(13, weight: .semibold))
                    .foregroundStyle(Palette.accent)
            }

            VStack(spacing: 8) {
                Slider(value: $player.speed, in: 0.7...1.4, step: 0.05)
                    .tint(Palette.accent)
                HStack {
                    Text("慢一点")
                    Spacer()
                    Text("快一点")
                }
                .font(AppFont.rounded(10))
                .foregroundStyle(Palette.inkFaint)
            }
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Palette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Palette.line.opacity(0.7), lineWidth: 0.8)
            )
        }
    }

    // MARK: - Emotion

    private var emotionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("语气", subtitle: "整篇基调")

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ],
                spacing: 8
            ) {
                ForEach(Emotion.allCases) { emotion in
                    emotionChip(emotion)
                }
            }

            Text(emotionDescription)
                .font(AppFont.rounded(11))
                .foregroundStyle(Palette.inkSoft)
                .lineSpacing(3)
                .padding(.horizontal, 2)
        }
    }

    private func emotionChip(_ emotion: Emotion) -> some View {
        let selected = player.emotionMode == emotion
        return Button {
            player.emotionMode = emotion
        } label: {
            VStack(spacing: 5) {
                Image(systemName: emotion.symbol)
                    .font(.system(size: 15, weight: .medium))
                Text(emotion.title)
                    .font(AppFont.rounded(11, weight: selected ? .semibold : .regular))
            }
            .foregroundStyle(selected ? emotion.tint : Palette.inkSoft)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(selected ? emotion.tint.opacity(0.12) : Palette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(selected ? emotion.tint.opacity(0.55) : Palette.line.opacity(0.7), lineWidth: 0.8)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var emotionDescription: String {
        switch player.emotionMode {
        case .auto:
            return "最推荐。根据标点、关键词和句子长短，为每一句单独选择语气：疑问句会更轻，感叹句会更有起伏，长句会放慢。"
        default:
            return "整篇统一使用「\(player.emotionMode.title)」语气。适合诗歌、独白，或你想让整篇文章保持同一种情绪的时候。"
        }
    }

    // MARK: - Behavior

    private var behaviorSection: some View {
        Toggle(isOn: $player.autoScroll) {
            VStack(alignment: .leading, spacing: 3) {
                Text("自动滚动")
                    .font(AppFont.rounded(14, weight: .medium))
                    .foregroundStyle(Palette.ink)
                Text("朗读到下一句时，把当前句带到视野里")
                    .font(AppFont.rounded(10))
                    .foregroundStyle(Palette.inkFaint)
            }
        }
        .tint(Palette.accent)
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Palette.line.opacity(0.7), lineWidth: 0.8)
        )
    }

    private var footnote: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "info.circle")
                .font(.system(size: 10))
            Text("离线朗读使用系统语音，不耗流量。想要更自然的声音，可以在 iOS「设置 > 辅助功能 > 朗读内容 > 声音」里下载中文的「增强」或「高级」语音。")
                .font(AppFont.rounded(10))
                .lineSpacing(3)
        }
        .foregroundStyle(Palette.inkFaint)
    }

    // MARK: - Header

    private func sectionTitle(_ title: String, subtitle: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(AppFont.serif(17, weight: .semibold))
                .foregroundStyle(Palette.ink)
            if let subtitle {
                Text(subtitle)
                    .font(AppFont.rounded(10))
                    .foregroundStyle(Palette.inkFaint)
            }
        }
    }
}
