# 手把手：把「声笺」装到你的 iPhone 上

> 写给完全没做过 iOS 的人。你不需要懂 Xcode、不需要 Mac、不需要写代码。
> 全部操作在 **Windows 11 + iPhone 数据线** 上完成，约 40 分钟（其中 20 分钟是等下载和等编译）。
>
> 全程只有两样东西必须是“你的”：**GitHub 账号**（用来跑免费的云编译）和 **Apple ID**（用来签名装机）。别的我都能提前替你准备好。

---

## 开工前，先确认三件事

| 检查 | 在哪里看 | 要求 |
| --- | --- | --- |
| iPhone 系统版本 | 手机：设置 → 通用 → 关于本机 → 软件版本 | **iOS 17.0 或更高**。低于 17 先跟我说，我把最低版本改低再重新构建 |
| 一根能传数据的线 | 盒子里的原装线最稳 | 只能充电的劣质线会连不上电脑 |
| 电脑能上网 | 打开浏览器 | GitHub 和苹果的下载站要能访问 |

另外确认你的 Apple ID 开了**双重认证**（绝大多数人都开了）：手机上 设置 → 点最上面的你的名字 → 密码与安全性。没开的话先去 [appleid.apple.com](https://appleid.apple.com) 开，否则签名会失败。

---

## 第 1 步：准备 GitHub 账号（3 分钟）

1. 浏览器打开 <https://github.com>。
2. 有账号就直接登录；没有就点 **Sign up** 注册（邮箱 + 密码 + 验证邮件，免费）。
3. 登录后，点右上角 **+** → **New repository**。
4. 填写：
   - **Repository name**：`MoodReader`（大小写要一致，后面命令里也用这个名字）
   - 下面三个勾选项（Add a README / .gitignore / license）**全部不勾**
   - 可见性选 **Public**（公开。公开仓库的 macOS 编译免费，私有仓库每月只有 200 分钟额度）
5. 点最下面绿色 **Create repository**。

你会看到一个空仓库页面，上面写着 "Quick setup"。**先别动它**，去下一步。

> ✅ 检查点：浏览器地址栏是 `https://github.com/你的用户名/MoodReader`

---

## 第 2 步：把工程传上去（5 分钟）

1. 点开始菜单，搜 **PowerShell**，打开 **Windows PowerShell**。
2. 把下面整段**一次性**复制进去，**先把两处占位符改成你自己的**，再按回车：

```powershell
cd "G:\ios阅读器"
git config user.name "你的GitHub用户名"
git config user.email "你的GitHub邮箱"
git commit --amend --reset-author --no-edit
git remote add origin https://github.com/你的GitHub用户名/MoodReader.git
git push -u origin main
```

举例：如果你的 GitHub 用户名是 `zhangsan`，第三行就是 `git config user.name "zhangsan"`，第五行就是 `https://github.com/zhangsan/MoodReader.git`。

**接下来会发生什么：**

- 第五行回车后，会**弹出一个浏览器窗口**，标题类似 "Sign in to GitHub"，让你登录 GitHub 并点 **Authorize**。这是 Windows 自带的 Git 凭据管理器，正常现象，点同意即可。
- 授权完回到 PowerShell，会刷出一堆 `Writing objects...`，最后显示 `branch 'main' set up to track 'origin/main'`。
- 刷新浏览器里的仓库页面，能看到 `MoodReader`、`Docs`、`.github` 这些文件夹。

**如果报错：**

| 报错 | 原因 | 怎么办 |
| --- | --- | --- |
| `remote origin already exists` | 之前加过 | 先执行 `git remote set-url origin https://github.com/你的用户名/MoodReader.git` 再 push |
| `Authentication failed` | 没有授权成功 | 再执行一次 `git push -u origin main`，重新弹窗授权 |
| `repository not found` | 地址写错 / 仓库名不一致 | 对照浏览器地址栏，仓库名必须是 `MoodReader`，用户名不能拼错 |
| `nothing to commit` | 正常，说明已经提交过 | 忽略，继续 push |

> ✅ 检查点：GitHub 网页上能看到 `MoodReader`、`Docs`、`.github` 这些文件夹

---

## 第 3 步：让云端的 Mac 帮你编译（等 8–12 分钟，不用看着）

1. 浏览器打开 `https://github.com/你的用户名/MoodReader/actions`
2. 左边栏点 **iOS Build**。
3. 右边会有一个灰色按钮 **Run workflow**，点它 → 再点绿色 **Run workflow** 确认。
4. 页面刷新后，列表最上面出现一条记录，前面是**黄色小圆点**（运行中）。
5. 等 8–12 分钟，圆点变成**绿色对勾** = 编译成功。

**下载成品：**

6. 点进这条记录 → 页面**最下面**有 **Artifacts** 区域 → 点 **MoodReader-unsigned-ipa**，会下载一个 `MoodReader-unsigned-ipa.zip`。
7. 在 Windows 里解压这个 zip，得到 **`MoodReader-unsigned.ipa`**（这就是要装到手机的安装包）。

**如果圆点变成红色叉（编译失败）：**

- 点进去 → 左边点 **build** → 展开 **编译（真机 Release，不签名）** 这一步 → 往下拉到第一条 `error:` 开头的内容。
- **把那段错误复制粘贴给我**（在这个对话里发给我就行），我改代码，你再点一次 Run workflow。
- 这个工程从来没被编译过，第一次报几个错是很正常的，别慌，也别自己改。

> ✅ 检查点：你手上有一个 `MoodReader-unsigned.ipa` 文件（约几 MB）

---

## 第 4 步：在电脑上装三个软件（20 分钟，包含重启）

> 关键：**必须用苹果官网的版本，不能用微软商店的版本**。商店版被沙盒锁住，签名必定失败。

1. **卸载商店版（如果装过）**：设置 → 应用 → 已安装的应用 → 搜 `iTunes`、`iCloud` → 有就卸载。
2. **装 iTunes（官网版）**：打开 <https://www.apple.com/itunes/download/win64> → 下载 `iTunes64Setup.exe` → 右键 → **以管理员身份运行** → 一路下一步。
3. **装 iCloud（官网版）**：打开
   <https://updates.cdn-apple.com/2020/windows/001-39935-20200911-1A70AA56-F448-11EA-8CC0-99D41950005E/iCloudSetup.exe>
   → 运行 → 一路下一步。
4. **装 Sideloadly**：打开 <https://sideloadly.io/> → 点 **Windows** 下载 → 运行安装包 → 下一步到底。
5. **重启电脑**（重要，让苹果的 USB 驱动生效）。

重启后，插上 iPhone，打开 iTunes，左侧栏能看到手机图标，就说明驱动正常。

> ✅ 检查点：iTunes 里能看到你的 iPhone

---

## 第 5 步：手机上做两件事（2 分钟）

1. **信任这台电脑**：插线后手机会弹「要信任此电脑吗？」→ 点 **信任** → 输入手机锁屏密码。
   （没弹？拔了重插一次。还不行？换一根线或换个 USB 口。）
2. **开发者模式**：iOS 16 以后装第三方 App 必须开。路径是
   **设置 → 隐私与安全性 → 拉到最下面 → 开发者模式 → 打开开关 → 重启手机**。
   重启后第一次解锁时，会再弹一次确认，点「打开」。

> ⚠️ 如果你在设置里**找不到「开发者模式」这一项**：不用急，先跳到第 6 步试装——第一次安装被拒绝之后，这一项才会出现。到时候回来开、重启、再装一次就行。

---

## 第 6 步：签名并安装（3 分钟，这一步必须你亲手做）

1. 电脑上打开 **Sideloadly**。
2. 顶部 **Device** 下拉框里应该出现你的 iPhone 名字（看不到就拔插一次，或先打开 iTunes）。
3. 把 `MoodReader-unsigned.ipa` **拖进** Sideloadly 窗口上半部分的虚线框（或点 **IPA** 图标选择文件）。
4. 在 **Apple ID** 输入框里填你的 Apple ID（就是手机上 设置 → 顶部你的名字 那个邮箱）。
5. 点右下角的 **Start**。
6. 会弹窗要你输 **Apple ID 密码**，然后要你输手机上收到的 **6 位双重认证验证码**。
7. 等 30–60 秒：Sideloadly 会创建证书、装好 App。

**如果报错，先看这里：**

| 提示 | 怎么办 |
| --- | --- |
| `Developer Mode Required` / 要求开发者模式 | 回第 5 步第 2 条开启，重启手机，再点 Start |
| `Call to np_client_new failed` 或 `AFC_E_MUX_ERROR` | 你装的是微软商店版 iTunes。卸载，装第 4 步给的官网版，重启 |
| `LOCKDOWN_E_INVALID_HOST_ID` | 手机没点信任。插着线重启电脑，打开 iTunes 同步一次 |
| `An App ID with Identifier 'com.moodreader.app' is not available` | 这个 Bundle ID 被别人占了。点 Sideloadly 的 **Advanced Options**，勾选 **Change Bundle ID**，填 `com.你的名字.moodreader`，重新 Start |
| `maximum number of installed apps using a free developer profile` | 免费账号最多 3 个自签 App。删掉手机里其他自签 App |
| `maximum App ID limit has been reached...10 App IDs every 7 days` | 免费账号限制，等几天，或换一个 Apple ID |

> ✅ 检查点：手机桌面上出现「声笺」图标

---

## 第 7 步：信任这个 App，打开它（1 分钟）

1. 手机上：**设置 → 通用 → VPN 与设备管理 → 开发者 App**（App Developer）
2. 点里面的 **你的 Apple ID**（邮箱）→ 再点 **信任"..."** → 确认信任。
3. 回到桌面，点「声笺」打开。

第一次打开看到「书架」和三篇文章，就成功了。

> 点开就闪退？先重启手机；还闪退就把具体现象告诉我。

---

## 第 8 步：验收（照着点一遍，10 分钟）

| 点哪里 | 应该发生什么 |
| --- | --- |
| 点「继续收听」卡片 | 有声音，当前句变黄高亮 |
| 点正文里任意一句 | 从那一句开始读 |
| 点播放器中间的暂停/播放 | 停在这一句，再点继续 |
| 按手机侧边键锁屏 | **还有声音**，锁屏界面显示书名和播放控件（这是网页版做不到的） |
| 切到别的 App | 朗读继续 |
| 点播放器右上角书签图标 | 提示「已收藏这一句」 |
| 把 App 从后台划掉再打开 | 回到上次读到的那一句 |

**想让声音更好听**：手机 设置 → 辅助功能 → 朗读内容 → 声音 → 中文 → 下载「增强」或「高级」语音（如婷婷、小晓），然后回 App 里点「朗读设置」选中它。

---

## 第 9 步：7 天之后（必看）

用免费 Apple ID 签的 App，**7 天后会打不开**（提示「无法验证 App」）。这不是坏了，是证书过期。

**重新签一次就好，数据不会丢：**

1. 插线，打开 Sideloadly。
2. 还是那个 `MoodReader-unsigned.ipa`、同一个 Apple ID、同一个 Bundle ID（如果你改过，还要用改过的那个）。
3. 点 Start，走一遍第 6 步。
4. 手机上 App 直接更新，进度和书签都还在。

**不想每 7 天折腾的三个选择：**

- 在 Sideloadly 里勾选 **自动刷新**（Advanced Options 里），之后它会在过期前自动帮你重签（需要电脑开着、手机在同一 Wi-Fi 或插着线）。
- 升级到付费开发者账号（$99/年），签名一次管一年，还能用 TestFlight 装到更多手机上，不用数据线。
- 改用网页版长期听（不用再签名，但锁屏会停，见 `demo/`）。

---

## 一页速查

```text
GitHub 建仓库 → PowerShell 里 push → Actions 点 Run → 下载 IPA
   ↓
装官网 iTunes + iCloud + Sideloadly → 重启
   ↓
手机信任电脑 → 开开发者模式 → Sideloadly 填 Apple ID → Start
   ↓
手机 设置→通用→VPN与设备管理→信任 → 打开 App
   ↓
7 天后重复最后两步
```

卡在哪一步，把**屏幕上的原话**（截图或复制报错）发我，我接着往下带。
