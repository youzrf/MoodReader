import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var store: LibraryStore

    @State private var path: [Book] = []
    @State private var showNewBook = false
    @State private var createdBook: Book?
    @State private var pendingDelete: Book?
    @State private var showDeleteAlert = false

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                PaperBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        header
                        if let recent = store.mostRecentBook {
                            continueCard(for: recent)
                        }
                        shelf
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Book.self) { book in
                ReaderView(book: book)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showNewBook, onDismiss: openCreatedBook) {
                NewBookSheet { book in
                    createdBook = book
                }
                .environmentObject(store)
            }
            .alert("删除这本书？", isPresented: $showDeleteAlert, presenting: pendingDelete) { book in
                Button("删除", role: .destructive) {
                    store.delete(bookID: book.id)
                }
                Button("取消", role: .cancel) {}
            } message: { book in
                Text("《\(book.title)》的朗读进度和书签也会一起删除。")
            }
        }
        .tint(Palette.accent)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(greeting)
                        .font(AppFont.rounded(12, weight: .medium))
                        .foregroundStyle(Palette.inkSoft)
                        .tracking(1.6)
                    Text("声笺")
                        .font(AppFont.serif(36, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                }
                Spacer()
                Button {
                    showNewBook = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Palette.ink))
                        .shadow(color: Palette.ink.opacity(0.18), radius: 10, y: 5)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("新建朗读")
            }

            HStack(spacing: 8) {
                Text("让文字，有情绪地响起来")
                    .font(AppFont.rounded(13))
                    .foregroundStyle(Palette.inkSoft)
                Rectangle()
                    .fill(Palette.line)
                    .frame(width: 22, height: 0.7)
                Text(dateText)
                    .font(AppFont.rounded(11))
                    .foregroundStyle(Palette.inkFaint)
            }
            .padding(.top, 3)
        }
    }

    // MARK: - Continue

    private func continueCard(for book: Book) -> some View {
        Button {
            store.markOpened(bookID: book.id)
            path.append(book)
        } label: {
            HStack(spacing: 14) {
                BookCover(book: book, compact: true)
                    .frame(width: 62, height: 82)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 7) {
                        CapsuleTag(text: book.progress > 0.001 ? "继续收听" : "开始收听", tint: Palette.accent)
                        Text("\(book.readingMinutes) 分钟")
                            .font(AppFont.rounded(11))
                            .foregroundStyle(Palette.inkFaint)
                    }
                    Text(book.title)
                        .font(AppFont.serif(18, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Text(book.author.isEmpty ? "未署名" : book.author)
                        .font(AppFont.rounded(11))
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(1)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Palette.line.opacity(0.75))
                            Capsule()
                                .fill(Palette.accent)
                                .frame(width: geometry.size.width * max(0.015, book.progress))
                        }
                    }
                    .frame(height: 3.5)
                    .padding(.top, 2)
                }

                Image(systemName: "play.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Palette.accent.opacity(0.10)))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Palette.card.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Palette.line.opacity(0.65), lineWidth: 0.8)
            )
            .shadow(color: Palette.ink.opacity(0.05), radius: 18, y: 10)
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Shelf

    private var shelf: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("我的书架")
                    .font(AppFont.serif(20, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text("\(store.books.count)")
                    .font(AppFont.rounded(12, weight: .medium))
                    .foregroundStyle(Palette.inkFaint)
                Spacer()
                Text("长按可删除")
                    .font(AppFont.rounded(10))
                    .foregroundStyle(Palette.inkFaint)
            }

            if store.books.isEmpty {
                emptyShelf
            } else {
                LazyVGrid(columns: columns, spacing: 22) {
                    ForEach(store.books) { book in
                        Button {
                            store.markOpened(bookID: book.id)
                            path.append(book)
                        } label: {
                            BookCard(book: book)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .contextMenu {
                            Button(role: .destructive) {
                                pendingDelete = book
                                showDeleteAlert = true
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyShelf: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Palette.inkFaint)
            Text("书架还空着")
                .font(AppFont.serif(18, weight: .semibold))
                .foregroundStyle(Palette.ink)
            Text("粘贴一段文字，或导入一个 txt 文件")
                .font(AppFont.rounded(12))
                .foregroundStyle(Palette.inkSoft)
            Button("新建朗读") { showNewBook = true }
                .font(AppFont.rounded(13, weight: .semibold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(Capsule().fill(Palette.accent))
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Palette.card.opacity(0.7))
        )
    }

    // MARK: - Helpers

    private func openCreatedBook() {
        guard let createdBook else { return }
        self.createdBook = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            path.append(createdBook)
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return "早上好"
        case 11..<14: return "中午好"
        case 14..<18: return "下午好"
        default: return "晚上好"
        }
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: Date())
    }
}

// MARK: - Cover

private struct BookCover: View {
    let book: Book
    var compact: Bool = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: compact ? 10 : 18, style: .continuous)
                .fill(gradient)

            Circle()
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                .frame(width: compact ? 54 : 120, height: compact ? 54 : 120)
                .offset(x: compact ? 22 : 62, y: compact ? -28 : -80)

            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: compact ? 38 : 92, height: compact ? 38 : 92)
                .offset(x: compact ? -12 : -24, y: compact ? -46 : -118)

            VStack(alignment: .leading, spacing: compact ? 3 : 8) {
                Text(book.initial)
                    .font(AppFont.serif(compact ? 26 : 54, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.94))
                if !compact {
                    MiniWaveform(color: Color.white.opacity(0.7))
                }
                Text(book.title)
                    .font(AppFont.serif(compact ? 9 : 15, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(compact ? 8 : 14)
        }
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 10 : 18, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 0.8)
        )
        .shadow(color: gradientShadow, radius: compact ? 6 : 14, y: compact ? 3 : 8)
    }

    private var gradient: LinearGradient {
        let colors = BookCard.palette(for: book.seed)
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var gradientShadow: Color {
        BookCard.palette(for: book.seed).last?.opacity(0.28) ?? Color.black.opacity(0.1)
    }
}

private struct MiniWaveform: View {
    let color: Color
    private let heights: [CGFloat] = [5, 11, 7, 15, 9, 13, 6]

    var body: some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(Array(heights.enumerated()), id: \.offset) { _, height in
                Capsule()
                    .fill(color)
                    .frame(width: 2, height: height)
            }
        }
        .frame(height: 15)
    }
}

// MARK: - Book card

private struct BookCard: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            BookCover(book: book)
                .aspectRatio(0.73, contentMode: .fit)

            VStack(alignment: .leading, spacing: 3) {
                Text(book.title)
                    .font(AppFont.serif(16, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 5) {
                    Text(book.author.isEmpty ? "未署名" : book.author)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    Text("\(book.readingMinutes) 分钟")
                }
                .font(AppFont.rounded(10))
                .foregroundStyle(Palette.inkFaint)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.line.opacity(0.65))
                        Capsule()
                            .fill(Palette.accent.opacity(0.85))
                            .frame(width: geometry.size.width * max(0.012, book.progress))
                    }
                }
                .frame(height: 2.5)
                .padding(.top, 3)
            }
        }
    }

    static func palette(for seed: Int) -> [Color] {
        switch seed % 5 {
        case 0:
            return [Color(hex: 0xB85C3E), Color(hex: 0x7F3D2E)]
        case 1:
            return [Color(hex: 0x6F8A80), Color(hex: 0x3E5A55)]
        case 2:
            return [Color(hex: 0xC79A4B), Color(hex: 0x8A632D)]
        case 3:
            return [Color(hex: 0x9C6B78), Color(hex: 0x6A4250)]
        default:
            return [Color(hex: 0x5E7285), Color(hex: 0x354656)]
        }
    }
}

#Preview {
    LibraryView()
        .environmentObject(LibraryStore())
}
