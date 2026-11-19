import Foundation

// MARK: - Segment models

struct SpeechChunk: Identifiable, Equatable {
    let id: Int
    let text: String
    let range: NSRange
    let sentenceIndex: Int
    let isSentenceStart: Bool
}

struct ReaderSentence: Identifiable, Equatable {
    let id: Int
    let text: String
    let range: NSRange
}

struct SegmentedText {
    var chunks: [SpeechChunk]
    var sentences: [ReaderSentence]

    static let empty = SegmentedText(chunks: [], sentences: [])

    /// 点击正文的字符位置 → 句子序号。
    func sentenceIndex(atCharacterOffset offset: Int) -> Int? {
        guard !sentences.isEmpty else { return nil }
        if let match = sentences.first(where: { NSLocationInRange(offset, $0.range) }) {
            return match.id
        }
        // 点在句间空白时，落到最近的一句。
        return sentences.min(by: {
            distance(from: offset, to: $0.range) < distance(from: offset, to: $1.range)
        })?.id
    }

    func chunkIndex(forSentence index: Int) -> Int? {
        chunks.firstIndex { $0.sentenceIndex == index && $0.isSentenceStart }
            ?? chunks.firstIndex { $0.sentenceIndex == index }
    }

    private func distance(from offset: Int, to range: NSRange) -> Int {
        if offset < range.location { return range.location - offset }
        if offset > NSMaxRange(range) { return offset - NSMaxRange(range) }
        return 0
    }
}

// MARK: - Segmenter

/// 把正文切成「句子 → 朗读片段」。
///
/// 句子用于高亮、书签和进度；朗读片段会在逗号、顿号等位置再切一刀，
/// 让较长的句子有自然的换气和停顿，而不是一口气读完。
enum TextSegmenter {
    private static let hardTerminators: Set<Character> = [
        "。", "！", "？", "!", "?", "；", ";", "…"
    ]

    private static let softTerminators: Set<Character> = [
        "，", ",", "、", "：", ":"
    ]

    private static let closingCharacters: Set<Character> = [
        "”", "’", "」", "』", "）", "】", "》", "〉", "〕", "］", "｝", "\""
    ]

    private static let whitespace: Set<Character> = [
        " ", "\t", "\n", "\r", "\u{3000}"
    ]

    private static let minClauseLength = 14
    private static let maxChunkLength = 64
    private static let preferredSplitBacktrack = 24

    static func segment(_ text: String) -> SegmentedText {
        let chars = Array(text)
        guard !chars.isEmpty else { return .empty }

        // 先把每个 Character 的 UTF-16 偏移算好，NSRange 可以直接用于高亮和书签。
        var offsets = [Int](repeating: 0, count: chars.count + 1)
        for index in chars.indices {
            offsets[index + 1] = offsets[index] + String(chars[index]).utf16.count
        }

        var chunks: [SpeechChunk] = []
        var sentences: [ReaderSentence] = []
        var sentenceIndex = 0
        var clauseStart = 0
        var sentenceStart: Int?
        var sentenceEnd = 0

        func trimmedBounds(_ start: Int, _ end: Int) -> (Int, Int)? {
            var lower = start
            var upper = end
            while lower < upper, whitespace.contains(chars[lower]) { lower += 1 }
            while upper > lower, whitespace.contains(chars[upper - 1]) { upper -= 1 }
            guard lower < upper else { return nil }
            return (lower, upper)
        }

        func isSpeakable(_ value: String) -> Bool {
            value.unicodeScalars.contains { scalar in
                CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar)
            }
        }

        func appendClause(start: Int, end: Int) {
            guard let (lower, upper) = trimmedBounds(start, end) else { return }
            let value = String(chars[lower..<upper])
            guard isSpeakable(value) else { return }

            let isStart = sentenceStart == nil
            if isStart { sentenceStart = lower }
            sentenceEnd = upper

            chunks.append(
                SpeechChunk(
                    id: chunks.count,
                    text: value,
                    range: NSRange(location: offsets[lower], length: offsets[upper] - offsets[lower]),
                    sentenceIndex: sentenceIndex,
                    isSentenceStart: isStart
                )
            )
        }

        func finishSentence() {
            guard let start = sentenceStart, sentenceEnd > start else { return }
            let range = NSRange(
                location: offsets[start],
                length: offsets[sentenceEnd] - offsets[start]
            )
            let value = String(chars[start..<sentenceEnd])
            guard !value.isEmpty else { return }
            sentences.append(ReaderSentence(id: sentenceIndex, text: value, range: range))
            sentenceIndex += 1
            sentenceStart = nil
            sentenceEnd = 0
        }

        var cursor = 0
        while cursor < chars.count {
            let char = chars[cursor]

            // 句末标点：收尾，并把紧跟的引号、括号一起算进这句话。
            if hardTerminators.contains(char) {
                var end = cursor + 1
                while end < chars.count,
                      hardTerminators.contains(chars[end]) || closingCharacters.contains(chars[end]) {
                    end += 1
                }
                while end < chars.count, closingCharacters.contains(chars[end]) {
                    end += 1
                }
                appendClause(start: clauseStart, end: end)
                if let mergedEnd = attributionEnd(after: end, chars: chars) {
                    appendClause(start: end, end: mergedEnd)
                    finishSentence()
                    clauseStart = skipWhitespace(chars, from: mergedEnd)
                    cursor = clauseStart
                    continue
                }
                finishSentence()
                clauseStart = skipWhitespace(chars, from: end)
                cursor = clauseStart
                continue
            }

            // 英文句号：避开小数点和连续点号。
            if char == "." {
                let previous = cursor > 0 ? chars[cursor - 1] : nil
                let next = cursor + 1 < chars.count ? chars[cursor + 1] : nil
                let isDecimal = previous?.isNumber == true && next?.isNumber == true
                let isRepeated = next == "."
                let isSentenceEnd = next == nil || whitespace.contains(next!) || next == "”" || next == "\""

                if !isDecimal && (isRepeated || isSentenceEnd) {
                    var end = cursor + 1
                    while end < chars.count, chars[end] == "." { end += 1 }
                    while end < chars.count, closingCharacters.contains(chars[end]) { end += 1 }
                    appendClause(start: clauseStart, end: end)
                    finishSentence()
                    clauseStart = skipWhitespace(chars, from: end)
                    cursor = clauseStart
                    continue
                }
            }

            // 换行：一句话结束。
            if char == "\n" || char == "\r" {
                var end = cursor + 1
                while end < chars.count, chars[end] == "\n" || chars[end] == "\r" { end += 1 }
                appendClause(start: clauseStart, end: cursor)
                finishSentence()
                clauseStart = end
                cursor = end
                continue
            }

            // 逗号、顿号、冒号：句子还没完，但可以换气。
            if softTerminators.contains(char) {
                let length = offsets[cursor + 1] - offsets[clauseStart]
                if length >= minClauseLength {
                    appendClause(start: clauseStart, end: cursor + 1)
                    clauseStart = cursor + 1
                }
                cursor += 1
                continue
            }

            // 破折号也可以作为语气停顿。
            if char == "—" {
                let length = offsets[cursor + 1] - offsets[clauseStart]
                if length >= minClauseLength {
                    var end = cursor + 1
                    while end < chars.count, chars[end] == "—" { end += 1 }
                    appendClause(start: clauseStart, end: end)
                    clauseStart = end
                    cursor = end
                    continue
                }
            }

            // 没有标点的超长片段：优先在空格处断开，否则硬切。
            if offsets[cursor + 1] - offsets[clauseStart] >= maxChunkLength {
                var cut = cursor
                var back = cursor
                while back > clauseStart,
                      offsets[cursor + 1] - offsets[back] < preferredSplitBacktrack {
                    if chars[back] == " " {
                        cut = back
                        break
                    }
                    back -= 1
                }
                if cut > clauseStart {
                    appendClause(start: clauseStart, end: cut)
                    clauseStart = cut
                    cursor = cut
                    continue
                }
            }

            cursor += 1
        }

        appendClause(start: clauseStart, end: chars.count)
        finishSentence()

        return SegmentedText(chunks: chunks, sentences: sentences)
    }

    private static func skipWhitespace(_ chars: [Character], from index: Int) -> Int {
        var cursor = index
        while cursor < chars.count, whitespace.contains(chars[cursor]) { cursor += 1 }
        return cursor
    }

    /// 把引号后的短旁白并入同一句，例如：「你好。」他说。
    /// 这样高亮、书签和进度都以一个完整的“对白 + 说话人”为单位。
    private static func attributionEnd(after index: Int, chars: [Character]) -> Int? {
        guard index > 0, index <= chars.count else { return nil }
        let quoteClosers: Set<Character> = ["”", "\"", "』", "」"]
        guard quoteClosers.contains(chars[index - 1]) else { return nil }

        var start = index
        while start < chars.count,
              chars[start] == " " || chars[start] == "\t" || chars[start] == "\u{3000}" {
            start += 1
        }
        guard start < chars.count else { return nil }
        guard chars[start] != "\n", chars[start] != "\r" else { return nil }
        guard chars[start] != "“", chars[start] != "\"" else { return nil }
        guard !closingCharacters.contains(chars[start]) else { return nil }

        var cursor = start
        var length = 0
        while cursor < chars.count {
            let char = chars[cursor]
            if char == "\n" || char == "\r" { return nil }
            if hardTerminators.contains(char) {
                // 旁白通常以句号收尾；问号/感叹号更像下一句独立的话。
                guard char == "。" || char == "；" || char == ";" else { return nil }
                var end = cursor + 1
                while end < chars.count,
                      hardTerminators.contains(chars[end]) || closingCharacters.contains(chars[end]) {
                    end += 1
                }
                let candidate = String(chars[start..<end])
                guard candidate.count <= 6 else { return nil }
                guard !candidate.contains("“"), !candidate.contains("\"") else { return nil }
                return end
            }
            length += 1
            if length > 7 { return nil }
            cursor += 1
        }
        return nil
    }
}
