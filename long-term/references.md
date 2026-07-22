# References — 外部引用

> 类型：reference
> 最后更新：2026-07-22

---

## 关键配置参考

### 飞书通道（2026-07-22 起为唯一通道）

先生要求：所有消息推送全部走飞书，不再使用微信沟通。

```
--channel feishu \
--to ou_2e89db5e7367fa046af8335a03b80594
```

- 飞书目前是唯一投递通道
- 不需指定 accountId（default account 即可）
- 缺 `--to` 或 `--channel` 会导致投递失败或被拒绝

### 微信通道（已弃用）

- 通道仍处于 enabled 状态，但不作为消息推送目标
- 历史配置：accountId `27437355a7fd-im-bot`（原 a156aada4521-im-bot）
- 不会再有新的 cron 任务使用此通道投递

### 参考链接
- OpenClaw 安全文档：docs.openclaw.ai/gateway/security
- Qwen API：dashscope.aliyuncs.com (国内区 Standard)
- GitHub Copilot Embedding：text-embedding-3-small
- HERMES Agent 记忆架构（演讲稿收录）
- Claude Code 记忆架构（演讲稿收录）

## 服务器信息

- 腾讯云 LightHouse 轻量应用服务器
- IP: 49.235.164.60
- 系统: Ubuntu 6.8.0-124-generic

## SSL 证书

- 域名: www.jxpyaoguang.cloud
- 颁发机构: TrustAsia (腾讯云合作)
- 有效期: 2026-07-11 ~ 2026-10-09
- 私钥位置: /etc/nginx/ssl/jxpyaoguang.cloud.key
- 证书位置: /etc/nginx/ssl/jxpyaoguang.cloud.crt
