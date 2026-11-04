# 文明 6 Mod 工作区

每个 Mod 使用独立项目目录，源码、说明和安装包均放在自己的目录中。

工坊上传：[Windows 上传准备包](bundles/steam-workshop-upload-kit.zip) · [逐步上传说明](WORKSHOP.md)。材料已准备，尚未上传或公开工坊条目。

直接试玩：[下载四合一安装包](bundles/civ6-mods-preview.zip) · [Steam 版安装步骤](INSTALL.md)。当前均为尚未实机验证的预览版。

| Mod | 功能 | 说明 | 安装包 |
| --- | --- | --- | --- |
| InfiniteProjects · 无限循环项目 | 每城独立开关，队列空闲时自动续建指定项目 | [使用说明](InfiniteProjects/README.md) | [下载 0.1.0](InfiniteProjects/dist/InfiniteProjects-0.1.0.zip) |
| SpyRepeat · 间谍任务循环 | 每名间谍独立开关，重复任务，异常时暂停 | [使用说明](SpyRepeat/README.md) | [下载 0.1.0](SpyRepeat/dist/SpyRepeat-0.1.0.zip) |
| BuilderAuto · 建造者自动作业 | 每个建造者独立开关，自动修复、开发资源和改良工作地块 | [使用说明](BuilderAuto/README.md) | [下载 0.2.0](BuilderAuto/dist/BuilderAuto-0.2.0.zip) |
| AutoTheme · 巨作一键整理 | 整理整个巨作面板，支持产品、遗物、著作、音乐、艺术品和文物 | [使用说明](AutoTheme/README.md) | [下载 0.2.0](AutoTheme/dist/AutoTheme-0.2.0.zip) |

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
└── 其他Mod/                  # 后续项目同样独立组织
```

安装游戏 Mod 时使用安装包内的 Mod 文件夹，或项目 `src/` 下的 Mod 文件夹。

自行编写的代码及封面使用 [MIT 许可证](LICENSE)，参考资料与署名见 [CREDITS.md](CREDITS.md)。
