import SwiftUI
import UniformTypeIdentifiers

struct NewBookSheet: View {
    @EnvironmentObject private var store: LibraryStore
    @Environment(\.dismiss) private var dismiss

    let onCreated: (Book) -> Void

    @State private var title = ""
    @State private var author = ""
    @State private var text = ""
    @State private var showImporter = false
    @State private var errorMessage: String?
    @FocusState private var editorFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        intro
                        titleFields
                        editorCard
                        importRow
                        footer
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 10)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("新建朗读")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(Palette.inkSoft)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("开始") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                         ? Palette.inkFaint : Palette.accent)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.plainText]
            ) { result in
                importFile(result)
            }
            .alert("没能创建", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .tint(Palette.accent)
    }

    // MARK: - Sections

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("把想听的字，放进来。")
                .font(AppFont.serif(23, weight: .semibold))
                .foregroundStyle(Palette.ink)
            Text("会自动断句，长句在逗号处换气；每一句都会有合适的语气。")
                .font(AppFont.rounded(12))
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var titleFields: some View {
        VStack(spacing: 0) {
            TextField("标题（可留空）", text: $title)
                .font(AppFont.serif(19, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Palette.card)

            SoftDivider().padding(.leading, 16)

            TextField("作者 / 来源（可选）", text: $author)
                .font(AppFont.rounded(13))
                .foregroundStyle(Palette.ink)
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Palette.card)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Palette.line.opacity(0.7), lineWidth: 0.8)
        )
    }

    private var editorCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("正文")
                    .font(AppFont.rounded(11, weight: .medium))
                    .foregroundStyle(Palette.inkSoft)
                Spacer()
                Text("\(text.count) 字 · 约 \(estimatedMinutes) 分钟")
                    .font(AppFont.rounded(10))
                    .foregroundStyle(Palette.inkFaint)
            }

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("把文章粘贴到这里，或者从下方导入 txt 文件…")
                        .font(AppFont.serif(16))
                        .foregroundStyle(Palette.inkFaint)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $text)
                    .font(AppFont.serif(16))
                    .foregroundStyle(Palette.ink)
                    .lineSpacing(6)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .focused($editorFocused)
                    .frame(minHeight: 250)
                    .padding(.horizontal, -1)
            }
            .padding(13)
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

    private var importRow: some View {
        Button {
            showImporter = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "doc.text")
                    .font(.system(size: 14, weight: .medium))
                Text("从文件导入 txt")
                    .font(AppFont.rounded(13, weight: .medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.inkFaint)
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.card.opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Palette.line.opacity(0.6), lineWidth: 0.8)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var footer: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "waveform")
                .font(.system(size: 10))
            Text("支持中文与英文。导入 GB18030、UTF-8 编码的 txt 都可以。")
                .font(AppFont.rounded(10))
        }
        .foregroundStyle(Palette.inkFaint)
    }

    // MARK: - Actions

    private var estimatedMinutes: Int {
        max(1, Int(ceil(Double(text.count) / 320.0)))
    }

    private func save() {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            errorMessage = "先粘贴或导入一些文字吧。"
            return
        }
        let book = store.addBook(title: title, author: author, content: clean)
        onCreated(book)
        dismiss()
    }

    private func importFile(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            errorMessage = "读取文件失败：\(error.localizedDescription)"
        case .success(let url):
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let data = try Data(contentsOf: url)
                guard let content = Self.decode(data) else {
                    errorMessage = "这个文件暂时读不出来，请换一个 txt 文件试试。"
                    return
                }
                text = content.trimmingCharacters(in: .whitespacesAndNewlines)
                if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    title = url.deletingPathExtension().lastPathComponent
                }
            } catch {
                errorMessage = "读取文件失败：\(error.localizedDescription)"
            }
        }
    }

    private static func decode(_ data: Data) -> String? {
        if let value = String(data: data, encoding: .utf8) {
            return value
        }
        // GB18030（兼容 GBK / GB2312）在 Foundation 中的编码值。
        let gb18030 = String.Encoding(rawValue: 0x80000632)
        if let value = String(data: data, encoding: gb18030) {
            return value
        }
        if let value = String(data: data, encoding: .utf16) {
            return value
        }
        return String(data: data, encoding: .isoLatin1)
    }
}

#Preview {
    NewBookSheet { _ in }
        .environmentObject(LibraryStore())
}
