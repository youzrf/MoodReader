import SwiftUI

// MARK: - Emotion

enum Emotion: String, CaseIterable, Codable, Identifiable, Equatable {
    case auto
    case calm
    case warm
    case cheerful
    case sad
    case serious
    case excited
    case curious
    case whisper

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "智能"
        case .calm: return "平静"
        case .warm: return "温柔"
        case .cheerful: return "轻快"
        case .sad: return "感伤"
        case .serious: return "郑重"
        case .excited: return "激动"
        case .curious: return "好奇"
        case .whisper: return "低语"
        }
    }

    var symbol: String {
        switch self {
        case .auto: return "sparkles"
        case .calm: return "water.waves"
        case .warm: return "heart"
        case .cheerful: return "sun.max"
        case .sad: return "cloud.rain"
        case .serious: return "book.closed"
        case .excited: return "bolt"
        case .curious: return "questionmark.circle"
        case .whisper: return "moon.stars"
        }
    }

    var tint: Color {
        switch self {
        case .auto: return Palette.sage
        case .calm: return Color(hex: 0x6F8A8A)
        case .warm: return Color(hex: 0xC07A5A)
        case .cheerful: return Palette.gold
        case .sad: return Color(hex: 0x6F7E9A)
        case .serious: return Color(hex: 0x7A6A58)
        case .excited: return Palette.accent
        case .curious: return Color(hex: 0x7A8A5C)
        case .whisper: return Color(hex: 0x8B7E94)
        }
    }

    /// 相对基础语速的倍率。
    var rateFactor: Double {
        switch self {
        case .auto, .calm: return 0.94
        case .warm: return 0.90
        case .cheerful: return 1.06
        case .sad: return 0.82
        case .serious: return 0.90
        case .excited: return 1.12
        case .curious: return 0.98
        case .whisper: return 0.76
        }
    }

    var pitch: Double {
        switch self {
        case .auto, .calm: return 1.0
        case .warm: return 0.97
        case .cheerful: return 1.10
        case .sad: return 0.90
        case .serious: return 0.94
        case .excited: return 1.15
        case .curious: return 1.06
        case .whisper: return 0.93
        }
    }

    var volume: Double {
        switch self {
        case .auto, .calm: return 0.95
        case .warm: return 0.95
        case .cheerful: return 1.0
        case .sad: return 0.88
        case .serious: return 1.0
        case .excited: return 1.0
        case .curious: return 0.95
        case .whisper: return 0.58
        }
    }

    var postDelay: TimeInterval {
        switch self {
        case .auto, .calm: return 0.16
        case .warm: return 0.20
        case .cheerful: return 0.10
        case .sad: return 0.30
        case .serious: return 0.22
        case .excited: return 0.08
        case .curious: return 0.14
        case .whisper: return 0.34
        }
    }

    /// 可选情绪，不包含 auto。
    static var selectable: [Emotion] {
        allCases.filter { $0 != .auto }
    }
}

// MARK: - Emotion director

enum EmotionDirector {
    private static let sadWords = [
        "哭", "泪", "孤独", "离开", "告别", "错过", "遗憾", "想念", "沉默",
        "雨", "夜", "冷", "疼", "死", "失去", "回不去", "很久", "再见", "晚安"
    ]

    private static let happyWords = [
        "笑", "喜欢", "爱", "暖", "光", "花", "春天", "甜", "幸福", "开心",
        "温柔", "亮", "希望", "拥", "阳光", "热", "棒", "精彩", "厉害"
    ]

    private static let strongWords = [
        "一定", "必须", "终于", "竟然", "再也", "永远", "绝不", "居然", "突然"
    ]

    /// 把“智能”解析成一句具体情绪；手动选择的情绪直接返回。
    static func resolve(_ base: Emotion, for text: String) -> Emotion {
        guard base == .auto else { return base }

        let sentence = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sentence.isEmpty else { return .calm }

        let hasSad = contains(sentence, any: sadWords)
        let hasHappy = contains(sentence, any: happyWords)
        let hasStrong = contains(sentence, any: strongWords)
        let hasExclamation = sentence.contains("！") || sentence.contains("!")
        let hasQuestion = sentence.contains("？") || sentence.contains("?")
        let hasEllipsis = sentence.contains("……") || sentence.contains("...")
        let isDialogue = sentence.contains("“") || sentence.contains("”") || sentence.contains("\"")

        if hasQuestion {
            return hasSad ? .sad : .curious
        }
        if hasExclamation {
            if hasSad { return .sad }
            if hasStrong || hasHappy { return .excited }
            return .cheerful
        }
        if hasEllipsis {
            return .warm
        }
        if hasSad {
            return .sad
        }
        if hasHappy {
            return .cheerful
        }
        if isDialogue {
            return .warm
        }
        if hasStrong {
            return .serious
        }
        if sentence.count <= 8 {
            return .calm
        }
        // 用字符和做一个稳定的轻微变化，避免整篇听起来像同一条直线。
        let scalarSum = sentence.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return scalarSum % 3 == 0 ? .warm : .calm
    }

    private static func contains(_ text: String, any words: [String]) -> Bool {
        words.contains { text.contains($0) }
    }
}
