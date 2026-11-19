import SwiftUI
import UIKit

/// 原生 UITextView 承载长文：比 SwiftUI Text 更适合大段文字、精确字符定位和滚动高亮。
struct ReaderTextView: UIViewRepresentable {
    let text: String
    let highlightRange: NSRange?
    let scrollTrigger: Int
    let onTap: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = false
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 6, left: 24, bottom: 28, right: 24)
        textView.textContainer.lineFragmentPadding = 0
        textView.showsVerticalScrollIndicator = false
        textView.alwaysBounceVertical = true
        textView.contentInsetAdjustmentBehavior = .never
        textView.keyboardDismissMode = .onDrag

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tap.delegate = context.coordinator
        tap.cancelsTouchesInView = false
        textView.addGestureRecognizer(tap)
        context.coordinator.textView = textView
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.onTap = onTap

        if context.coordinator.loadedText != text {
            context.coordinator.loadedText = text
            context.coordinator.lastHighlight = highlightRange
            context.coordinator.lastScrollTrigger = scrollTrigger
            textView.attributedText = Self.makeAttributedString(text: text, highlight: highlightRange)
            textView.setContentOffset(.zero, animated: false)
            DispatchQueue.main.async {
                Self.scrollToHighlight(textView, range: highlightRange, animated: false)
            }
            return
        }

        if context.coordinator.lastHighlight != highlightRange {
            let mutable = NSMutableAttributedString(attributedString: textView.attributedText)
            if let old = context.coordinator.lastHighlight,
               old.location != NSNotFound,
               NSMaxRange(old) <= mutable.length {
                mutable.removeAttribute(.backgroundColor, range: old)
            }
            if let new = highlightRange,
               new.location != NSNotFound,
               new.length > 0,
               NSMaxRange(new) <= mutable.length {
                mutable.addAttribute(
                    .backgroundColor,
                    value: UIColor(hex: 0xF1D9A7, alpha: 0.78),
                    range: new
                )
            }
            let offset = textView.contentOffset
            textView.attributedText = mutable
            textView.contentOffset = offset
            context.coordinator.lastHighlight = highlightRange
        }

        if context.coordinator.lastScrollTrigger != scrollTrigger {
            context.coordinator.lastScrollTrigger = scrollTrigger
            Self.scrollToHighlight(textView, range: highlightRange, animated: true)
        }
    }

    // MARK: - Rendering

    private static func makeAttributedString(text: String, highlight: NSRange?) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 10
        paragraph.paragraphSpacing = 18
        paragraph.alignment = .natural

        let base: [NSAttributedString.Key: Any] = [
            .font: UIFont.readerFont(size: 19),
            .foregroundColor: UIColor(hex: 0x2B2722),
            .paragraphStyle: paragraph,
            .kern: 0.32
        ]

        let result = NSMutableAttributedString(string: text, attributes: base)
        if let highlight,
           highlight.location != NSNotFound,
           highlight.length > 0,
           NSMaxRange(highlight) <= result.length {
            result.addAttribute(
                .backgroundColor,
                value: UIColor(hex: 0xF1D9A7, alpha: 0.78),
                range: highlight
            )
        }
        return result
    }

    private static func scrollToHighlight(_ textView: UITextView, range: NSRange?, animated: Bool) {
        guard let range,
              range.location != NSNotFound,
              range.length > 0,
              range.location < textView.attributedText.length else { return }

        textView.scrollRangeToVisible(range)

        guard let start = textView.position(from: textView.beginningOfDocument, offset: range.location) else {
            return
        }
        let caret = textView.caretRect(for: start)
        let maxOffset = max(
            0,
            textView.contentSize.height + textView.textContainerInset.bottom - textView.bounds.height
        )
        let target = min(max(0, caret.minY - textView.bounds.height * 0.26), maxOffset)
        textView.setContentOffset(CGPoint(x: 0, y: target), animated: animated)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onTap: (Int) -> Void
        weak var textView: UITextView?
        var loadedText: String?
        var lastHighlight: NSRange?
        var lastScrollTrigger: Int = -1

        init(onTap: @escaping (Int) -> Void) {
            self.onTap = onTap
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let textView else { return }
            let point = gesture.location(in: textView)

            let contentBottom = textView.contentSize.height + textView.textContainerInset.bottom
            guard point.y >= 0, point.y <= contentBottom else { return }

            if let textRange = textView.characterRange(at: point) {
                let offset = textView.offset(from: textView.beginningOfDocument, to: textRange.start)
                guard offset >= 0 else { return }
                onTap(offset)
                return
            }

            guard let position = textView.closestPosition(to: point) else { return }
            let offset = textView.offset(from: textView.beginningOfDocument, to: position)
            guard offset >= 0 else { return }
            onTap(offset)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
