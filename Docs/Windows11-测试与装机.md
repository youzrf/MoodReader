# 在 Windows 11 上测试，并安装到 iPhone

> 适用对象：手上只有 Windows 电脑，想做 iOS App 的开发者。
> 对应工程：本仓库 `MoodReader.xcodeproj`（SwiftUI + AVSpeechSynthesizer，iOS 17+，Xcode 16 工程格式）。

---

## 0. 先看结论

有三件事要分开说，很多人把它们混成一件事，于是卡住：

| 你想做的事 | Windows 11 上能不能做 | 怎么做 |
| --- | --- | --- |
| 跑业务逻辑测试（断句、情绪、书签） | **能** | 现在就能跑，见第 1 节（浏览器 demo + Node 测试） |
| 编译原生 iOS 包 | **不能**，必须 macOS + Xcode | 交给云端 macOS：GitHub Actions（本仓库已配好） |
| 装到自己的 iPhone | **能**，但要借一次 Apple 签名 | 云端出 IPA → Windows 上 Sideloadly 签名安装（免费 Apple ID，7 天）；或付费账号走 TestFlight（90 天） |

一句话：**Windows 负责写代码和签名装机，macOS 只负责编译。** 编译这一环可以租云端的、也可以白嫖 GitHub 的 macOS 机器，不需要你自己买 Mac。

### 五条路线的成本对比

| 路线 | 花钱 | 花时间（首次） | App 有效期 | 需要 Mac 吗 | 适合谁 |
| --- | --- | --- | --- | --- | --- |
| **A. GitHub Actions + Sideloadly（免费 Apple ID）** | ¥0 | 1–2 小时 | 7 天，到期重签 | 不需要 | 想立刻在自己手机上用起来 |
| **B. 付费开发者 + TestFlight** | $99/年 | 半天（含审核） | 90 天/个构建 | 不需要 | 长期用、给朋友测、不想每 7 天折腾 |
| **C. 租云 Mac** | 约 $1/小时 起 | 1 小时 | 取决于签名方式 | 云端 Mac | 要在真正的 Xcode/模拟器里调 UI、看日志 |
| **D. 买台二手 Mac mini** | ¥1500–2500 | 半天 | 免费账号也能真机调试 | 自己的 Mac | 打算长期做 iOS |
| **E. 浏览器 / PWA（不装原生 App）** | ¥0 | 10 分钟 | 不限 | 不需要 | 只想先看看长什么样，不想碰 Apple ID |

**建议**：先走 **A**，今晚就能在手机上听到朗读；用满一周觉得值得，再考虑 B 或 D。C 只在你要深度调试界面时才需要。

---

## 1. 现在就能在 Windows 上做的验证（5 分钟，不用 Apple 账号）

这个仓库里带了一个和 iOS 版同一套断句/情绪逻辑的网页演示，功能等价度很高：

```powershell
# 方式一：直接双击
start "G:\ios阅读器\demo\index.html"

# 方式二：起本地服务器（推荐，避免浏览器限制本地文件）
cd "G:\ios阅读器"
python -m http.server 8000
# 然后浏览器打开 http://localhost:8000/demo/
```

跑一遍逻辑测试（本机已实测通过，Node 24）：

```powershell
cd "G:\ios阅读器\demo"
node segmenter.test.js
# 输出：segmenter tests passed
```

这能验证：断句、引号旁白合并、小数/英文句号、长句换气、情绪判定、点击跳句、书签、进度记忆。
**不能**验证：AVSpeechSynthesizer 的真实音色、锁屏/后台播放、系统语音包、Now Playing 控件——这些只能上真机或模拟器。

---

## 2. 路线 A：0 元把 App 装到你的 iPhone

### A-1. 把工程推到 GitHub（约 10 分钟）

1. 浏览器打开 <https://github.com/new>，仓库名填 `MoodReader`，**不要**勾选 README/LICENSE/.gitignore（保持空仓库），可见性选 **Public**。
2. 在本机执行（把 `你的用户名`、名字、邮箱换成你自己的）：

```powershell
cd "G:\ios阅读器"
git init -b main
git config user.name "你的名字"
git config user.email "你的邮箱"
git add -A
git commit -m "MoodReader: iOS 朗读应用"
git remote add origin https://github.com/你的用户名/MoodReader.git
git push -u origin main
```

第一次 push 会弹出浏览器让你登录 GitHub，授权后即可。之后每次改代码就是 `git add -A; git commit -m "..."; git push`。

> **为什么建议 Public**：GitHub Actions 的 macOS 机器按 **10 倍**计费。私有仓库每月只有 2000 分钟额度，等于 200 分钟 macOS；公开仓库的 macOS 分钟完全免费。代码里没有密钥，公开没有风险。
>
> 不想公开也行，那就把额度省着用：一次构建约 3–5 分钟，200 分钟够跑 40 次左右。或者改用 **Codemagic**（个人免费 500 分钟/月的 macOS M2）。

### A-2. 在云端编译出 IPA（约 8–12 分钟）

仓库里已经放好 `.github/workflows/ios-build.yml`，push 之后会自动跑；也可以手动触发：

1. 打开 `https://github.com/你的用户名/MoodReader/actions`
2. 左侧选 **iOS Build** → 右上 **Run workflow** → **Run workflow**
3. 等它变绿（第一次要装工具链，慢一点）
4. 进这次运行 → 页面底部 **Artifacts** → 下载 **MoodReader-unsigned-ipa**
5. 解压得到 `MoodReader-unsigned.ipa`

> 这个 IPA 是**未签名**的（CI 里显式关掉了签名），必须在你电脑上用 Apple ID 签一次才能装，见 A-4/A-5。
> 想顺便在浏览器里看看界面，运行 workflow 时勾上 `build_simulator_app`，会多产出一个模拟器版 `.app.zip`，见第 6 节。

### A-3. Windows 端准备签名工具（约 20 分钟）

Sideloadly 需要**苹果官网版**的 iTunes 和 iCloud，Microsoft Store 版是被沙盒化的，签名必定失败。

1. 如果装过 Microsoft Store 版 iTunes / iCloud，先卸载。
2. 安装官网版（右键 → 以管理员身份运行）：
   - iTunes 64 位：<https://www.apple.com/itunes/download/win64>
   - iCloud：<https://updates.cdn-apple.com/2020/windows/001-39935-20200911-1A70AA56-F448-11EA-8CC0-99D41950005E/iCloudSetup.exe>
3. 安装 Sideloadly（Windows 版）：<https://sideloadly.io/> → `SideloadlySetup64.exe`
4. **重启电脑**（让 Apple Mobile Device 服务生效）。
5. 装完用数据线连手机，先打开 iTunes 确认能识别设备，并同步一次。

### A-4. iPhone 端准备（约 3 分钟）

iOS 16 起，安装非 App Store 的 App 必须打开开发者模式：

1. **设置 → 隐私与安全性 → 开发者模式** → 打开 → 重启手机 → 重启后解锁时再确认一次。
2. 数据线连电脑，手机上点 **信任**，输入锁屏密码。
3. 确认系统版本 ≥ iOS 17（工程默认部署目标就是 17.0）。

### A-5. 用 Sideloadly 签名安装（约 3 分钟）

1. 打开 Sideloadly，顶部设备下拉里应该出现你的 iPhone。
2. 把 `MoodReader-unsigned.ipa` 拖进 Sideloadly 的 IPA 区域。
3. **Apple ID** 填你的 Apple ID（免费的就行），点 **Start**。
4. 如果开了双重认证，会弹窗让你输 6 位验证码。
5. 首次会花 30–60 秒创建开发证书和 7 天描述文件，然后开始安装。

两个常用选项：

- **Advanced Options → Change Bundle ID**：如果提示 "An App ID with Identifier ... is not available"（`com.moodreader.app` 可能已经被别人注册），勾上它，改成 `com.你的名字.moodreader`，重试即可。
- **Advanced Options → Remove limitation on supported devices**：遇到 `DeviceNotSupportedByThinning` 时勾上。
- 建议勾选 **自动刷新 / auto refresh**：之后手机和电脑在同一 Wi-Fi 下，Sideloadly 会在过期前自动帮你重签。

### A-6. 第一次打开 App

1. 手机上会弹出「不受信任的开发者」——正常现象。
2. **设置 → 通用 → VPN 与设备管理 → 开发者 App → 你的 Apple ID → 信任**。
3. 回桌面打开「声笺」，应该能看到三篇示例文章。

> 声音太小或没声音：先确认手机音量；再确认系统里有中文语音——**设置 → 辅助功能 → 朗读内容 → 声音 → 中文**，下载「增强/高级」语音（婷婷、小晓等）后，在 App 的「朗读设置」里选它，情绪起伏会明显更好。

### A-7. 7 天之后怎么办

免费 Apple ID 签的 App，**7 天后打不开**（不是删了，是证书过期）。三个办法：

| 办法 | 操作 | 代价 |
| --- | --- | --- |
| 自动续签 | 保持 Sideloadly 在后台、手机同 Wi-Fi（或插着数据线） | 电脑得偶尔开着 |
| 手动重签 | 重复 A-5：同一个 IPA、同一个 Apple ID、**同一个 Bundle ID** 覆盖安装 | 1 分钟；本地数据保留 |
| 升级路线 B | 付费账号签一年，或走 TestFlight | $99/年 |

其他可选工具：**SideStore / AltStore**（Windows 上装 AltServer，走 Wi-Fi 配对自动续签，原理相同，也是 7 天）；**爱思助手**的中文界面也能签，但广告和捆绑较多。原理都一样：免费证书 7 天。

### A-8. 免费账号的硬限制（先知道，少踩坑）

| 限制 | 数值 |
| --- | --- |
| 证书/描述文件有效期 | 7 天 |
| 同时安装的自签 App | 3 个 |
| 每 7 天可创建的 App ID | 10 个 |
| 后台音频、锁屏控制 | **不受限**，`UIBackgroundModes: audio` 写在 Info.plist 里，免费签名同样生效 |
| 能否上架 App Store | 不能 |

### A-9. Sideloadly 常见报错对照

| 报错 | 原因与处理 |
| --- | --- |
| `Call to np_client_new failed: NP_E_CONN_FAILED` / `AFC_E_MUX_ERROR` | 装了 Microsoft Store 版 iTunes。卸载，装官网版 |
| `LOCKDOWN_E_INVALID_HOST_ID` | 没点「信任」。插着线重启电脑，打开 iTunes 同步一次 |
| `Your maximum App ID limit has been reached...up to 10 App IDs every 7 days` | 免费账号限制。等几天，或换一个 Apple ID |
| `This device has reached the maximum number of installed apps using a free developer profile` | 免费账号最多 3 个自签 App，删掉其他的 |
| `Untrusted Developer` | 设置 → 通用 → VPN 与设备管理 → 信任 |
| `Installation failed: 0 InstallProhibited` | 屏幕使用时间限制：设置 → 屏幕使用时间 → 内容和隐私访问限制 → iTunes Store 与 App Store 购买 → 安装 App → 允许 |
| `DeviceNotSupportedByThinning` | 勾 Advanced Options → Remove limitation on supported devices |
| `The identity used to sign the executable is no longer valid` | 电脑/手机时间不对，校准后重试 |
| 装完桌面没有图标 | 重启手机 |
| 一直搜不到设备 | 换数据线/换 USB 口；确认 iTunes 里能看到设备 |

---

## 3. 路线 B：$99/年 + TestFlight（长期方案，无需数据线）

适合：想长期用、想给朋友测、不想每 7 天续签。

1. **注册**：<https://developer.apple.com/programs/> → 个人账号 $99/年（约 ¥688），通常 1–2 天通过。
2. **建 App 记录**：<https://appstoreconnect.apple.com> → 我的 App → **+** → 新建 App。Bundle ID 先在 *Certificates, Identifiers & Profiles* 里注册，例如 `com.你的名字.moodreader`，并对应修改工程里的 `PRODUCT_BUNDLE_IDENTIFIER`。
3. **生成上传密钥**：App Store Connect → 用户和访问 → 集成 → App Store Connect API → 生成密钥（Key ID + Issuer ID + 只给下载一次的 `.p8`）。
4. **CI 自动签名并上传**（二选一）：
   - **Codemagic**（推荐，个人免费 500 分钟/月）：用 GitHub 登录 → 添加本仓库 → 在 Code signing 里填上 API Key，Codemagic 会自动创建证书和描述文件并上传 App Store Connect。官方文档：<https://docs.codemagic.io/yaml-code-signing/signing-ios/>
   - **GitHub Actions + fastlane**：在 workflow 里加一步 `fastlane pilot`，用 API Key 走 `cert`/`sigh` 自动签发。
5. **手机安装**：App Store 搜 **TestFlight** → 用同一个 Apple ID 登录 → 接受内测邀请 → 安装「声笺」。

注意：

- 每个 TestFlight 构建 **90 天**过期，续期只要再传一版；每次上传必须把 `CFBundleVersion`（build 号）加一。
- 过期不会立刻影响手机上的已装版本，但 TestFlight 会提示。把 build 号写成日期（如 `2026111901`）最省事。

---

## 4. 路线 C：租一台云 Mac（要真正在 Xcode 里调 UI 时）

Windows 无法运行 iOS 模拟器，但你可以远程操作一台云端 macOS：

| 服务 | 计费 | 备注 |
| --- | --- | --- |
| [MacinCloud](https://www.macincloud.com/) | 按小时约 $1 起，或月付 | 有预装 Xcode 的镜像，最省事；支持 RDP |
| [Scaleway Apple silicon](https://www.scaleway.com/en/mac-mini/) | 按小时约 €0.10 起 | 便宜，需要自己装 Xcode |
| [AWS EC2 mac](https://aws.amazon.com/ec2/instance-types/mac/) | $0.65/小时起，**最短 24 小时** | 适合一次性大任务 |
| [MacStadium](https://www.macstadium.com/) | 月付 | 团队用得多 |

操作要点：

1. Windows 上用 **Microsoft Remote Desktop**（RDP）或 VNC 连上去；文件通过云盘/网盘传。
2. 首次打开 Xcode 会自动生成 scheme（本仓库我已补了共享 scheme，省这一步）。
3. 选 **MoodReader** target → Signing & Capabilities → Team 选你的 Apple ID（免费账号会出现 "Personal Team"）→ 选模拟器 → `Cmd + R`。
4. **云 Mac 没法插 USB 真机**，所以真机只有两条路：TestFlight（需要付费账号）或 Ad Hoc（需要付费账号 + 登记 UDID）。免费账号在云 Mac 上只能跑模拟器。

模拟器能测什么：界面布局、点击跳句、书签弹窗、字体、断句高亮、ShareLink/文件导入。
模拟器测不了：真实音色、锁屏/后台播放、来电打断、Now Playing 控件。音频经过远程桌面也可能卡顿失真。

---

## 5. 路线 D：买一台二手 Mac mini（打算长期做 iOS 的话）

云 Mac 适合偶尔用，长期做开发更划算的是一台自己的 Mac：

- **配置**：M1 / 8G / 256G，二手约 ¥1500–2500；预算够就上 16G——Xcode 加模拟器很吃内存。
- **系统要求**：Xcode 16 需要 macOS 14.5（Sonoma）或更新；如果你打算装更新的 Xcode，买之前按那个版本的系统要求核对一下卖家机器的系统版本。
- **买回来做三件事**：App Store 装 Xcode → 打开 `MoodReader.xcodeproj` → Signing 里选 Personal Team，插上数据线 `Cmd + R`。
- **比云 Mac 好在哪**：模拟器不卡、能插真机调试（断点、控制台、Instruments）、免费 Apple ID 也能装到手机上（同样是 7 天）。
- **不推荐**：2015 年以前的 Intel 机型，跑不动新 Xcode，也别指望模拟器流畅。

---

## 6. 路线 E：完全不碰 Apple 账号的两个玩法

### E-1. 浏览器里的 iOS 模拟器（Appetize.io）

1. 在 GitHub Actions 里手动运行 workflow，勾选 **build_simulator_app**。
2. 下载 artifact **MoodReader-simulator-app**，解压得到 `MoodReader-simulator.app.zip`（注意：Appetize 只接受模拟器构建的 `.app.zip`，不接受 `.ipa`）。
3. 打开 <https://appetize.io/> 上传，浏览器里就能点。
4. 免费额度：30 分钟/月，单次会话 3 分钟。音视频在浏览器里不一定能出声，主要用来看界面和交互。

### E-2. 把网页版装到 iPhone 主屏（PWA）

`demo/` 是一个完整的网页版，可以用 GitHub Pages 免费托管：

1. 仓库 Settings → **Pages** → Source 选 **Deploy from a branch** → 分支 `main`、目录 `/ (root)` → Save。
2. 等 1 分钟，访问 `https://你的用户名.github.io/MoodReader/demo/`。
3. iPhone 用 **Safari** 打开该地址 → 分享 → **添加到主屏幕**。

限制（与原生版的最大差距）：iOS 的 Web Speech API 在**锁屏或切到后台后会停止朗读**，也没有锁屏控制；离线能力取决于浏览器缓存。所以它只适合"先看看长什么样"，真要通勤听书还是得原生版。

---

## 7. 装到真机后，按这张表验收

| # | 测试项 | 期望结果 |
| --- | --- | --- |
| 1 | 首次启动 | 书架出现 3 篇示例文章，无闪退 |
| 2 | 点「继续收听」 | 从上次句子开始读，高亮跟随 |
| 3 | 点正文任意一句 | 从该句开始读，进度条同步 |
| 4 | 长句换气 | 逗号处有明显停顿，不是一口气读完 |
| 5 | 暂停/继续 | 暂停落在句间也不丢位置 |
| 6 | 上一句 | 第一次回到当前句开头，再按才到上一句 |
| 7 | 锁屏继续播放 | 锁屏后仍有声音，锁屏控件显示书名/进度 |
| 8 | 后台切换 | 切到别的 App 仍继续朗读 |
| 9 | 来电/闹钟打断 | 自动暂停，结束后恢复 |
| 10 | 收藏书签 + 备注 | 列表按正文顺序排列，点击可跳转 |
| 11 | 杀进程重开 | 回到上次的句子和滚动位置 |
| 12 | 新建/导入 | 粘贴文本、导入 UTF-8 与 GB18030 的 `.txt` 均正常 |
| 13 | 朗读设置 | 切换声音、语速、语气立即生效 |
| 14 | 增强语音 | 下载「增强」中文语音后，语气明显更自然 |

前 6 项和 10–13 项在模拟器/网页版也能过；7–9 必须真机。

---

## 8. 云端编译失败时怎么查

1. Actions 里点开失败的 run → 展开 **编译（真机 Release，不签名）** 这一步。
2. 或者下载 artifact **build-log**，搜 `error:`（workflow 里也会把 error 行单独 grep 出来贴在日志末尾）。
3. 对照常见原因：

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| `does not contain a scheme named "MoodReader"` | 没有共享 scheme | 已在本仓库补上 `xcshareddata/xcschemes/MoodReader.xcscheme`，确认它被提交了 |
| `The project ... cannot be opened because it is in a future Xcode project file format` | 工程是 objectVersion 77（Xcode 16 格式） | 必须 Xcode 16+；本 workflow 用 `macos-15`，默认 Xcode 16，满足 |
| `Signing for "MoodReader" requires a development team` | 签名没关掉 | workflow 已设 `CODE_SIGNING_ALLOWED=NO`，别手动删这几行 |
| `Cannot find 'xxx' in scope` / `value of type ... has no member` | 源码里的编译错误 | 这是真错误，按行号改代码；日志里有完整上下文 |
| Swift 6 并发报错（`actor-isolated` / `Sendable`） | 有人把 SWIFT_VERSION 改成了 6 | 保持 `SWIFT_VERSION = 5.0`（本工程就是 5.0） |
| 构建成功但装到手机闪退 | Info.plist 缺键 / 资源缺失 / 真机架构不对 | 看 Xcode Devices and Simulators 的 Console，或手机上「设置 → 隐私与安全性 → 分析与改进 → 分析数据」里的崩溃日志 |

> 这个工程此前**从未真正编译过**（README 第 8 节也写了）。第一次上 CI 大概率会暴露几个小错误，属于正常现象——按日志改就行。
>
> 我另外做了一遍逐文件静态审计（14 个 Swift 文件 + Info.plist + pbxproj），**没有发现必然导致编译失败的 Swift 级缺陷**；跨文件符号、memberwise init、`AVSpeechSynthesizerDelegate` 五个回调签名、`MPNowPlayingInfoCenter`/`MPRemoteCommandCenter` 的键名、`fileImporter`/`onChange(of:)` 的新签名都与 Xcode 16 / iOS 17 一致。唯一的已知隐患是**并发**：`ReaderView` 把 `@MainActor` 闭包塞进非隔离回调、`DispatchQueue.main.asyncAfter` 里改 `@State`、`NotificationCenter` 的 `@Sendable` block 捕获 `self`——这些在 **Swift 5 模式只是 warning，在 Swift 6 / 严格并发下会变成 error**。所以：**不要把 `SWIFT_VERSION` 改成 6.0，也不要在 Xcode 里打开 Strict Concurrency Checking → Complete**。

---

## 9. 这个仓库为 Windows 开发增加了什么

| 文件 | 作用 |
| --- | --- |
| `.github/workflows/ios-build.yml` | 在 GitHub 的 macOS 机器上编译，产出未签名 IPA（可选产出模拟器 `.app.zip`） |
| `MoodReader.xcodeproj/xcshareddata/xcschemes/MoodReader.xcscheme` | 共享 scheme，`xcodebuild -scheme MoodReader` 必需；Xcode 打开工程也不会再问 |
| `Docs/Windows11-测试与装机.md` | 本文 |

本机（Windows 11）已验证的部分：

- `node demo/segmenter.test.js` → `segmenter tests passed`（Node 24）；
- `Info.plist`：`UIBackgroundModes = audio`、`UILaunchScreen`、竖屏限制齐全；
- 资源：`AppIcon` 是 Xcode 16 的单尺寸 1024 图，`AccentColor` 存在；
- 部署目标 iOS 17.0、`SWIFT_VERSION 5.0`、`TARGETED_DEVICE_FAMILY 1`（仅 iPhone）。

---

## 10. 时间预期

| 阶段 | 耗时 |
| --- | --- |
| 建 GitHub 仓库 + push | 10 分钟 |
| 第一次 CI 构建（含可能的报错修复） | 15–40 分钟 |
| 装 iTunes/iCloud/Sideloadly + 重启 | 20 分钟 |
| 手机开发者模式 + 信任 + 安装 | 5 分钟 |
| 之后每次改代码到手机上更新 | CI 5 分钟 + 签名 1 分钟 |

---

## 11. 一句话总结

**写代码在 Windows，编译在 GitHub 的 macOS（已配好），装在 Windows 上用 Sideloadly 签（免费 7 天），长期用就上 $99 的 TestFlight。** 不需要买 Mac，也不需要 macOS 虚拟机。
