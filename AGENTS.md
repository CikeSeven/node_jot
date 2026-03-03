# NodeJot AGENTS

> 文件编码要求：UTF-8（必须）

## 1. 项目概览
- 项目名：NodeJot
- 定位：局域网多端同步的本地优先笔记应用
- 平台：Android / iOS / Windows
- 核心原则：无云端上传、无账号体系、以本地数据为主

## 2. 技术栈
- UI 与应用框架：Flutter
- 状态管理：flutter_riverpod
- 本地数据库：Isar
- 局域网通信：HTTP + WebSocket + UDP 广播/组播
- 加密：X25519 + HKDF + AES-GCM
- 本地设置：shared_preferences
- 文本编辑与文档结构：appflowy_editor（迁移进行中）
- 本地化：手写 LocalizationsDelegate（zh/en）

## 3. 主要功能
- 笔记本地 CRUD（支持归档、删除、撤销、冲突副本）
- 局域网设备发现与配对（4 位配对码）
- 配对设备增量同步（基于 op log + lamport）
- 自动同步开关与一次性连接配置
- 主题切换（跟随系统/亮色/暗色）
- 中英文切换（首启读取系统语言，不支持语言回退英文）

## 4. 代码结构（当前）
### lib/app
- node_jot_app.dart：MaterialApp、主题、本地化装配
- theme/：颜色、间距、毛玻璃视觉、全局主题

### lib/core
- constants/：端口与网络协议常量
- models/app_services.dart：全局依赖装配入口
- services/：主题、语言、应用级设置
- utils/：日志、ID、配对码、文档编解码等工具

### lib/data
- isar/collections/：实体定义与 .g.dart 生成文件
- isar/isar_service.dart：数据库初始化
- repositories/：笔记/设备/操作日志/同步游标数据访问

### lib/domain
- models/：同步与设备领域模型
- services/：发现、加密、客户端、服务端、同步引擎

### lib/features
- home/：主页壳与主导航
- notes/：笔记列表、归档页、编辑页
- notes/editor/：编辑页子模块（控制器、预览、状态卡片）
- devices/：设备发现、配对、已配对设备管理
- settings/：主题/语言/配对相关设置
- conflicts/：冲突副本列表

### lib/l10n
- app_localizations.dart：中英文案与扩展

## 5. 数据模型说明
- NoteEntity：
  - 业务主键：noteId
  - 主内容：contentDocJson
  - 兼容字段：title / contentMd（迁移兼容）
  - 同步字段：baseRevision / headRevision
  - 状态字段：deletedAt / archivedAt / isConflictCopy
- DeviceEntity：设备标识、地址、密钥、信任状态
- OpLogEntity：操作日志（create/update/delete）
- SyncCursorEntity：按设备记录同步游标

## 6. 同步链路简述
1. 发现：广播 announce/probe，并处理 probe_response
2. 回打注册：发现后主动调用对端 register，缓解单向发现
3. 配对：交换公钥，派生 sharedKey，写入 trusted device
4. 同步：sync_request 拉取 + sync_push 推送 + 游标推进
5. 冲突：无法快进时创建冲突副本，避免无提示覆盖

## 7. 开发注意事项
- 所有代码与文档文件使用 UTF-8 编码。
- 修改 Isar 实体后必须执行：
  - dart run build_runner build --delete-conflicting-outputs
- 提交前建议执行：
  - dart format lib
  - flutter analyze
- 网络调试重点日志标签：
  - [NodeJot][discovery]
  - [NodeJot][sync-engine]
  - [NodeJot][sync-client]
  - [NodeJot][sync-server]
- Android 需具备局域网相关权限与组播锁能力。
- 迁移期间（Markdown -> AppFlowy 文档）优先确保：
  - 旧数据可读
  - 新数据可保存
  - 同步不回退到旧 schema

## 8. 当前限制
- 当前仅支持文本笔记，不支持附件/图片同步。
- 无云端备份与跨公网同步能力。
