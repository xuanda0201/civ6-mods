# 无限循环项目 · Infinite Projects

文明 6 单机 Mod：每座城市一个开关，当前项目完成且生产队列为空时，自动补上一份相同项目。

## 项目目录

- `src/InfiniteProjects/`：可直接安装的 Mod 源码。
- `dist/`：打包后的安装包。
- `README.md`：本 Mod 的安装、使用和验证说明。

## 安装

使用安装包时，把解压出的 `InfiniteProjects` 文件夹放入游戏的 `Mods` 目录。

从源码安装时，复制本项目的 `src/InfiniteProjects/` 文件夹。不要把包含 `src`、`dist` 的整个项目目录复制进去，也不要多套一层文件夹。

- Windows：通常是 `文档\My Games\Sid Meier's Civilization VI\Mods`，文档使用 OneDrive 时以实际路径为准。
- macOS：通常是 `~/Library/Application Support/Sid Meier's Civilization VI/Mods`。

在游戏的「额外内容 → 模组」启用「无限循环项目 / Infinite Projects」，再进入游戏。此版本包含保存状态的 Gameplay 脚本，**首次验证请开新局**；旧存档能否后加启用未验证。

## 使用

1. 选中自己的城市，在原来的生产面板安排一个可重复项目。
2. 点击屏幕左侧中部独立面板的「开启：循环当前项目」。
3. 项目完成后，只要队列为空且项目合法，就自动续建一份。
4. 点击「关闭项目循环」停止续建；当前已经开始的生产继续进行。

各城独立设置。要换循环项目，先关开关，安排新项目，再打开。开关会通过正常玩家操作写入城市属性，随游戏存档保存。

手动安排建筑、单位或其他项目时，会等待整条队列完成后再恢复原指定项目。项目因条件变化无法继续时显示暂停，后续回合重新检查。不会提前塞满队列，不会自动结束回合，也不会购买、移动单位或修改产出。

## 和而不同（HD）适配边界

- 不替换生产面板、买地面板、数据库或 HD 脚本，使用独立 UI。
- 从当前加载的 `GameInfo.Projects` 读取项目类型；不写死原版项目名称或数字 ID。
- 每次续建检查 `CanProduce` 和 `CanStartOperation`，遵守实际加载后的生产规则。
- 有世界/玩家次数上限或标记为内部项目的条目，不提供无限循环。
- HD 新增项目只要按正常项目机制实现、可重复生产，即可走同一流程；特殊 Lua 项目和资源消耗仍需实机确认。
- 不支持联机/热座；不要同时让 Auto Queue、自动生产等 Mod 管理同一座城。

**当前是待实机验证的首版，不声称已验证 HD 2.2 兼容。** 开发机没有文明 6 安装目录，检查了公开 HD 源码的操作接口和界面覆盖方式，但公开源码版本与工坊版本不完全一致。

本地已通过 Lua 语法、XML 与清单文件检查，并用临时模拟环境执行了逐城隔离、续建、重复事件、手动生产优先、不可生产后恢复、UI 重载保留属性、关闭循环和一次性项目排除。模拟不验证游戏接口的实际行为或真实存档序列化，以上仍以实机试玩为准；未添加测试框架或 CI。

## 最短试玩路径

在实际使用的 HD 模组组合下开单机新局，准备两座城市和一个能完成的可重复项目：

1. A 城开启循环、B 城不开。完成项目后，确认只有 A 城自动续建。
2. 在 A 城手动安排建筑，确认不被覆盖；整条队列结束后恢复指定项目。
3. 保存、退出到主菜单再读档，确认 A 城开关及指定项目保留。
4. 关闭开关，确认当前项目完成后不再续建。
5. 对学院项目、面包与马戏、HD 生产商品分别验证；若项目要求资源，确认每次完成的扣除符合 HD 规则。

出现问题时查看游戏 `Logs/Lua.log` 中的 `[InfiniteProjects]` 和报错信息；界面加载异常同时查看 `Modding.log`。续建请求每城每回合最多一次，失败后不会在同一回合无限重试。

## 源码参考

独立编写，未复制第三方实现。接口及加载格式参考：

- [HD 的状态写入流程](https://github.com/XHH-Coco/Civ6HarmonyInDiversity/blob/master/Gameplay/HD_StateUtils.lua)
- [Automated Production Queue](https://github.com/starreeze/AutomatedQueue)
- [CQUI](https://github.com/Azurency/CQUI_Community-Edition)

`InfiniteProjects.modinfo` 为入口；`InfiniteProjects_State.lua` 负责存档属性；`InfiniteProjects.lua` 和同名 XML 负责开关及续建。

## 工坊发布材料

`workshop/` 包含封面、中英文介绍、实机截图清单和准备元数据；当前尚未上传工坊、未完成实机验证。Windows 上传步骤见仓库根目录 `WORKSHOP.md`，上传时使用对应 `src/` 下的 `.modinfo`。代码和原创封面使用 MIT 许可证，安装内容中的 `LICENSE.txt` 随包分发。
