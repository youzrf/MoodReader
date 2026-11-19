# 接入豆包级情绪语音

当前版本是**离线可用**的系统语音方案：断句、逐句情绪、暂停、书签都已经完成，但音色上限取决于 iOS 的 AVSpeechSynthesizer。想要接近豆包，需要把“发声”这一步换成云端神经 TTS。本文给出可选路线和接入点，不包含任何密钥。

---

## 1. 为什么不能只靠 AVSpeechSynthesizer

`AVSpeechUtterance` 能调的参数只有：

- `rate`：语速
- `pitchMultiplier`：音高
- `volume`：音量
- `preUtteranceDelay` / `postUtteranceDelay`：句前后停顿

这能做“有起伏”，但做不了真正的**音色风格迁移**：笑意、叹气、气声、哭腔、角色感，都需要神经 TTS 在声学模型层面生成。系统语音的音色也取决于用户下载了哪个 voice。

所以当前实现的定位是：**断句、情绪编排和交互体验先做好，声音引擎可以替换**。

---

## 2. 推荐的服务

| 服务 | 优势 | 注意 |
| --- | --- | --- |
| 火山引擎豆包语音 | 与豆包同源，中文情绪最接近 | WebSocket 二进制协议，建议服务端签名/中转 |
| Azure Speech | SSML 成熟，`mstts:express-as` 风格多，REST 简单 | 不同 voice 支持不同 style，需要逐个确认 |
| OpenAI `gpt-4o-mini-tts` | 可用自然语言描述语气，接入最快 | 国内访问、成本、延迟需要评估 |

如果目标是“和豆包差不多”，优先火山引擎；如果先做可用的情绪版本，Azure 或 OpenAI 更容易在一两天内接完。

---

## 3. 接入点：只替换播放器

现有的数据流是：

```text
Book.content
   ↓ TextSegmenter
[ReaderSentence] + [SpeechChunk]   ← 断句、书签、进度都用它
   ↓ SpeechPlayer
AVSpeechSynthesizer
```

需要改的只有最后一步。建议抽一个协议：

```swift
protocol SpeechEngine: AnyObject {
    var onProgress: ((_ sentenceIndex: Int, _ charOffset: Int, _ progress: Double) -> Void)? { get set }
    var onFinished: (() -> Void)? { get set }

    func load(title: String, author: String, sentences: [ReaderSentence],
              chunks: [SpeechChunk], startSentenceIndex: Int)
    func play()
    func pause()
    func stop()
    func seek(toSentence index: Int)
}
```

然后：

- `LocalSpeechEngine`：现在的 `SpeechPlayer` 改个名；
- `CloudSpeechEngine`：请求音频、缓存、用 `AVAudioPlayer` 播放；
- `ReaderView` 里根据设置选择引擎，阅读器、书签、进度逻辑完全不动。

云端播放器的核心循环：

```text
当前 chunk → 查缓存
  ├─ 命中：AVAudioPlayer 直接播
  └─ 未命中：请求云端 → 写缓存 → 播
       同时预取后面 1–2 个 chunk
播放结束 → 停顿（按情绪）→ 下一个 chunk
```

暂停用 `AVAudioPlayer.pause()` / `play()`，比 AVSpeechSynthesizer 更可控；`audioPlayerDidFinishPlaying` 里推进位置。来电中断仍然用 `AVAudioSession.interruptionNotification`。

---

## 4. Azure Speech 示例

### 请求

```http
POST https://<region>.tts.speech.microsoft.com/cognitiveservices/v1
Ocp-Apim-Subscription-Key: <key>
Content-Type: application/ssml+xml
X-Microsoft-OutputFormat: audio-24khz-48kbitrate-mono-mp3
User-Agent: MoodReader
```

### SSML

```xml
<speak version="1.0"
       xmlns="http://www.w3.org/2001/10/synthesis"
       xmlns:mstts="https://www.w3.org/2001/mstts"
       xml:lang="zh-CN">
  <voice name="zh-CN-XiaoxiaoNeural">
    <mstts:express-as style="gentle" styledegree="1.2">
      <prosody rate="0.92" pitch="+0%">
        我推开便利店的门，风铃“叮”地响了一声。
      </prosody>
    </mstts:express-as>
  </voice>
</speak>
```

常用 style：

```text
cheerful / sad / angry / fearful / gentle / serious
affectionate / calm / excited / friendly / hopeful
```

不是每个 voice 都支持所有 style，建议先用 Xiaoxiao / Yunxi / Xiaoyi 测一遍。`styledegree` 范围约 0.01–2，1.0 是默认强度。

### 情绪映射

```swift
extension Emotion {
    var azureStyle: String {
        switch self {
        case .auto, .calm: return "calm"
        case .warm: return "gentle"
        case .cheerful: return "cheerful"
        case .sad: return "sad"
        case .serious: return "serious"
        case .excited: return "excited"
        case .curious: return "friendly"
        case .whisper: return "gentle" // 再配合 volume / rate
        }
    }
}
```

请求前必须对文本做 XML 转义（`& < > " '`），否则引号和 `&` 会直接把 SSML 弄坏。

---

## 5. OpenAI 兼容 TTS 示例

```http
POST https://api.openai.com/v1/audio/speech
Authorization: Bearer <key>
Content-Type: application/json
```

```json
{
  "model": "gpt-4o-mini-tts",
  "voice": "coral",
  "input": "我推开便利店的门，风铃“叮”地响了一声。",
  "instructions": "用温柔、略带笑意的语气朗读，像深夜电台，语速稍慢，句尾不要上扬。",
  "response_format": "mp3",
  "speed": 0.95
}
```

返回的响应体直接是音频二进制。`instructions` 是 `gpt-4o-mini-tts` 的能力，不是所有 OpenAI TTS 模型都支持；用兼容网关时要先确认。

可以让 `Emotion` 生成 instruction：

```text
温柔：用温柔、略带笑意的气声朗读，语速慢一点，像在耳边说话。
感伤：用克制的悲伤语气，句尾下沉，停顿稍长。
激动：语速加快，音量提高，重音落在“终于/竟然”这类词上。
好奇：句尾轻微上扬，像在提问。
低语：接近气声，音量降低，停顿拉长。
```

---

## 6. 缓存与预取

按“声音 + 情绪 + 语速 + 文本”做 key：

```swift
let key = SHA256("\(voice)|\(style)|\(rate)|\(chunk.text)")
```

- 缓存目录：`FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)` 下的 `TTS/`；
- 预取：当前 chunk 开始播放时，请求 `index + 1`、`index + 2`；
- 取消：用户切句/退出时取消未完成的 `URLSessionTask`；
- 清理：超过 200MB 或 7 天未访问的缓存可以清掉。

这样连续听长文时，句与句之间不会每句都等 1–2 秒。

---

## 7. 密钥安全

不要把云端 key 写进 `Info.plist`、源码或 UserDefaults。至少：

- 让用户自己填，存 Keychain；
- 或者放自己的服务端，App 只请求你的中转接口，由服务端持有 key 并做限流；
- 服务端接口加 App Attest / 登录态，避免被白嫖。

Keychain 最小示例：

```swift
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "com.moodreader.tts",
    kSecAttrAccount as String: "azure-key",
    kSecValueData as String: keyData
]
SecItemAdd(query as CFDictionary, nil)
```

---

## 8. 火山引擎 / 豆包

火山引擎的 TTS 通常走 WebSocket 二进制协议，需要：

- `appid`
- `access_token`
- `cluster`
- `voice_type`
- 可选的 `emotion`（部分音色支持 `happy` / `sad` / `angry` / `surprised` / `neutral` 等）
- `speech_rate` / `pitch_rate`

协议比 REST 复杂，建议不要在 iOS 客户端里直接拼签名。更稳的做法：

```text
iOS → 你的服务端（鉴权/签名）→ 火山引擎 WebSocket
```

服务端把音频流式转发回来，iOS 用 `AVAudioEngine` 或边收边写的 `AVAudioPlayer` 播放。

---

## 9. 接入后仍然保留的东西

- `TextSegmenter` 的句子/片段划分；
- `EmotionDirector` 的逐句语气判断；
- 书签的 `sentenceIndex + charOffset`；
- `LibraryStore` 的进度持久化；
- 锁屏 `MPNowPlayingInfoCenter`；
- 暂停、上一句、下一句、点句跳转。

换句话说：**断句和交互已经是成品，云端只负责“把这一段字读得更好听”**。
