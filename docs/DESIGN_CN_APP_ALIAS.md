# 设计说明：中文应用/动作对齐（MVP）

仓库：`adon68/jev-voice-control`（fork）  
目标：不增强 Jev 模型，只做「中文描述 → 本机应用名 / 动作」解析对齐。

## 问题

说「帮我打开谷歌浏览器」时 `action=openApp` 准，但 `target_app` 对不上安装列表里的 `Google Chrome`，Executor 报 Missing target app。

根因（代码层）：
- `AppMatcher` 只做英文 token 与安装名匹配，无中文别名。
- `SlotExtractor` 浏览器同义词仅英文（chrome/safari…）。
- Jev `target_app` choice 的 criteria 是**英文安装名**；模型选不到「谷歌浏览器」这个选项时，本地 fallback 也匹配不上。

## 1. 放哪一层？

| 方案 | 优点 | 缺点 | 结论 |
|------|------|------|------|
| 只扩 SlotExtractor 启发式 | 改动面小 | 易变成巨型 if/正则，难维护 | 辅助，不主责 |
| **本地别名词典 + AppMatcher 解析** | 确定性、可测、不烧模型、符合「不增强 Jev」 | 需维护词典 | **默认推荐** |
| 给 Jev choice 塞中文选项 | 看似让模型懂中文 | criteria 必须等于安装名；中文键选中后仍要映射；污染选择题 | 不推荐作主路径 |
| 改 Jev 模型 | 超出范围 | — | 不做 |

**推荐默认链路**（在 `CommandInterpreter.interpretClause` 本地覆盖/补全处）：

```
语音文本
  →（可选）中文动词 → Action（打开/关闭/切换…）
  → AppMatcher.resolve(clause, installedApps)
       1) 别名词典：别名/同义词 → 候选规范名
       2) 与 installedApps 精确/模糊对齐（现有 token 逻辑保留给英文）
  → 覆盖或填补 Jev 的 target_app
  → Executor（仍只认本机真实 app 名）
```

Jev 继续负责粗分类（是否 openApp）；**应用名落地以本地解析为准**。

## 2. MVP 数据结构与同义词

```swift
// 建议新文件：Sources/JevVoiceCore/AppAliasCatalog.swift
struct AppAliasCatalog {
  /// alias(lowercased) → preferred display/bundle name hint
  static let aliases: [String: String] = [
    "谷歌浏览器": "Google Chrome",
    "谷歌": "Google Chrome",
    "chrome": "Google Chrome",
    "谷歌chrome": "Google Chrome",
    // …
  ]
}
```

解析规则（MVP）：
1. 在 clause 中找最长别名命中（避免「谷歌」误伤过短）。
2. 映射到 hint 后，在 `installedApps` 里找 case-insensitive 全等；找不到再 `localizedStandardContains`。
3. 命中则 confidence ≥ 0.9，写回 `target_app`。

**应用别名（首批）**

| 中文/口语 | 规范名 |
|-----------|--------|
| 谷歌浏览器、谷歌、Chrome | Google Chrome |
| 苹果浏览器、Safari | Safari |
| 火狐、Firefox | Firefox |
| 备忘录、笔记 | Notes |
| 终端、Terminal | Terminal |
| 访达、Finder | Finder |
| 微信 | WeChat |
| VS Code、代码、Visual Studio Code | Visual Studio Code |
| 企微、企业微信 | 企业微信 / WeChat Work（以本机名为准） |

**动作同义词（首批，写入 AppMatcher.verbs + 中文）**

| 动作 | 中文触发 |
|------|----------|
| openApp | 打开、开启、启动、运行、帮我打开 |
| closeApp | 关闭、退出、关掉、结束 |
| switchApp | 切换到、切到、回到、显示 |
| hideApp | 隐藏 |
| minimizeApp | 最小化、收起来 |

用户词典可后续放到 `~/Library/Application Support/.../app-aliases.json` 热更新；MVP 先内置常量 + 单测即可。

## 3. 实时识别文字 UI

**结论：SwiftUI 完全可行，且大半已有。**

现状：`SpeechRecognizer` 已 `shouldReportPartialResults = true`，`VoiceController` 已订阅 `$transcript`；`ContentView.transcriptSection` 已在 popover 内展示。

建议增强（小改动）：
- Listening 时固定展示「实时识别」区块（更大字号 / 滚动 Text），空态文案区分「正在听…」。
- 可选：底部加 `ScrollView` + monospaced 字幕条，不新开窗口，仍挂在现有 menu-bar popover。
- **不必**新建独立 NSPanel（工作量大、焦点抢占风险高）。

工作量：约 0.5–1 人日。风险：低（只动 UI 绑定，不改识别管线）。

## 4. 落地顺序（第一步做什么）

1. **先加测试**（`AppMatcherTests` / 新 `AppAliasTests`）：  
   - `"打开谷歌浏览器"` + apps 含 `Google Chrome` → target Google Chrome  
   - `"帮我打开Chrome"` → 同上  
   - `"关闭 Safari"` 中英混用  
2. 实现 `AppAliasCatalog` + 扩展 `AppMatcher.match`（别名优先）。  
3. 在 `CommandInterpreter` 本地 fallback/override 处接入（已有 `localMatch` 分支，约 191–212 行附近）。  
4. 补中文动词表。  
5. UI：强化 `transcriptSection` 实时展示。  
6. 交付说明交给测试席位：用例表 + 本机需已安装 Google Chrome。

**本步不改**：Jev 模型、Executor 启应用逻辑、无关系统动作。

## 改动模块清单

| 模块 | 改动 |
|------|------|
| `JevVoiceCore/AppAliasCatalog.swift` | 新增 |
| `JevVoiceCore/AppMatcher.swift` | 别名 + 中文动词 |
| `JevVoiceCore/CommandInterpreter.swift` | 解析结果覆盖 target_app |
| `JevVoice/ContentView.swift` | 实时字幕强化（可选同 PR） |
| `Tests/JevVoiceTests/AppMatcherTests.swift` | 中文用例 |

## 验收（给测试）

- [ ] 说「打开谷歌浏览器」→ 打开 Google Chrome，无 Missing target app  
- [ ] 说「打开 Chrome」→ 同上  
- [ ] 说「关闭备忘录」→ 关闭 Notes（若已装）  
- [ ] Listening 时 popover 可见实时识别文字更新  
