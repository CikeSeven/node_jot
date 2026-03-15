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
- 文本编辑与文档结构：flutter_quill（文档主存储为 `contentDocJson`）
- 本地化：手写 LocalizationsDelegate（zh/en）

## 3. 主要功能
- 笔记本地 CRUD（支持归档、删除、撤销删除）
- 长按多选（归档/删除）与桌面端右键菜单
- 编辑器自动保存（变更后防抖保存，离页/退后台兜底保存）
- 局域网设备发现与配对（4 位配对码）
- 配对设备增量同步（基于 op log + lamport）
- 自动同步开关与一次性连接配置
- 固定配对码开关（启用后启动不轮换配对码）
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
- home/：主壳与导航
  - pages/：页面入口
  - widgets/：侧栏、KeepAlive 等复用组件
- notes/：笔记域
  - pages/：`notes_page` / `archived_notes_page` / `note_editor_page`
  - sections/：页面区块（头部、列表、编辑区、状态栏）
  - widgets/：卡片、空态、滑动背景等复用组件
  - editor/：编辑器控制器、扩展、移动端工具栏
- devices/：设备域
  - pages/：设备页入口
  - sections/：本机信息、已配对、已发现区块
  - widgets/：设备列表项
  - dialogs/：4 位码输入弹窗等
- settings/：设置域
  - pages/：设置页入口
  - sections/：设备名、主题语言、配对码策略区块
- conflicts/：历史冲突查看模块（当前默认入口隐藏）
  - pages/ / sections/ / widgets/

### 兼容入口文件（重要）
- `features/*/*.dart` 顶层文件目前主要用于 `export pages/...`，用于兼容旧引用路径。
- 新增页面/区块时，优先放入 `pages|sections|widgets|dialogs`，避免单文件膨胀。

### lib/l10n
- app_localizations.dart：中英文案与扩展

## 5. 数据模型说明
- NoteEntity：
  - 业务主键：noteId
  - 主内容：contentDocJson
  - 兼容字段：title / contentMd（兼容旧数据与同步回退）
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
5. 远端落库策略：按 `updatedAt` -> `headRevision` -> `lastEditorDeviceId` 进行覆盖判定（LWW）
6. 编辑中远端更新：允许覆盖当前编辑文档，并尽量恢复滚动位置/光标（键盘弹起时）

## 7. 开发注意事项
- 所有代码与文档文件使用 UTF-8 编码。
- 修改 Isar 实体后必须执行：
  - dart run build_runner build --delete-conflicting-outputs
- 提交前建议执行：
  - dart format lib
  - flutter analyze
- 布局代码约定：
  - 页面容器在 `pages/`
  - 页面可复用区块在 `sections/`
  - 原子组件在 `widgets/`
  - 弹窗在 `dialogs/`
  - 顶层 `xxx_page.dart` 仅做兼容 export（如已存在）
- 网络调试重点日志标签：
  - [NodeJot][discovery]
  - [NodeJot][sync-engine]
  - [NodeJot][sync-client]
  - [NodeJot][sync-server]
- Android 需具备局域网相关权限与组播锁能力。
- 迁移期间（旧结构化文档/Markdown -> Quill Delta）优先确保：
  - 旧数据可读
  - 新数据可保存
  - 同步不回退到旧 schema
- 编辑器行为约定：
  - 自动保存由“文档变更事件 + 防抖”触发，不使用轮询
  - 无改动会话退出时不落库
  - 新建空笔记离页可自动清理

## 8. 当前限制
- 当前仅支持文本笔记，不支持附件/图片同步。
- 无云端备份与跨公网同步能力。
- 多端同时编辑暂未做 CRDT/OT，当前采用覆盖策略（可能出现后写覆盖先写）。
