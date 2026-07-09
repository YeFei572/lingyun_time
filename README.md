# 凌云时光

凌云时光是一款面向婴儿日常照护的 Flutter 应用，用来记录喂奶、小便、维 D 等行为数据，并保存宝宝成长过程中的照片和视频剪影。

当前版本：`0.0.4+4`

## 功能概览

- 行为记录：按「吃奶 / 小便 / 维D」分类记录时间、数量或描述、备注。
- 奶量曲线：查看单日吃奶次数、总奶量、平均奶量和 24 小时趋势图。
- 时光剪影：从本地选择照片或视频，上传到 S3 兼容对象存储，并按时间线展示。
- 宝宝资料：设置出生日期，行为记录中可辅助展示出生天数。
- 主题切换：支持白天模式和暗夜模式。
- 数据备份：导出 / 导入 `.txt` 备份文件，覆盖行为记录、时光剪影、S3 配置和宝宝资料。

## 技术栈

- Flutter / Dart
- Riverpod：状态管理
- path_provider：应用本地数据目录
- file_picker：文件选择、备份导入导出
- cached_network_image：网络图片缓存与展示
- video_player：远程视频播放
- fl_chart：奶量曲线图
- crypto：S3 请求签名
- hugeicons：部分界面图标

## 项目结构

```text
lib/
  main.dart
  src/
    app/                  # 应用入口与 MaterialApp 配置
    core/
      config/             # 主题配置
      storage/            # 本地 JSON 存储与数据目录
      utils/              # 通用工具
    features/
      baby_log/           # 婴儿行为记录与奶量曲线
      home/               # 底部导航容器
      settings/           # 设置、宝宝资料、备份
      time_silhouette/    # 时光剪影、S3 上传配置与存储服务
    shared/
      models/             # 共享数据模型
```

## 本地运行

本项目使用 FVM 管理 Flutter 版本，当前 `.fvmrc` 指定 Flutter `3.44.4`。请优先通过 `fvm flutter ...` 执行 Flutter 命令，避免使用到本机全局 Flutter 版本。

1. 确认已安装 FVM，并安装项目指定的 Flutter 版本：

   ```bash
   fvm install
   ```

2. 检查 Flutter 环境：

   ```bash
   fvm flutter doctor
   ```

3. 安装依赖：

   ```bash
   fvm flutter pub get
   ```

4. 启动应用：

   ```bash
   fvm flutter run
   ```

5. 运行静态检查：

   ```bash
   fvm flutter analyze
   ```

6. 运行测试：

   ```bash
   fvm flutter test
   ```

## 数据存储

应用数据保存在系统的应用文档目录下，并统一放入 `lingyun_time` 子目录。当前包含：

- `baby_logs.json`：行为记录
- `memories.json`：时光剪影记录
- `s3_config.json`：S3 上传配置
- `baby_profile.json`：宝宝资料

备份文件是 UTF-8 文本格式，内容为 JSON。导入备份会覆盖当前本地数据，请在导入前确认现有数据已经妥善保存。

## S3 上传配置

时光剪影依赖 S3 兼容对象存储。请在「设置 > S3 上传配置」中填写：

- Endpoint
- Region
- Bucket
- Access Key ID
- Secret Access Key
- Path Prefix
- Public Base URL
- Path Style / Virtual Host 模式

未完成 S3 配置时，照片和视频无法上传。删除应用内的剪影记录只会删除本地记录，不会自动删除已上传到 S3 的对象。

> 备份文件会包含 S3 访问密钥等敏感信息，请不要公开分享备份文件。

## 开发备注

- 应用入口为 `lib/main.dart`，主导航为 `HomeShell`。
- 本地持久化通过 `LocalJsonStore` 写入 JSON 文件。
- 新增本地数据类型时，需要同步扩展备份导出 / 导入逻辑。
- 当前主要目标平台为 Android 和 iOS。
