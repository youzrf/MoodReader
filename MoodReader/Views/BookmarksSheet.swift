import SwiftUI

struct BookmarksSheet: View {
    @EnvironmentObject private var store: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var player: SpeechPlayer
    let bookID: UUID
    let onJump: (Int) -> Void

    @State private var editingBookmark: Bookmark?
    @State private var draftNote = ""
    @State private var showNoteEditor = false

    private var bookmarks: [Bookmark] {
        (store.book(id: bookID)?.bookmarks ?? []).sorted { $0.sentenceIndex < $1.sentenceIndex }
    }

    private var currentIsBookmarked: Bool {
        bookmarks.contains { $0.sentenceIndex == player.sentenceIndex }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        addCard
                        if bookmarks.isEmpty {
                            emptyState
                        } else {
                            bookmarkList
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("书签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(Palette.accent)
                }
            }
            .alert("书签备注", isPresented: $showNoteEditor) {
                TextField("写点什么…", text: $draftNote)
                Button("保存") {
                    if let bookmark = editingBookmark {
                        store.updateBookmarkNote(
                            bookID: bookID,
                            bookmarkID: bookmark.id,
                            note: draftNote.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    }
                    editingBookmark = nil
                }
                Button("取消", role: .cancel) {
                    editingBookmark = nil
                }
            } message: {
                Text("给这枚书签留一句话，之后回来会更清楚。")
            }
        }
        .tint(Palette.accent)
    }

    // MARK: - Add

    private var addCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("现在听到")
                .font(AppFont.rounded(10, weight: .medium))
                .foregroundStyle(Palette.inkFaint)
            Text(player.currentSentence?.text ?? "还没有开始朗读")
                .font(AppFont.serif(14))
                .foregroundStyle(Palette.ink.opacity(0.9))
                .lineLimit(2)
                .lineSpacing(3)

            if currentIsBookmarked {
                HStack(spacing: 6) {
                    Image(systemName: "bookmark.fill")
                    Text("这一句已经收藏")
                }
                .font(AppFont.rounded(12, weight: .medium))
                .foregroundStyle(Palette.accent)
                .padding(.top, 2)
            } else {
                Button {
                    addCurrent()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bookmark.badge.plus")
                        Text("把这一句加入书签")
                    }
                    .font(AppFont.rounded(12, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Palette.accent))
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(player.currentSentence == nil)
                .opacity(player.currentSentence == nil ? 0.5 : 1)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Palette.card.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Palette.line.opacity(0.7), lineWidth: 0.8)
        )
    }

    // MARK: - List

    private var bookmarkList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("共 \(bookmarks.count) 枚")
                .font(AppFont.rounded(11))
                .foregroundStyle(Palette.inkFaint)
                .padding(.top, 4)

            ForEach(bookmarks) { bookmark in
                bookmarkCard(bookmark)
            }
        }
    }

    private func bookmarkCard(_ bookmark: Bookmark) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Text("第 \(bookmark.sentenceIndex + 1) 句")
                    .font(AppFont.rounded(10, weight: .medium))
                    .foregroundStyle(Palette.accent)
                Rectangle()
                    .fill(Palette.line)
                    .frame(width: 14, height: 0.7)
                Text(timeText(bookmark.createdAt))
                    .font(AppFont.rounded(10))
                    .foregroundStyle(Palette.inkFaint)
                Spacer()
                Button {
                    editingBookmark = bookmark
                    draftNote = bookmark.note
                    showNoteEditor = true
                } label: {
                    Image(systemName: bookmark.note.isEmpty ? "text.bubble" : "text.bubble.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.inkSoft)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("编辑备注")

                Button {
                    store.removeBookmark(bookID: bookID, bookmarkID: bookmark.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.inkFaint)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("删除书签")
            }

            Text(bookmark.snippet)
                .font(AppFont.serif(15))
                .foregroundStyle(Palette.ink)
                .lineSpacing(4)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            if !bookmark.note.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 9))
                        .foregroundStyle(Palette.inkFaint)
                        .padding(.top, 2)
                    Text(bookmark.note)
                        .font(AppFont.rounded(11))
                        .foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Palette.paperDeep.opacity(0.55))
                )
            }

            HStack {
                Spacer()
                Button {
                    onJump(bookmark.sentenceIndex)
                    dismiss()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9))
                        Text("从这里听")
                            .font(AppFont.rounded(11, weight: .semibold))
                    }
                    .foregroundStyle(Palette.accent)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Palette.accent.opacity(0.10)))
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Palette.card.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Palette.line.opacity(0.65), lineWidth: 0.8)
        )
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bookmark")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Palette.inkFaint)
            Text("还没有书签")
                .font(AppFont.serif(17, weight: .semibold))
                .foregroundStyle(Palette.ink)
            Text("听到喜欢的一句，点一下播放器右上角的书签。")
                .font(AppFont.rounded(11))
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 46)
    }

    // MARK: - Actions

    private func addCurrent() {
        guard let sentence = player.currentSentence else { return }
        store.toggleBookmark(
            bookID: bookID,
            sentenceIndex: sentence.id,
            charOffset: sentence.range.location,
            snippet: sentence.text
        )
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
    }
}
