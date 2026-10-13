# 电话簿 · iPhone 本地 App

这是独立安装在自己 iPhone 上的单机应用，默认使用简体中文和浅色界面。通话记录、通讯录、收藏和设置都保存在 App 自己的资料库里；日常使用不需要网络或账号。应用使用 SwiftUI 原生列表、导航、搜索、表单与标签栏，在 iOS 26 上由系统提供相应的外观。

可新增、修改、复制、删除通话记录，编辑联系人姓名、电话号码、日期、时间、时长与通话状态；可管理本地联系人和收藏、拨号、查看详情、搜索和筛选未接来电。拨号后的界面有计时、静音、免提、键盘、添加通话、切换、合并和挂断交互，全部在 App 内完成，不建立真实电话连接。提供 JSON 备份导出与导入。这里的记录不会写入 iPhone 系统电话 App。

## 当前交付状态

- 已提供原生 Swift 源码、可直接打开的 Xcode 工程、数据层测试和手动云编译流程。
- 当前电脑是 Windows，未运行 Xcode、未生成经过验证的 IPA，也未在你的 iPhone 上验收。界面相似程度还需要在实机上对照确认。
- 工程最低支持 iOS 18，目标设备为 iPhone，竖屏；编译工具为 Xcode 26。桌面名称为「电话簿」，Bundle ID 为 `com.personal.calljournal`。
- 无通讯录、麦克风、相机、位置、通知或后台权限声明，无联网代码和第三方运行时依赖。
- 已在 Windows 的 WSL 环境使用 Swift 6.0.3 编译数据层并运行 27 项 XCTest，全部通过；原生页面的 Swift 语法检查通过。这不等同于使用 Apple SDK 完成 iOS 编译。
- 浏览器预览已检查完整字段编辑、保存后刷新、搜索/未接筛选、联系人改名/删除后的历史保留、拨号及挂断保存。预览与原生 App 的资料库独立。

## 先在 Windows 预览

双击 `Preview/index.html`，可在浏览器中体验通话列表、编辑、联系人、拨号和备份等主要操作。也可在本目录运行 `python -m http.server 8765 --directory Preview`，然后打开 `http://127.0.0.1:8765`。预览没有依赖下载，数据保存在这个浏览器的本地存储中。

浏览器预览用于检查流程，原生 iPhone App 的界面由 SwiftUI 渲染，两者资料库独立。iOS 26 的系统标签栏、表单、日期选择器与键盘需要在原生编译后验收。

## 只有 Windows，怎样装到 iPhone

编译 iOS 原生 App 仍需要 Apple 的 Xcode 工具链。你不用购买或借用 Mac：可以让 GitHub Actions 的 macOS 机器编译源码，再用 Windows 给生成的 IPA 签名、安装。云编译需要网络；安装成功后 App 本身可以离线使用。

### 1. 准备源码仓库

1. 注册或登录你自己的 GitHub 账号，创建一个 **Private（私有）** 仓库。
2. 用 GitHub Desktop 克隆这个仓库到 Windows。将本文件所在的 `CallJournal` 文件夹内的全部内容复制到仓库根目录，包括隐藏的 `.github` 文件夹。不要在仓库根目录外层再套一层 `CallJournal`。
3. 在 GitHub Desktop 提交文件，并点击 Push origin。仓库根目录应直接看到 `CallJournal.xcodeproj`、`CallJournal`、`Sources`、`Tests`、`scripts`、`Package.swift` 和 `.github`。

源码可上传；联系人、通话记录、JSON 备份、Apple 账号密码、验证码、证书和签名文件不应提交到仓库。这个编译流程不要求配置 Apple 凭据或 GitHub Secrets。私有仓库的 GitHub Actions 用量和 macOS 计费规则由你的 GitHub 套餐决定，启动前可在 GitHub 的 Billing 页面查看剩余额度。

### 2. 手动编译并下载

1. 在仓库网页打开 **Actions → Build iPhone App → Run workflow → Run workflow**。
2. 等待所有步骤成功，打开这次运行页面。
3. 在 **Artifacts** 下载 `CallJournal-unsigned-iphone`，解压后取得 `CallJournal-unsigned.ipa`。

工作流支持手动启动；主分支的原生代码、测试、工程或构建脚本更新也会触发编译。它会选择 runner 上稳定的 Xcode 26，先校验工程并运行 `swift test`，再编译 iPhone Release 包。若失败，打开红色步骤查看具体错误；失败的运行不会作为成功安装包交付。这个 IPA 尚未签名，不能直接点击安装到 iPhone。

### 3. 在 Windows 签名安装

1. 从 [Sideloadly 官网](https://sideloadly.io/) 下载 Windows 版。按官网的 Windows 前置要求安装其链接的网页版 iTunes 和 iCloud；如果已有 Microsoft Store 版，按其说明处理版本冲突。
2. 用 USB 数据线连接 iPhone，解锁手机，在手机上点击「信任此电脑」。打开 Sideloadly，确认它已识别你的 iPhone。
3. 把 `CallJournal-unsigned.ipa` 拖进 Sideloadly。仅在你自己电脑的 Sideloadly 中输入自己的 Apple 账号，按提示完成登录与验证码。不要把密码或验证码发进聊天或仓库。
4. 点击 Start，等待签名和安装完成。首次安装若提示未受信任的开发者，前往 iPhone「设置 → 通用 → VPN 与设备管理」信任对应账号。
5. 如果提示需要开发者模式，前往「设置 → 隐私与安全性 → 开发者模式」启用，按系统提示重启并确认，再打开桌面上的「电话簿」。如果该选项暂时没有出现，先完成设备连接及安装尝试，再按提示查看。

Sideloadly 官方提供 Windows 安装、账号签名、信任开发者与开发者模式的说明：[官方 FAQ](https://sideloadly.io/faq.html)。Apple 的开发者模式说明见 [Enable Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)。这是需要实际在你设备上执行并验证的安装路径，目前没有替你安装过。

### 4. 免费账号的续签与备份

普通 Apple 账号可以用于个人设备签名；免费个人团队的签名有效期为 **7 天**，每台设备最多同时安装 **3 个**此类 App。到期前需要续签，可用 Sideloadly 的自动刷新；电脑需运行相关程序，并通过 USB 或已配对的 Wi-Fi 检测到手机。规则见 [Apple 个人团队说明](https://developer.apple.com/help/account/basics/about-your-developer-account) 与 [Sideloadly 自动刷新说明](https://sideloadly.io/faq.html)。

刷新或更新时始终使用同一个 Apple 账号和相同 Bundle ID，覆盖现有 App。**先在 App 设置里导出 JSON 备份，并把文件保存到 App 之外。** 不要为了续签先卸载 App；卸载会移除本地资料。更换账号、改 Bundle ID、卸载重装或导入备份之前，也应先备份。导入会替换当前资料库，请先保存现有数据。

## 使用入口

- 首页进入通话列表。右上角「+」可添加通话，旁边菜单可清空记录和打开设置。
- 在统一布局点击记录查看详情；经典布局点击详情按钮查看详情，点击记录进入拨号。长按记录可编辑、复制为新记录或复制号码；向左滑可删除。
- 在「通讯录」添加或编辑本地联系人，也可加入个人收藏。
- 「拨号键盘」输入号码后点击拨号，进入本地通话交互；挂断后保存相应记录。
- 经典布局保留「语音留言」标签，当前显示空列表；可以设置本地语音信箱号码并进入 App 内通话页，不连接真实运营商语音信箱。
- 设置可切换列表布局、外观，并导出或导入资料库备份。

首次启动资料库为空，添加自己需要的联系人和通话记录即可。姓名和电话可以保存在联系人中；通话记录还可单独填写显示姓名。

## 工程与开发验证

```text
CallJournal/                 SwiftUI 页面、App 状态、图标资源
Sources/CallJournalCore/      模型、校验、JSON 备份、本地文件存储
Tests/CallJournalCoreTests/   数据层测试
CallJournal.xcodeproj/        iPhone 原生工程与共享 scheme
scripts/                     工程校验、Xcode 选择、未签名 IPA 打包
.github/workflows/           手动 GitHub Actions 编译
```

Xcode 工程使用同步文件组自动包含两个源码目录，不需要每增加一个 Swift 文件就更新工程。数据层同时通过 Swift Package 单独测试，App target 直接编译这些模型文件，无外部 package 下载。

在 Windows 可运行 `python scripts/validate-project.py` 检查工程引用、设备设置、Info.plist、共享 scheme 与图标资源。这个检查不能代替 iOS 编译。

已执行的数据测试覆盖：字段范围、未接/已取消通话的零时长、按日期排序、联系人改名和历史号码保留、删除联系人时保留历史姓名、搜索、JSON 往返、文件大小限制、损坏资料库恢复，以及写入失败时保留旧数据。

在有 Xcode 26 的 macOS 机器上，进入仓库根目录运行：

```bash
swift test
bash scripts/build-unsigned-ipa.sh
```

或者打开 `CallJournal.xcodeproj`，选择 `CallJournal` scheme 和 iPhone 模拟器进行界面验证。连接自己的 iPhone 调试时，在 Xcode「Signing & Capabilities」中选择自己的 Personal Team。

第一次安装后的重点验收：编辑并保存一条完整记录，关闭并重开确认保留；检查姓名、号码、来电/去电/未接状态、日期、时间和时长；检查详情、搜索、收藏、拨号键盘、通话各按钮；导出备份，添加一条临时数据，再导入确认恢复。还需对照你 iPhone 的系统电话页面检查字号、间距、底部标签栏、键盘与系统日期控件。

安装资料核对日期：2026-10-13。GitHub runner 自带 Xcode 会变化；脚本如果找不到 Xcode 26 会明确停止。runner 工具清单可查 [GitHub 官方 macOS 26 镜像说明](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md)。
