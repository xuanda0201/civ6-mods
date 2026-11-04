# 文明 6 Mod 工作区

每个 Mod 使用独立项目目录，源码、说明和安装包均放在自己的目录中。

工坊上传：[Windows 上传准备包](bundles/steam-workshop-upload-kit.zip) · [逐步上传说明](WORKSHOP.md)。材料已准备，尚未上传或公开工坊条目。

直接试玩：[下载全部六个 Mod](bundles/civ6-mods-complete.zip) · [仅五个便利功能](bundles/civ6-mods-preview.zip) · [Steam 版安装步骤](INSTALL.md)。当前均为尚未实机验证的预览版。

| Mod | 功能 | 说明 | 安装包 |
| --- | --- | --- | --- |
| InfiniteProjects · 无限循环项目 | 每城独立开关，队列空闲时自动续建指定项目 | [使用说明](InfiniteProjects/README.md) | [下载 0.1.0](InfiniteProjects/dist/InfiniteProjects-0.1.0.zip) |
| SpyRepeat · 间谍任务循环 | 每名间谍独立开关，重复任务，异常时暂停 | [使用说明](SpyRepeat/README.md) | [下载 0.1.0](SpyRepeat/dist/SpyRepeat-0.1.0.zip) |
| BuilderAuto · 建造者自动作业 | 每个建造者独立开关，自动修复、开发资源和改良工作地块 | [使用说明](BuilderAuto/README.md) | [下载 0.2.1](BuilderAuto/dist/BuilderAuto-0.2.1.zip) |
| AutoTheme · 巨作一键整理 | 整理整个巨作面板，支持产品、遗物、著作、音乐、艺术品和文物 | [使用说明](AutoTheme/README.md) | [下载 0.2.0](AutoTheme/dist/AutoTheme-0.2.0.zip) |
| RailAuto · 沿途自动铺铁路 | 军事工程师、大亨等单位独立开关，正常移动时沿途铺设 | [使用说明](RailAuto/README.md) | [下载 0.1.1](RailAuto/dist/RailAuto-0.1.1.zip) |

另有可选的独立领袖：[杨广·通济四海](YangGuangRework/README.md) · [下载 0.1.1](YangGuangRework/dist/YangGuangRework-0.1.1.zip)。原杨广保留；此项有单独前置，不包含在五个便利功能的合集安装包中。

游戏规则集、HD 版本及验证状态见 [兼容记录](COMPATIBILITY.md)。

目录约定：

```text
civ6/
├── README.md
├── InfiniteProjects/
│   ├── README.md
│   ├── src/InfiniteProjects/  # 可复制到游戏 Mods 目录
│   └── dist/                 # 安装包
├── SpyRepeat/
│   ├── README.md
│   ├── src/SpyRepeat/
│   └── dist/
├── BuilderAuto/
│   ├── README.md
│   ├── src/BuilderAuto/
│   └── dist/
├── AutoTheme/
│   ├── README.md
│   ├── src/AutoTheme/
│   └── dist/
├── RailAuto/
│   ├── README.md
│   ├── src/RailAuto/
│   └── dist/
└── 其他Mod/                  # 后续项目同样独立组织
```

安装游戏 Mod 时使用安装包内的 Mod 文件夹，或项目 `src/` 下的 Mod 文件夹。

自行编写的代码及封面使用 [MIT 许可证](LICENSE)，参考资料与署名见 [CREDITS.md](CREDITS.md)。
