# Formata — JSON 扩展与增量解析实施计划

交付对象：Codex · 仓库：https://github.com/gsmlg-dev/formata
制定日期：2026-11-13 · 参考基线：`main`，提交 e7f86654a63d7a9bcd1b67aed7534ecce2e7dc71
状态：已实现（见文末“执行摘要”）。

## 0. Goal

在现有 Formata 单 Mix 项目、单 Hex 包内完成三个相互关联、但 API 边界明确的 JSON 改进：

1. 可配置 JSON 解析：在现有 `:json` Codec 增加 `comments` 和 `trailing_commas` 两个独立开关；严格 JSON 仍为默认行为。不新增 `:jsonc` Codec。
2. 原生增量 JSON 解析：提供面向任意字节 Chunk／LLM Token Delta 的纯函数式解析状态机，增量输出结构事件与已完成字段值，支持最终完整性验证；不是对累计文本反复执行 `decode/1`。
3. JSON5 独立 Codec：按 JSON5 1.0.0 语法实现 `Formata.Codec.JSON5`，复用公共设施但不把 JSON5 语义注入严格 JSON。

保持项目定位：Data Codec + Schema + Validation + Transformation。不引入身份认证、JWT、JOSE、数据库存储协议等功能。

明确不在本次 Scope：JSONB、独立 JSONL/NDJSON Codec、CBOR、MessagePack、JSON Schema 引擎重构、LLM 供应商 SDK / SSE 协议客户端、JSON5 增量解析、完整容错式“修复不合法 JSON”引擎、保留注释的 CST / 格式保持编辑器。

## 1. 已确认的代码现状与设计约束

- `lib/formata/codec/json.ex` 通过 `Formata.Jason.decode(input, objects: :ordered_objects)` 解码，再经 `unorder/2` 拒绝重复键；`decode/2` 当前未将 opts 传递给实际解析过程。
- `Formata.Jason.Decoder.parse/2` 是一次性递归解析，不暴露跨 Chunk 续接状态。
- `Formata.Codec` 只有 `format/0`、`decode/2`、`encode/2`，不要强制给所有 Codec 增加流式回调。
- 所有预期失败使用 `{:error, [%Formata.Error{}, ...]}`；不创建动态 atom。
- 现有 JSON 域不接受非有限浮点；`Formata.Transform` 负责显式有损转换。
- Elixir `~> 1.18`；CI 覆盖 1.18/OTP 27 和 1.20/OTP 28；运行时零外部依赖。

## 2. 不可破坏的全局约束

1. `Formata.decode(input, :json)` 不带选项时仍严格遵循 RFC 8259。
2. 正确拒绝重复对象键（比较解码后的字符串键），保留嵌套数据路径。
3. 不产生 atom，不执行 JSON 数据中的内容，不进行隐式转换，不吞掉解析错误。
4. 不依赖进程、全局状态、ETS、GenServer、NIF、端口或网络 I/O。
5. 不使用正则或“先删注释再解析”实现 JSONC；不对 JSON5 用正则预转换成 JSON。
6. 维持 `Formata.Error` 统一错误协议，不要把不完整输入当成成功的完整文档。
7. 继续遵守资源约束（包括 Jason fork 的整数位数限制）。
8. 同时更新 README、设计说明、CHANGELOG、ExDoc、NOTICE。

## 3. Workstream A — `:json` 注释 / 尾随逗号

- `Formata.decode(input, :json, comments: true, trailing_commas: true)`；两个开关相互独立，解码专用；`encode(..., :json)` 仍生成严格 JSON。
- 行注释到行结束或 EOF；块注释不可嵌套，未闭合报错；字符串内容不当注释；不接受 `#` 注释与 JSON5 语法。
- `[1,,2]`、`{,}`、`{"x":1,,}` 无论开关如何都拒绝。
- 错误位置使用原始输入偏移。
- 错误选项值与未知选项返回结构化错误，并记录向后兼容影响。

## 4. Workstream B — 原生增量 JSON Parser

- 单个 JSON 文档的跨 Chunk 增量解析器，不是 JSONL。
- API：`new/1`、`feed/2`、`finish/1`、`decode_stream/2`。
- 事件：`{:start_object, path}`、`{:end_object, path}`、`{:start_array, path}`、`{:end_array, path}`、`{:key, path, key}`、`{:value, path, value}`；可选 `{:string_delta, path, fragment}`。
- 事件是“已识别的语法事实”，不代表文档最终有效；有副作用的工具执行需等 `finish/1` 成功和校验完成。
- 任意切分；合法前缀等待、非法前缀立即失败；`finish` 拒绝所有不完整文档；与一次性解码接受/拒绝一致；位置不因 Chunk 重置；不保存累计原文。
- 资源限额：`max_depth`、`max_document_bytes`、`max_token_bytes`。
- 测试：所有两段切分、逐字节、随机切分、差分测试、懒执行与终止；性能测量提供可复现命令。

## 5. Workstream C — JSON5 独立 Codec

- `Formata.Codec.JSON5` 注册为 `:json5`；不在 `:json` 加 `json5: true`。
- JSON5 1.0.0：注释、尾随逗号、单/双引号字符串、ES5.1 IdentifierName 键、附加空白、`+1`、`.5`、`5.`、十六进制、`Infinity`、`NaN`。
- 拒绝无效 token、重复键、不完整注释/转义、超出有限浮点范围的数字。
- 非有限值使用 `:infinity`、`:negative_infinity`、`:nan`；编码输出最小、确定的 JSON5。
- `convert(input, :json5, :json)` 对非有限值按严格 JSON 策略拒绝并给出 path；JSON Schema 返回 `:non_json_value`。

## 6. JSONL / NDJSON

仅在文档中演示逐行调用 `Formata.decode(line, :json)`，不增加核心抽象。

## 7–10. 目录、阶段、验收与执行指令

见原计划：Phase 0 设计核验 → Phase 1 JSON 解码开关 → Phase 2 增量 Parser → Phase 3 JSON5 → Phase 4 文档、回归与提交。验收门槛：`mix format --check-formatted`、`mix compile --warnings-as-errors --force`、`mix test`、`mix docs`、`mix hex.build`。不创建分支/worktree，不发布 Hex 版本。

## 执行摘要

基线核对：`main` HEAD 为 `e7f8665`，与计划基线一致；`Formata.Jason`、`Formata.Codec.JSON` 与 `Formata.Codec` 的现状与第 1 节描述一致。CI 中 `ci.yml` 只做格式检查与编译，测试在 `test.yml`（`mix test`）中运行。

| 阶段 | 提交 | 内容 |
| --- | --- | --- |
| 1 | `feat(json): add opt-in comments and trailing_commas decode options` | 在 Jason fork decoder 的每个空白位置加入 `/` 分支；尾随逗号依据累加器非空判断；`Formata.Codec.check_options/3` 统一选项校验 |
| 2 | `feat(json): add incremental single-document JSON stream parser` | `Formata.Codec.JSON.Stream` + 内部 `Stream.Machine`；`bench/json_stream.exs` |
| 3 | `feat(json5): add JSON5 1.0.0 codec` | `Formata.Codec.JSON5` + 内部 `JSON5.Parser`，注册 `:json5` |
| 4 | `docs: ...` | README、`docs/design.md`、CHANGELOG、NOTICE、ExDoc 分组、本文件 |

与计划的差异与决定：

- 增量 Parser 未复用一次性 Jason decoder（无可续接状态），以差分测试保证语义一致；设计记录见 `docs/design.md` “Incremental JSON parser”。
- `string_deltas: true` 已实现（非推迟）。
- 增量 Parser 额外使用错误码 `:incomplete`（EOF 截断）与 `:limit_exceeded`；接受/拒绝与 `Formata.decode/3` 一致，但错误码与个别偏移可能不同（流按输入顺序报告第一个问题）。
- 增量 Parser 的 column 以 Unicode 码点计数；`Formata.decode/3` 使用字素（grapheme）计数；字节 offset 相同。
- JSON5 的 IdentifierName 字符类别使用运行时 PCRE 的 Unicode 通用类别表（对单个码点分类，不做文本预转换）。
- `Formata.Codec.JSON.decode/2` 现在拒绝未知选项（向后不兼容：过去被静默忽略），已写入 CHANGELOG “Changed”。
- 性能：同一 406 KB 文档整块输入时，增量 Parser 约比一次性解码慢 8 倍；成本与 Chunk 数量近似无关，而“每个 Chunk 重新解码累计缓冲区”呈二次增长。数据与复现命令见 `docs/design.md`。
