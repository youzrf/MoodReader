import Foundation
import Combine

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var books: [Book] = []

    private let fileURL: URL
    private var pendingSave: Task<Void, Never>?

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let folder = base.appendingPathComponent("MoodReader", isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            self.fileURL = folder.appendingPathComponent("library.json")
        }
        load()
    }

    // MARK: - Read

    func book(id: UUID) -> Book? {
        books.first { $0.id == id }
    }

    var mostRecentBook: Book? {
        books.max { $0.lastOpenedAt < $1.lastOpenedAt }
    }

    // MARK: - Write

    @discardableResult
    func addBook(title: String, author: String, content: String) -> Book {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let book = Book(
            title: cleanTitle.isEmpty ? Self.derivedTitle(from: cleanContent) : cleanTitle,
            author: cleanAuthor,
            content: cleanContent
        )
        books.insert(book, at: 0)
        scheduleSave()
        return book
    }

    func delete(bookID: UUID) {
        books.removeAll { $0.id == bookID }
        scheduleSave()
    }

    func markOpened(bookID: UUID) {
        guard let index = books.firstIndex(where: { $0.id == bookID }) else { return }
        books[index].lastOpenedAt = Date()
        scheduleSave()
    }

    func updateProgress(bookID: UUID, sentenceIndex: Int, charOffset: Int, progress: Double) {
        guard let index = books.firstIndex(where: { $0.id == bookID }) else { return }
        guard books[index].lastSentenceIndex != sentenceIndex
                || books[index].lastCharOffset != charOffset else { return }
        books[index].lastSentenceIndex = sentenceIndex
        books[index].lastCharOffset = charOffset
        books[index].progress = min(max(progress, 0), 1)
        scheduleSave()
    }

    @discardableResult
    func toggleBookmark(bookID: UUID, sentenceIndex: Int, charOffset: Int, snippet: String) -> Bool {
        guard let index = books.firstIndex(where: { $0.id == bookID }) else { return false }
        if let bookmarkIndex = books[index].bookmarks.firstIndex(where: { $0.sentenceIndex == sentenceIndex }) {
            books[index].bookmarks.remove(at: bookmarkIndex)
            scheduleSave()
            return false
        }
        let bookmark = Bookmark(
            sentenceIndex: sentenceIndex,
            charOffset: charOffset,
            snippet: snippet
        )
        books[index].bookmarks.append(bookmark)
        books[index].bookmarks.sort { $0.sentenceIndex < $1.sentenceIndex }
        scheduleSave()
        return true
    }

    func removeBookmark(bookID: UUID, bookmarkID: UUID) {
        guard let index = books.firstIndex(where: { $0.id == bookID }) else { return }
        books[index].bookmarks.removeAll { $0.id == bookmarkID }
        scheduleSave()
    }

    func updateBookmarkNote(bookID: UUID, bookmarkID: UUID, note: String) {
        guard let bookIndex = books.firstIndex(where: { $0.id == bookID }),
              let markIndex = books[bookIndex].bookmarks.firstIndex(where: { $0.id == bookmarkID }) else {
            return
        }
        books[bookIndex].bookmarks[markIndex].note = note
        scheduleSave()
    }

    func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        writeToDisk()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            books = Book.samples()
            scheduleSave()
            return
        }
        guard let decoded = try? JSONDecoder().decode([Book].self, from: data) else {
            books = Book.samples()
            scheduleSave()
            return
        }
        books = decoded
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            self?.writeToDisk()
        }
    }

    private func writeToDisk() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            let data = try encoder.encode(books)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("MoodReader: 保存书架失败 - \(error)")
        }
    }

    private static func derivedTitle(from content: String) -> String {
        let firstLine = content
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let title = firstLine.isEmpty ? "未命名朗读" : firstLine
        return String(title.prefix(18))
    }
}
