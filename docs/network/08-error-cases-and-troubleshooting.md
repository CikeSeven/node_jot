# 08. 错误场景与排障

## 1. 使用方式

本章用于定位“为什么设备看不到/配对失败/同步不生效”。  
建议按“分层排障”顺序执行：发现层 -> 注册层 -> 配对层 -> 同步层。

推荐日志标签：

- `[NodeJot][discovery]`
- `[NodeJot][sync-engine]`
- `[NodeJot][sync-client]`
- `[NodeJot][sync-server]`

## 2. 分层排障清单

## 2.1 发现层（UDP）

检查点：

1. 是否有 `discovery started` 日志
2. 是否有 `broadcast targets` 输出
3. 是否能看到 `received probe` / `discovered device` 日志
4. 设备是否在 12 秒后被移除（可能说明只收到了瞬时包）

典型症状：
- “需要切到设备页等一会儿才看到”：可先手动 `refreshDiscovery()`
- “电脑能看到手机，手机看不到电脑”：常见是虚拟机/网卡隔离或广播方向受限

## 2.2 注册层（HTTP）

检查点：

1. `sync-client` 是否有 `post register to host:port`
2. 是否出现 `register response ok`
3. 服务端是否打印 `accepted register from ...`

若失败：
- 看是否只某一路径失败（兼容路径 `/api/localsend/v2/register` 与 `/register`）
- 看 remote `syncPort` 是否正确

## 2.3 配对层（WS 明文）

检查点：

1. 发起端是否打印 `pair start`
2. 接收端是否打印 `received pair_request`
3. 结果是否 `pair success` / `pair_failed`

常见失败：
- `Invalid pairing code`：配对码不一致
- 设备本地时间/网络无关，此处核心是 4 位码和 WS 可达性

## 2.4 加密与同步层（WS secure_message）

检查点：

1. `sync start -> ...`
2. `received sync_request` / `received sync_push`
3. `sync_push applied x/y`
4. 游标是否推进（`SyncCursorEntity.lastLamportSeen`）

常见失败：
- `Untrusted device`：对端设备未在 trusted 表
- `schemaVersion` 太低被跳过
- `sync_request/sync_push` 非预期响应类型

## 3. 故障矩阵

| 现象 | 层级 | 可能原因 | 快速验证 | 修复方向 |
| --- | --- | --- | --- | --- |
| A 能看到 B，B 看不到 A | 发现/注册 | 单向广播可达或回打失败 | 看 B 端有无 `register back success` | 手动刷新发现，检查网卡/虚拟机网络模式 |
| 输入配对码后立即失败 | 配对 | 码错误 | 看返回 `pair_failed` | 校对 4 位码，确认固定配对码状态 |
| 已配对但状态常变 invalid | 探测 | 对端离线/端口不可达/密钥失效 | 看 `trusted probe failed` | 重新连接配对，确认两端应用版本与网络 |
| 删除笔记后另一端不一致 | 同步 | 自动同步关闭/连接未建立/游标未推进 | 看是否触发 `sync start` 和 `sync_push` | 打开自动同步，检查连接状态为 connected |
| 长期 connected 但数据不更新 | 同步策略 | 本地无 op 产生或被 stale 判定 | 检查 `appendOperation` 和 `skip stale op` | 校验更新时间与修订号写入逻辑 |

## 4. 必查数据表

## 4.1 DeviceEntity

重点字段：
- `trusted`
- `sharedKey`
- `host/port`
- `lastSeenAt`

## 4.2 OpLogEntity

重点字段：
- `opId`（是否唯一）
- `lamport`（是否单调递增）
- `payloadJson.schemaVersion`

## 4.3 SyncCursorEntity

重点字段：
- `peerDeviceId`
- `lastLamportSeen`（是否随着同步增长）

## 5. 典型排障流程（建议按顺序）

1. 确认两端都在同一局域网且 `syncPort=45888` 可达。
2. 打开设备页触发刷新，观察 discovery 日志是否出现双方。
3. 检查 register 是否成功（至少一侧成功回打）。
4. 重新配对，确认 trusted 记录里有 `sharedKey`。
5. 触发一次手动同步，观察 pull/push 两段日志是否完整。
6. 如果仍失败，导出 op/cursor 数据检查 lamport 与游标关系。

## 6. 已知实现边界（避免误判）

- 一次性连接开关目前只同步配置，不会自动执行“退出应用即删配对”。
- 同步不是 CRDT；并发编辑可能出现后写覆盖先写。
- 当前仅支持文本笔记同步，不支持附件。

