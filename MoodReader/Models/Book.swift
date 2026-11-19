import Foundation

// MARK: - Book

struct Book: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var author: String
    var content: String
    var createdAt: Date
    var lastOpenedAt: Date
    var lastSentenceIndex: Int
    var lastCharOffset: Int
    var progress: Double
    var seed: Int
    var bookmarks: [Bookmark]

    init(
        id: UUID = UUID(),
        title: String,
        author: String = "",
        content: String,
        createdAt: Date = Date(),
        lastOpenedAt: Date = Date(),
        lastSentenceIndex: Int = 0,
        lastCharOffset: Int = 0,
        progress: Double = 0,
        seed: Int = Int.random(in: 0..<5),
        bookmarks: [Bookmark] = []
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.content = content
        self.createdAt = createdAt
        self.lastOpenedAt = lastOpenedAt
        self.lastSentenceIndex = lastSentenceIndex
        self.lastCharOffset = lastCharOffset
        self.progress = progress
        self.seed = seed
        self.bookmarks = bookmarks
    }

    var characterCount: Int { content.count }

    var readingMinutes: Int {
        max(1, Int(ceil(Double(characterCount) / 320.0)))
    }

    var preview: String {
        content
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var initial: String {
        String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1))
    }
}

// MARK: - Bookmark

struct Bookmark: Identifiable, Codable, Hashable {
    var id: UUID
    var sentenceIndex: Int
    var charOffset: Int
    var snippet: String
    var note: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        sentenceIndex: Int,
        charOffset: Int,
        snippet: String,
        note: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sentenceIndex = sentenceIndex
        self.charOffset = charOffset
        self.snippet = snippet
        self.note = note
        self.createdAt = createdAt
    }
}

// MARK: - Samples

extension Book {
    static func samples() -> [Book] {
        [
            Book(
                title: "深夜便利店",
                author: "声笺 · 短篇",
                content: """
                城市在凌晨两点的时候，会露出另一种表情。

                我推开便利店的门，风铃“叮”地响了一声。收银台后面的年轻人抬起头，冲我笑了一下：“还是老样子？”

                “嗯，一杯热豆浆。”我说。

                他把杯子放到机器下面，白色的热气很快涌上来，像一小团舍不得散开的云。窗外有出租车驶过，灯光从玻璃上滑下去，整条街又安静了。

                我忽然想起很多年前，也是这样的深夜，也有人问过我要不要喝点热的。那时候我急着赶路，摇了摇头。后来才明白，有些热气，错过了就不会再有。

                “您的豆浆。”他把杯子推过来，又补了一句，“小心烫。”

                我捧着杯子走出门。夜风很凉，掌心却很暖。城市没有说话，只是把一盏一盏的灯，留给了还醒着的人。
                """,
                seed: 0
            ),
            Book(
                title: "海边的第七封信",
                author: "声笺 · 书信",
                content: """
                亲爱的阿遥：

                这是我写给你的第七封信。前六封都没有寄出去，它们安静地躺在抽屉里，像六只不肯远行的纸船。

                今天下午，我去了我们以前常去的那片海。风很大，浪一层一层地推上来，又退回去。我在礁石上坐了很久，直到鞋底沾满了细碎的沙。

                你还记得吗？你说过，海是不会记住任何人的。可我不信。要不然，为什么每一次潮水涌上来，都像是在叫谁的名字？

                我带了一枚硬币，原本想替你许个愿。可硬币在掌心握得太久，竟然也暖了。最后我没有把它扔进海里，而是放回了口袋。

                有些愿望，也许不必实现。只要它还在，就已经足够让人走下去。

                天色暗下来的时候，我听见远处有人在笑。那笑声被风吹得断断续续，却让我忽然很想你。

                阿遥，如果你收到这封信，不必急着回。你只要知道，在很远的地方，有一个人把海的声音，折进了纸里。

                祝你好眠。

                林岸
                十一月十七日
                """,
                seed: 1
            ),
            Book(
                title: "把日子读慢一点",
                author: "声笺 · 随笔",
                content: """
                我们总是太着急了。

                急着起床，急着赶路，急着把一天的事情做完，再急着睡去。手机里的消息一条接一条，像雨点落在铁皮屋顶上，热闹，却听不清哪一滴才是自己的声音。

                有一天，我故意把闹钟关掉，睡到自然醒。阳光已经爬到了书桌边上，灰尘在光里慢慢地飘。我给自己煮了一壶茶，没有放音乐，也没有打开任何屏幕。

                水开的时候，壶盖轻轻跳动，发出“嗒、嗒”的声响。我忽然觉得，这声音很好听。不是因为它有多美，而是因为我终于有空，把它听完。

                楼下的老人正在浇花。他浇得很慢，一勺一勺，像是怕惊动了叶子上的光。我趴在窗边看了很久，心里那根一直绷着的弦，悄悄地松了一点。

                慢下来，并不是把生活停下来。而是让眼睛重新看见，让耳朵重新听见，让心重新回到身体里。

                如果你也觉得累了，不妨试试：把手机放远一点，把呼吸放长一点。然后，听一段文字，读一页书，或者，只是安安静静地，喝完一杯热水。

                日子不会因为我们的匆忙而变短，却会因为我们的停留，变得厚一点。

                今天，也请慢一点。
                """,
                seed: 2
            )
        ]
    }
}
