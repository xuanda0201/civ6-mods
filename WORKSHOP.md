# Steam 创意工坊上传准备

**当前状态：发布材料已准备，未上传 Steam，尚未通过实机验证。**

下载 [Windows 上传准备包](bundles/steam-workshop-upload-kit.zip)，解压到一个方便的位置，例如 `C:\Civ6Upload`。这是给上传者用的准备包；安装试玩请使用 [合集安装包](bundles/civ6-mods-preview.zip)。

## Windows 上怎么上传

1. 登录准备发布 Mod 的 Steam 账号，在库中勾选「工具」，安装 **Sid Meier's Civilization VI Development Tools**。
2. 先按 `INSTALL.md` 将五个 Mod 安装到本地，在实际使用的 HD 组合中开单机新局验证；各 Mod 的截图清单也包含建议验证场景。
3. 启动开发工具，选择 **Steam Workshop Uploader**。如果从 ModBuddy 进入，使用 `Tools → Launch Steam Uploader`。
4. 新建上传，选择准备包对应 Mod 的 `content` 文件夹内的 `.modinfo`。不要选择合集 ZIP、仓库目录或整个上传准备包。
5. 标题使用 `metadata.json` 中的 `title`，说明粘贴 `description.zh-CN.bbcode`，封面选择 `preview.png`。英文说明也已准备，可按需附在中文说明后。
6. **首次选择 Private / 私密**。`metadata.json` 是本仓库的准备材料清单，不是上传工具可自动导入的配置；仍需在工具中手动选择文件、填写字段。
7. 上传完成后记录条目网址和 Workshop ID，再用同一个账号订阅测试。把用户 `Mods` 中的同 ID 本地副本暂时移出，确认实际加载工坊下载版本。
8. 补充真实游戏截图、确认实机结果后，再在工坊页面修改可见性。不要在未验证时将文案改成“已验证 HD 兼容”。

不需要先在 ModBuddy 重建工程；当前已有可选取的 `.modinfo`。这些是 Lua/XML Mod，不需要先安装大型 Development Assets 美术资源包。

## 五个便利功能与一个独立领袖的材料

| Mod | 选择的入口（相对准备包） | 当前版本 |
| --- | --- | --- |
| 无限循环项目 | `InfiniteProjects/content/InfiniteProjects.modinfo` | 0.1.0 |
| 间谍任务循环 | `SpyRepeat/content/SpyRepeat.modinfo` | 0.1.0 |
| 建造者自动作业 | `BuilderAuto/content/BuilderAuto.modinfo` | 0.2.1 |
| 巨作一键整理 | `AutoTheme/content/AutoTheme.modinfo` | 0.2.0 |
| 沿途自动铺铁路 | `RailAuto/content/RailAuto.modinfo` | 0.1.1 |
| 杨广·通济四海（独立领袖） | `YangGuangRework/content/YangGuangRework.modinfo` | 0.1.3 |

每个目录还包含封面 PNG、中文/英文 BBCode 说明、真实截图待拍清单和元数据。封面来自几何图形与文字绘制，没有伪造游戏截图。

GitHub 仓库当前为私有，因此工坊介绍没有放一个公众无法访问的源码链接。是否公开仓库不影响上传私密工坊条目；需要公开源码时再单独决定。

## 发布前还需要你在 Windows 上完成

- 确认 Mod 出现在额外内容列表，开启后有对应按钮。
- 验证各自的最短使用流程以及保存、返回主菜单、读档。
- 按 `screenshots-needed.md` 拍摄真实游戏画面。
- 将 `metadata.json` 的实机状态、验证的游戏/DLC/HD 版本补为实际结果；记录工坊 ID。
- 回报报错信息或上传失败提示，以便修复。当前源码的 `.modinfo` 已声明仅单机，不应在工坊描述中承诺联机。

目前没有将 HD 设置成所有项目的强制工坊前置项：这些 Mod 旨在条件适配 HD，但尚未完成原版/HD 对照实测。发布页只应填写实际必需的 DLC 和 Mod，不能用“适配目标”冒充已验证的依赖或兼容性。

## 更新原条目

首次上传后，将每个条目的 ID 写入该 Mod `workshop/metadata.json` 的 `publishedFileId`（字符串）。将 Steam 返回的链接填入 `workshopUrl`。后续使用 Uploader 对原条目执行 **Upload a new version**，不要反复创建新条目；沿用各 Mod 现有 UUID。

若用户从本地安装改为工坊订阅，提醒移除同 ID 的本地副本。GitHub 仓库可继续保持一个，五个工坊条目各自维护版本；都验证后再建立合集。

## 重新打包

```text
python scripts/package.py
```

该命令只生成本地安装包和上传准备包，不上传 Steam、不修改工坊可见性。封面已提交到仓库；重新绘制可用 `python workshop/create_covers.py`，该可选脚本需要 Pillow 及系统中文字体。

参考：[开发工具说明](https://github.com/Wild-W/Civ-6-Documentation/blob/main/README.md)、[Civ6 上传流程](https://steamcommunity.com/sharedfiles/filedetails/?id=1836201808)、[Steam Workshop 上传与更新机制](https://partner.steamgames.com/doc/features/workshop/implementation)。

游戏规则集、HD 版本和真实验证情况按 `COMPATIBILITY.md` 维护；发布页不得将 HD v2.2 适配目标写成已验证兼容。

独立领袖需单独验证，并在工坊页面列出原杨广、王朝特性、HD 及官方 DLC 前置。包中只有新增配置/代码和资源引用；不打包第三方画像、单位资产。原作者署名与原资源许可证保持不变。
