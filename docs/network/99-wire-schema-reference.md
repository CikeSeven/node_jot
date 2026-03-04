# 99. 协议字典（字段级）

本文集中定义 NodeJot 当前网络消息结构，便于抓包对照、协议审计和联调。

## 1. 约定

- 时间字段统一使用：
  - ISO8601 字符串（如 `createdAt`、`timestamp`）
  - 或 UTC 毫秒时间戳（`*UpdatedAtMs`）
- 设备 ID 均为字符串（UUID 形态）
- 加密消息通过 `secure_message` 统一包裹
- 消息体为 JSON

---

## 2. UDP 发现报文

## 2.1 `probe`

- 方向：广播/组播（发送到 `discoveryPort=45890`）
- 传输：UDP 明文
- 生产：`DiscoveryService._sendProbe` -> `_sendPresencePacket`
- 消费：`DiscoveryService._handlePacket`

字段：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `type` | string | 是 | `probe` |
| `deviceId` | string | 是 | 发送方设备 ID |
| `displayName` | string | 是 | 展示名 |
| `syncPort` | int | 是 | 同步端口 |
| `publicKey` | string | 是 | 公钥 |
| `timestamp` | string | 是 | ISO8601 |

## 2.2 `announce`

结构与 `probe` 相同，仅 `type=announce`。

## 2.3 `probe_response`

结构与 `probe` 相同，仅 `type=probe_response`（通常定向发送给 probe 来源地址）。

---

## 3. HTTP register

## 3.1 请求：`POST /register` 或 `/api/localsend/v2/register`

- 方向：A -> B
- 传输：HTTP JSON
- 生产：`SyncClient.register/_registerAtPath`
- 消费：`SyncServer.start` -> `SyncEngine._handleRegister`

字段：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `deviceId` | string | 是 | A 设备 ID |
| `displayName` | string | 是 | A 展示名 |
| `publicKey` | string | 是 | A 公钥 |
| `syncPort` | int | 是 | A 同步端口 |

## 3.2 成功响应

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `status` | string | `ok` |
| `deviceId` | string | B 设备 ID |
| `displayName` | string | B 展示名 |
| `publicKey` | string | B 公钥 |
| `syncPort` | int | B 同步端口 |

## 3.3 失败响应

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `status` | string | `error` |
| `message` | string | 错误说明 |

---

## 4. WebSocket 明文配对

## 4.1 `pair_request`

- 方向：A -> B
- 传输：WS 明文 JSON（未加密）
- 生产：`SyncEngine.pairWithDevice`
- 消费：`SyncEngine._handlePairRequest`

字段：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `type` | string | 是 | `pair_request` |
| `deviceId` | string | 是 | A 设备 ID |
| `displayName` | string | 是 | A 展示名 |
| `publicKey` | string | 是 | A 公钥 |
| `code` | string | 是 | 4 位配对码 |

## 4.2 `pair_ok`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `type` | string | `pair_ok` |
| `deviceId` | string | B 设备 ID |
| `displayName` | string | B 展示名 |
| `publicKey` | string | B 公钥 |

## 4.3 `pair_failed`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `type` | string | `pair_failed` |
| `message` | string | 例如 `Invalid pairing code` |

---

## 5. secure_message 信封

- 方向：双向
- 传输：WS JSON
- 生产：`CryptoService.encryptEnvelope`
- 消费：`CryptoService.decryptEnvelope`

字段：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `type` | string | 是 | `secure_message` |
| `deviceId` | string | 是 | 信封发送方设备 ID |
| `nonce` | string | 是 | base64(12-byte nonce) |
| `cipherText` | string | 是 | base64 密文 |
| `mac` | string | 是 | base64 GCM tag |

说明：以下第 6~8 章消息都可能作为 `secure_message.payload`。

---

## 6. 已配对设备设置同步消息

## 6.1 `peer_status_request`

| 字段 | 类型 | 必填 |
| --- | --- | --- |
| `type` | string | 是（`peer_status_request`） |
| `requesterDeviceId` | string | 是 |
| `autoSyncEnabled` | bool | 是 |
| `autoSyncUpdatedAtMs` | int | 是 |
| `oneTimeConnectionEnabled` | bool | 是 |
| `oneTimeConnectionUpdatedAtMs` | int | 是 |

生产：`SyncEngine._syncTrustedSettingsWithPeer`  
消费：`SyncEngine._handlePeerStatusRequest`

## 6.2 `peer_status_response`

| 字段 | 类型 | 必填 |
| --- | --- | --- |
| `type` | string | 是（`peer_status_response`） |
| `autoSyncEnabled` | bool | 是 |
| `autoSyncUpdatedAtMs` | int | 是 |
| `oneTimeConnectionEnabled` | bool | 是 |
| `oneTimeConnectionUpdatedAtMs` | int | 是 |

## 6.3 `peer_settings_apply`

| 字段 | 类型 | 必填 |
| --- | --- | --- |
| `type` | string | 是（`peer_settings_apply`） |
| `requesterDeviceId` | string | 是 |
| `autoSyncEnabled` | bool | 是 |
| `autoSyncUpdatedAtMs` | int | 是 |
| `oneTimeConnectionEnabled` | bool | 是 |
| `oneTimeConnectionUpdatedAtMs` | int | 是 |

生产：`SyncEngine._syncTrustedSettingsWithPeer`  
消费：`SyncEngine._handlePeerSettingsApply`

## 6.4 `peer_settings_apply_ok`

| 字段 | 类型 | 必填 |
| --- | --- | --- |
| `type` | string | 是（`peer_settings_apply_ok`） |
| `autoSyncEnabled` | bool | 是 |
| `autoSyncUpdatedAtMs` | int | 是 |
| `oneTimeConnectionEnabled` | bool | 是 |
| `oneTimeConnectionUpdatedAtMs` | int | 是 |

---

## 7. 增量同步消息

## 7.1 `sync_request`

| 字段 | 类型 | 必填 |
| --- | --- | --- |
| `type` | string | 是（`sync_request`） |
| `requesterDeviceId` | string | 是 |
| `lastLamportSeen` | int | 是 |

生产：`SyncEngine.syncWithDevice`  
消费：`SyncEngine._handleSyncRequest`

## 7.2 `sync_response`

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `type` | string | 是（`sync_response`） | 固定值 |
| `ops` | array<object> | 是 | `SyncOperation.toMap()` 结果数组 |
| `serverSeenRequesterLamport` | int | 是 | 服务端已处理到 requester 的 lamport |

## 7.3 `sync_push`

| 字段 | 类型 | 必填 |
| --- | --- | --- |
| `type` | string | 是（`sync_push`） |
| `requesterDeviceId` | string | 是 |
| `ops` | array<object> | 是 |

消费：`SyncEngine._handleSyncPush`

## 7.4 `sync_push_ok`

| 字段 | 类型 | 必填 |
| --- | --- | --- |
| `type` | string | 是（`sync_push_ok`） |
| `applied` | int | 是 |
| `lastLamport` | int | 是 |

---

## 8. SyncOperation 线协议结构

`ops` 数组元素结构（由 `SyncOperation.toMap()` 定义）：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `opId` | string | 是 | 幂等键 |
| `lamport` | int | 是 | 逻辑时钟 |
| `deviceId` | string | 是 | 操作源设备 |
| `noteId` | string | 是 | 目标笔记 ID |
| `opType` | string | 是 | create/update/delete |
| `payload` | object | 是 | 笔记快照 |
| `createdAt` | string | 是 | ISO8601 |

`payload`（快照）核心字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `noteId` | string | 笔记业务主键 |
| `contentDocJson` | string? | AppFlowy 文档 JSON |
| `contentMd` | string | markdown 镜像 |
| `title` | string | 展示标题（兼容字段） |
| `updatedAt` | string | ISO8601 |
| `deletedAt` | string? | 软删除时间 |
| `archivedAt` | string? | 归档时间 |
| `lastEditorDeviceId` | string | 最后编辑设备 |
| `baseRevision` | int | 前置修订号 |
| `headRevision` | int | 当前修订号 |
| `schemaVersion` | int | 快照 schema 版本 |

---

## 9. 通用错误响应

## 9.1 `error`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `type` | string | `error` |
| `message` | string | 错误描述 |

## 9.2 `sync_error`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `type` | string | `sync_error` |
| `message` | string | 例如 `Requester is not trusted` |

---

## 10. 消息与处理函数映射表

| 消息 | 发送侧函数 | 接收侧函数 |
| --- | --- | --- |
| `probe` | `DiscoveryService._sendProbe` | `DiscoveryService._handlePacket` |
| `announce` | `DiscoveryService._broadcastPresence` | `DiscoveryService._handlePacket` |
| `probe_response` | `DiscoveryService._sendProbeResponse` | `DiscoveryService._handlePacket` |
| `register` | `SyncClient.register` | `SyncEngine._handleRegister` |
| `pair_request` | `SyncEngine.pairWithDevice` | `SyncEngine._handlePairRequest` |
| `peer_status_request` | `SyncEngine._syncTrustedSettingsWithPeer` | `SyncEngine._handlePeerStatusRequest` |
| `peer_settings_apply` | `SyncEngine._syncTrustedSettingsWithPeer` | `SyncEngine._handlePeerSettingsApply` |
| `sync_request` | `SyncEngine.syncWithDevice` | `SyncEngine._handleSyncRequest` |
| `sync_push` | `SyncEngine.syncWithDevice` | `SyncEngine._handleSyncPush` |

