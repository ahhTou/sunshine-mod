# macOS 应用图标

2026-10-27 · Sunshine Mod。

## 形象与来源

直接复用 [ahhtou.wang](https://ahhtou.wang) 的 favicon 纸巾章鱼。原始文件快照为 `src_assets/macos/ahhtou-favicon.svg`；身体路径、流苏触腕、眼睛和嘴的几何与颜色不变，只统一缩放、定位并移除站点背景。保持原形象，不重新设计角色或增补触腕。

新增暖金太阳及十二束光，放在章鱼背后；应用背景为深蓝色。图标无文字。

## 原生 macOS 27 资源

- `src_assets/macos/SunshineMod.icon/` 是可在 Apple Icon Composer 中继续编辑的分层源文件。
- `Assets/01-sunlight.svg`：太阳光；`02-octopus.svg`：站点原始轮廓；`03-face.svg`：原始表情。
- Icon Composer 文档按前景到背景存储组和层；背景、材质、圆角遮罩与高光由系统渲染，素材不预制圆角或静态阴影。
- `src_assets/macos/sunshine-icon.svg` 为可编辑的完整平面设计参考，不用它替代分层资源。
- `sunshine-mod/build-icon.sh` 调用 Xcode 的 actool，生成 `Assets.car` 与兼容旧系统的 `SunshineMod.icns`。
- CMake 的开发 bundle 和安装/打包路径均使用以上资源；Info.plist 的 CFBundleIconName 为 SunshineMod。

构建需要包含 Icon Composer/actool 的 Xcode 27；沿用项目构建命令即可。单独重建资源：

```sh
sh sunshine-mod/build-icon.sh "$PWD/cmake-build-sunshine-mod-upgrade"
```

预览使用 Apple 自带 ictool 的 `--design-generation 27`，而非把效果画进 SVG；默认预览见本目录 `icon-preview.png`。图标构建不修改现用 Sunshine-SCK-Trace 的应用包，也不启动或重启远控服务。

参考：[Apple App icons 指南](https://developer.apple.com/design/human-interface-guidelines/app-icons)、[Icon Composer 文档](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer)。

## 本次验证

macOS 27 默认、深色、着色深色及 64px 图标已用 ictool 渲染检查；原始章鱼路径、眼睛、嘴与站点 favicon 逐项相同。完整应用构建、图标元数据/资源一致性、ad-hoc 签名及隔离目录的 Runtime 安装资源检查通过；无改动时增量构建为 no work to do。
