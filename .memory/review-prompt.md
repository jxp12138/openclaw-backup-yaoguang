# Background Review — 后台记忆提取指引

## 触发条件
连续10轮主代理API调用中未发生任何 memory 写入。

## 流程

1. **检查是否满足条件**
   - 查询 transcripts/sessions.db 中最近10条 assistant 消息
   - 确认其中是否有 write/edit 写入 long-term/ 文件的操作
   - 如果有写入 → 跳过本轮 review，重置计数器

2. **启动 review**
   - spawn 子代理，mode="run"
   - 注入最近5轮对话的摘要
   - 使用以下提示：

```
请回顾最近一段对话，提取值得长期记住的信息。

类型判断规则：
- user: 关于用户本人的偏好、习惯、行为准则
- feedback: 用户对AI的纠正或确认，好的或坏的
- project: 不可从代码推导的项目上下文、规划、待办
- reference: 外部链接、配置、引用

明确不存：
- 代码可推导的结构、架构、调试方案
- 文件路径、git 历史
- 相对日期（转为绝对日期）
- 会话中的临时任务进度

输出格式（每条一行）：
(type) 摘要内容
例：
(user) 先生不喜欢表情包
(project) 地图子代理计划 2026-07-10 开始构建
```

3. **主代理收到 review 结果后**
   - 判断每一条的类型
   - 写入 long-term/ 对应文件
   - 更新 MEMORY.md 索引注释
   - 重置 turn 计数器
