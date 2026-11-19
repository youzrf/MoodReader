import SwiftUI

struct PlayerBar: View {
    @ObservedObject var player: SpeechPlayer
    let isBookmarked: Bool
    let onToggle: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onBookmark: () -> Void
    let onSettings: () -> Void

    private let speedOptions: [Double] = [0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4]

    var body: some View {
        VStack(spacing: 12) {
            progressLine
            topRow
            controls
        }
        .padding(.horizontal, 16)
        .padding(.top, 13)
        .padding(.bottom, 14)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.45), lineWidth: 0.8)
        )
        .shadow(color: Palette.ink.opacity(0.10), radius: 24, y: 12)
    }

    // MARK: - Progress

    private var progressLine: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.line.opacity(0.55))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Palette.accent.opacity(0.65), Palette.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(3, geometry.size.width * player.progress))
            }
        }
        .frame(height: 2.5)
        .padding(.horizontal, 2)
    }

    // MARK: - Top

    private var topRow: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    CapsuleTag(
                        text: player.currentEmotion.title,
                        tint: player.currentEmotion.tint
                    )
                    Text(sentenceCounter)
                        .font(AppFont.rounded(10))
                        .foregroundStyle(Palette.inkFaint)
                }

                Text(player.currentSentence?.text ?? "轻点正文中的任意一句，从这里开始听。")
                    .font(AppFont.serif(14))
                    .foregroundStyle(Palette.ink.opacity(0.92))
                    .lineSpacing(3)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.easeInOut(duration: 0.2), value: player.sentenceIndex)
            }

            Button(action: onBookmark) {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isBookmarked ? Palette.accent : Palette.inkSoft)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle().fill(isBookmarked ? Palette.accent.opacity(0.12) : Palette.paperDeep.opacity(0.55))
                    )
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel(isBookmarked ? "移除书签" : "添加书签")
        }
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 0) {
            speedMenu
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 22) {
                Button(action: onPrevious) {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Palette.inkSoft)
                        .frame(width: 38, height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("上一句")

                Button(action: onToggle) {
                    ZStack {
                        Circle()
                            .fill(Palette.ink)
                        Image(systemName: playSymbol)
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .offset(x: playSymbol == "play.fill" ? 1.5 : 0)
                    }
                    .frame(width: 54, height: 54)
                    .shadow(color: Palette.ink.opacity(0.22), radius: 10, y: 5)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(player.state == .playing ? "暂停" : "播放")

                Button(action: onNext) {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Palette.inkSoft)
                        .frame(width: 38, height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("下一句")
            }

            HStack(spacing: 6) {
                Spacer(minLength: 0)
                emotionMenu
                Button(action: onSettings) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.inkSoft)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("朗读设置")
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var speedMenu: some View {
        Menu {
            ForEach(speedOptions, id: \.self) { value in
                Button {
                    player.speed = value
                } label: {
                    if abs(player.speed - value) < 0.001 {
                        Label(speedText(value), systemImage: "checkmark")
                    } else {
                        Text(speedText(value))
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(player.speedLabel)
                    .font(AppFont.rounded(11, weight: .semibold))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundStyle(Palette.inkSoft)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Palette.paperDeep.opacity(0.6))
            )
        }
    }

    private var emotionMenu: some View {
        Menu {
            Button {
                player.emotionMode = .auto
            } label: {
                Label("智能（随文变化）", systemImage: "sparkles")
            }
            Divider()
            ForEach(Emotion.selectable) { emotion in
                Button {
                    player.emotionMode = emotion
                } label: {
                    Label(emotion.title, systemImage: emotion.symbol)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: player.emotionMode.symbol)
                    .font(.system(size: 11, weight: .semibold))
                Text(player.emotionMode == .auto ? "智能" : player.emotionMode.title)
                    .font(AppFont.rounded(11, weight: .medium))
            }
            .foregroundStyle(player.emotionMode.tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(player.emotionMode.tint.opacity(0.10))
            )
        }
    }

    // MARK: - Helpers

    private var playSymbol: String {
        switch player.state {
        case .playing: return "pause.fill"
        case .finished: return "arrow.counterclockwise"
        default: return "play.fill"
        }
    }

    private var sentenceCounter: String {
        guard player.sentenceCount > 0 else { return "" }
        return "第 \(min(player.sentenceIndex + 1, player.sentenceCount)) / \(player.sentenceCount) 句"
    }

    private func speedText(_ value: Double) -> String {
        String(format: "%.1f×", value)
    }
}
