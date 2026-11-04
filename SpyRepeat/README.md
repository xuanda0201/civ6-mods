# 间谍任务循环 · Spy Repeat

文明 6 单机 Mod：每名间谍一个开关，重复已经手动安排过的任务。独立于无限循环项目 Mod，可以分别启用。

## 安装与使用

解压 `dist/SpyRepeat-0.1.0.zip`，把其中的 `SpyRepeat` 文件夹复制进游戏 `Mods` 目录。从源码安装则复制 `src/SpyRepeat/`，不要复制包含 `src`、`dist` 的项目目录。

- Windows：通常为 `文档\My Games\Sid Meier's Civilization VI\Mods`。
- macOS：通常为 `~/Library/Application Support/Sid Meier's Civilization VI/Mods`。

在「额外内容 → 模组」启用「间谍任务循环 / Spy Repeat」，首次验证请开单机新局。Gameplay 脚本能否后加到已有存档尚未验证。

1. 使用游戏原来的间谍界面，手动安排一次偷钱、反间谍或其他可重复任务。
2. 点击屏幕左侧的「间谍循环」按钮，在列表里为该间谍「开启自动重复」。任务进行中也可以打开开关。
3. 任务结束、间谍空闲且原任务仍然合法时，自动续派到原目标地块。
4. 点击「关闭自动重复」只停止后续续派，不会取消当前任务。

## 暂停与手动安排

- 游戏提供可选晋升时暂停；使用实际晋升指令查询，避免硬编码原版升级次数。处理晋升后，在列表点击恢复。
- 遇到需要逃跑的任务结果时暂停，逃跑路线仍在游戏原界面选择。不会代选路线或自动关闭结果弹窗。
- 原任务不合法、城市归属变化、间谍调动或离开地图时暂停并展开列表显示原因。临时失效也需要手动恢复，不会在条件变化后突然续派。
- 被捕、阵亡和旅行可能都表现为离开地图，本 Mod 不推断具体原因，提示查看原间谍界面；暂停记录可移除。
- 同一城市内手动换成另一个可重复任务，会更新循环任务；主动调往其他城市会暂停，需要重新安排后开启。
- 若游戏为归来的间谍分配了新单位 ID，需要为新单位重新开启；旧记录不会按名字自动绑定。
- 状态和每回合续派保护存入玩家属性，随游戏存档保存。每名间谍每回合最多提交一次自动续派。

初始先手动安排任务，确保记录的任务类型和地块来自当前正在执行的任务；不会自动挑选城市、分配任务权重或做晋升选择。获取来源属于准备行动，不提供无限重复。

## 和而不同适配与验证边界

不替换 HD 的间谍、任务、晋升界面，不修改数据库。读取当前加载的任务定义和晋升选项，通过正常的玩家脚本操作写入状态，通过 `UnitManager` 检查并请求任务。

当前为 **0.1.0 待实机验证版**。开发机未找到文明 6，不能确认原版或 HD 实际运行效果。公开 HD 源码的版本也可能落后于工坊版本。仅支持单机，不支持热座/联机；不要让其他间谍自动化 Mod 同时管理同一间谍。

已通过 Lua 语法、XML、清单引用检查，以及临时 Lua 模拟中的逐间谍隔离、开关/恢复、同城手动换任务、重复续派保护、晋升暂停、续派等待期间发生逃跑、任务不可用、调动、离图、UI 重载和移除记录检查。未新增测试框架；模拟不验证实际游戏接口、真实存档序列化或 UI 布局。

### 最短试玩路径

在实际使用的 HD 组合中，准备两个间谍：

1. 只为 A 开启偷钱循环，B 保持手动。确认只有 A 自动续派。
2. A 续派后关闭开关，确认当前任务继续、结束后停止。
3. 在本国指定区域开启反间谍循环，确认仍保护原区域。
4. 保存并回到主菜单读档，确认开关、目标和暂停状态保留。
5. 验证晋升、手动改任务、调往新城市、目标失效、逃跑及被捕的暂停行为。

任务结果弹窗仍由游戏管理；如果结果需要确认，先处理弹窗。出现问题查看 `Logs/Lua.log` 中的 `[SpyRepeat]` 和错误信息；加载问题也查看 `Modding.log`。

## 文件结构与参考

`src/SpyRepeat/` 为可安装源码，`dist/` 放安装包。

独立编写，接口行为参考公开源码：

- [HD 间谍晋升界面](https://github.com/XHH-Coco/Civ6HarmonyInDiversity/blob/master/UI/Replacement/HD_PKSpyUnitPromotionPopup.lua)
- [HD 单位面板的晋升指令查询](https://github.com/XHH-Coco/Civ6HarmonyInDiversity/blob/master/UI/Replacement/DL_UnitPanel.lua)
- [HD 状态保存操作](https://github.com/XHH-Coco/Civ6HarmonyInDiversity/blob/master/Gameplay/HD_StateUtils.lua)
- [CQUI / Better Espionage Screen](https://github.com/Azurency/CQUI_Community-Edition/tree/master/Integrations/BES)

## 工坊发布材料

`workshop/` 包含封面、中英文介绍、实机截图清单和准备元数据；当前尚未上传工坊、未完成实机验证。Windows 上传步骤见仓库根目录 `WORKSHOP.md`，上传时使用对应 `src/` 下的 `.modinfo`。代码和原创封面使用 MIT 许可证，安装内容中的 `LICENSE.txt` 随包分发。
