import SwiftUI

struct ReaderView: View {
    @EnvironmentObject private var store: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var player = SpeechPlayer()
    @State private var book: Book
    @State private var segmented: SegmentedText = .empty
    @State private var scrollTrigger = 0
    @State private var showBookmarks = false
    @State private var showSettings = false
    @State private var toastMessage: String?
    @State private var didPrepare = false

    init(book: Book) {
        _book = State(initialValue: book)
    }

    var body: some View {
        ZStack {
            PaperBackground()

            VStack(spacing: 0) {
                header
                progressLine
                reader
                PlayerBar(
                    player: player,
                    isBookmarked: isBookmarked,
                    onToggle: { player.toggle() },
                    onPrevious: {
                        player.previousSentence()
                        scrollTrigger += 1
                    },
                    onNext: {
                        player.nextSentence()
                        scrollTrigger += 1
                    },
                    onBookmark: toggleBookmark,
                    onSettings: { showSettings = true }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toast($toastMessage)
        .onAppear(perform: prepare)
        .onDisappear(perform: teardown)
        .onChange(of: player.sentenceIndex) { _, _ in
            if player.autoScroll {
                scrollTrigger += 1
            }
        }
        .sheet(isPresented: $showBookmarks) {
            BookmarksSheet(player: player, bookID: book.id) { index in
                player.seek(toSentence: index)
                scrollTrigger += 1
            }
            .environmentObject(store)
        }
        .sheet(isPresented: $showSettings) {
            VoiceSettingsSheet(player: player)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(Palette.card.opacity(0.78))
                    )
                    .overlay(
                        Circle().stroke(Palette.line.opacity(0.7), lineWidth: 0.8)
                    )
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("返回书架")

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(AppFont.serif(17, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    if !book.author.isEmpty {
                        Text(book.author)
                        Text("·")
                    }
                    Text("\(max(1, player.sentenceIndex + 1)) / \(max(1, player.sentenceCount)) 句")
                }
                .font(AppFont.rounded(10))
                .foregroundStyle(Palette.inkFaint)
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button {
                toggleBookmark()
            } label: {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isBookmarked ? Palette.accent : Palette.inkSoft)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(isBookmarked ? Palette.accent.opacity(0.12) : Palette.card.opacity(0.78))
                    )
                    .overlay(
                        Circle().stroke(Palette.line.opacity(0.7), lineWidth: 0.8)
                    )
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel(isBookmarked ? "移除书签" : "添加书签")

            Menu {
                Button {
                    showBookmarks = true
                } label: {
                    Label("书签（\(bookmarkCount)）", systemImage: "bookmark")
                }
                Button {
                    showSettings = true
                } label: {
                    Label("朗读设置", systemImage: "slider.horizontal.3")
                }
                Divider()
                Button {
                    player.repeatSentence()
                    scrollTrigger += 1
                } label: {
                    Label("重读这一句", systemImage: "arrow.counterclockwise")
                }
                Button {
                    player.seek(toSentence: 0, autoplay: false)
                    scrollTrigger += 1
                    toastMessage = "已回到开头"
                } label: {
                    Label("回到开头", systemImage: "text.line.first.and.arrowtriangle.forward")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(Palette.card.opacity(0.78))
                    )
                    .overlay(
                        Circle().stroke(Palette.line.opacity(0.7), lineWidth: 0.8)
                    )
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 9)
    }

    private var progressLine: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle().fill(Palette.line.opacity(0.45))
                Rectangle()
                    .fill(Palette.accent.opacity(0.72))
                    .frame(width: geometry.size.width * player.progress)
            }
        }
        .frame(height: 1.5)
    }

    // MARK: - Reader

    @ViewBuilder
    private var reader: some View {
        if segmented.sentences.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Palette.inkFaint)
                Text("这篇文章还没有可朗读的内容")
                    .font(AppFont.serif(16))
                    .foregroundStyle(Palette.inkSoft)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ReaderTextView(
                text: book.content,
                highlightRange: currentSentence?.range,
                scrollTrigger: scrollTrigger
            ) { offset in
                guard let index = segmented.sentenceIndex(atCharacterOffset: offset) else { return }
                player.seek(toSentence: index)
                scrollTrigger += 1
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - State

    private var currentSentence: ReaderSentence? {
        guard segmented.sentences.indices.contains(player.sentenceIndex) else { return nil }
        return segmented.sentences[player.sentenceIndex]
    }

    private var isBookmarked: Bool {
        guard let stored = store.book(id: book.id) else { return false }
        return stored.bookmarks.contains { $0.sentenceIndex == player.sentenceIndex }
    }

    private var bookmarkCount: Int {
        store.book(id: book.id)?.bookmarks.count ?? 0
    }

    // MARK: - Lifecycle

    private func prepare() {
        guard !didPrepare else { return }
        didPrepare = true

        segmented = TextSegmenter.segment(book.content)
        player.load(
            title: book.title,
            author: book.author,
            sentences: segmented.sentences,
            chunks: segmented.chunks,
            startSentenceIndex: book.lastSentenceIndex
        )
        let library = store
        player.onProgress = { sentenceIndex, charOffset, progress in
            library.updateProgress(
                bookID: book.id,
                sentenceIndex: sentenceIndex,
                charOffset: charOffset,
                progress: progress
            )
        }
        player.onFinished = {
            toastMessage = "读完了。喜欢的话，留一枚书签吧。"
        }
        scrollTrigger += 1
    }

    private func teardown() {
        if let sentence = currentSentence {
            store.updateProgress(
                bookID: book.id,
                sentenceIndex: sentence.id,
                charOffset: sentence.range.location,
                progress: player.progress
            )
        }
        player.end()
    }

    private func toggleBookmark() {
        guard let sentence = currentSentence else { return }
        let added = store.toggleBookmark(
            bookID: book.id,
            sentenceIndex: sentence.id,
            charOffset: sentence.range.location,
            snippet: sentence.text
        )
        toastMessage = added ? "已收藏这一句" : "已移除书签"
    }
}

#Preview {
    NavigationStack {
        ReaderView(book: Book.samples()[0])
            .environmentObject(LibraryStore())
    }
}
