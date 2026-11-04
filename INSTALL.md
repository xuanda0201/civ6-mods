# Steam 版文明 6：本地安装

本项目的 Mod 可以作为本地模组使用，无需发布或订阅创意工坊；独立领袖仍需要安装并启用前置模组和 DLC。

## 1. 下载并解压

下载 [完整安装包（六个 Mod）](bundles/civ6-mods-complete.zip)，包含以下五个便利功能，以及独立领袖 `YangGuangRework`。如果只需要便利功能，可下载 [五个便利功能合集](bundles/civ6-mods-preview.zip)。如果是在 GitHub 文件页面，点击 Download raw / 下载原始文件。

解压后包含五个可安装目录：

```text
InfiniteProjects/
SpyRepeat/
BuilderAuto/
AutoTheme/
RailAuto/
```

可以全部安装，也可以只选需要的。AutoTheme 已包含最新 0.2.0。

## 2. 复制到用户 Mods 目录

先退出文明 6。将上述五个目录复制到游戏的用户 `Mods` 文件夹中；没有 `Mods` 就创建。不要放进 Steam 游戏本体的 `steamapps/common` 或 `Assets` 目录，也不要覆盖工坊订阅目录。

Windows 通常是：

```text
C:\Users\你的用户名\Documents\My Games\Sid Meier's Civilization VI\Mods
```

如果文档使用 OneDrive 或被重定向，请打开实际的「文档」目录，再进入 `My Games`。

Mac Steam 版通常是：

```text
~/Library/Application Support/Sid Meier's Civilization VI/Mods
```

Finder 按 `Command + Shift + G`，粘贴路径即可前往。部分 Mac 版本的数据目录曾迁移至同名内层文件夹；如果外层安装后不显示，检查：

```text
~/Library/Application Support/Sid Meier's Civilization VI/Sid Meier's Civilization VI/Mods
```

以当前游戏实际使用的数据目录为准，不要在两个位置同时保留重复副本。

安装后应直接看到 `.modinfo` 文件，例如：

```text
Mods/
├── InfiniteProjects/InfiniteProjects.modinfo
├── SpyRepeat/SpyRepeat.modinfo
├── BuilderAuto/BuilderAuto.modinfo
├── AutoTheme/AutoTheme.modinfo
└── RailAuto/RailAuto.modinfo
```

不要变成 `Mods/AutoTheme/src/AutoTheme/AutoTheme.modinfo`。若已装旧版，请替换同名 Mod 文件夹，保持只安装一份。

## 3. 游戏中启用

1. 从 Steam 启动文明 6。
2. 主菜单进入「额外内容 → 模组」。
3. 按需启用「无限循环项目」「间谍任务循环」「建造者自动作业」「巨作一键整理」「沿途自动铺铁路」。
4. 同时启用原先使用的和而不同及其必需模组。
5. 首次请开单机新局验证。带 Gameplay 保存脚本的项目（包括 RailAuto）不保证能向旧存档后加启用。

所有开关默认关闭。不要同时让其他自动化模组接管同一城市、间谍或建造者。你原有的商路自动重复 Mod 可以保留。

## 4. 快速使用

| 功能 | 用法 |
| --- | --- |
| 无限循环项目 | 城市先安排一个项目，再点左侧「开启：循环当前项目」 |
| 间谍循环 | 手动派出一次任务，再从「间谍循环」列表开启重复 |
| 建造者自动作业 | 选中建造者，点击右下角标准单位操作栏的建造图标，高亮表示开启，悬停查看状态 |
| 巨作整理 | 在自己的回合点击「一键整理巨作」 |
| 沿途自动铺铁路 | 选中可铺铁路单位，点击右下角标准单位操作栏的道路图标，高亮后正常移动 |

这些是本地安装的预览版，已完成语法和模拟检查，尚未在真实文明 6 / HD 环境中验证。若列表不显示，先检查文件夹层级和是否存在重复副本；若游戏内报错，查看当前游戏数据目录中的 `Logs/Lua.log` 和 `Modding.log`。

参考：[文明 6 官方手册的额外内容说明](https://downloads.2kgames.com/civilization/vi/manuals/eu/CIV_VI_25TH_ONLINE_MANUAL_ENG.pdf)、[Aspyr 的 Mac Steam 数据目录迁移说明](https://support.aspyr.com/hc/en-us/articles/19003861040653-Game-Files-Missing-after-update-Civilization-VI-Mac-Steam)。

RailAuto 要求《风云变幻》规则集；沿途施工不额外消耗行动力，资源不足只停施工、不取消移动。兼容范围与游戏/HD 验证状态见 `COMPATIBILITY.md`。

## 可选独立领袖

“杨广·通济四海”包含在六个 Mod 的完整安装包中，也提供单独安装包 `YangGuangRework/dist/YangGuangRework-0.1.1.zip`；五个便利功能合集不含该领袖。将 `YangGuangRework` 文件夹复制到同一个 Mods 目录，确保直接存在 `Mods/YangGuangRework/YangGuangRework.modinfo`。

保留并启用原杨广、王朝特性、HD，以及《风云变幻》和“撒哈拉统治者”等所需官方 DLC；这些第三方前置不包含在本压缩包内。新局选择“杨广·通济四海”，原来的杨广仍可选。详细前置及能力见 `YangGuangRework/README.md`。
