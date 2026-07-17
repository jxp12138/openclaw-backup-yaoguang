# References — 外部引用

> 类型：reference
> 最后更新：2026-07-09

---

## 关键配置参考

### 微信 Cron 任务投递配置

涉及微信通道的 cron 定时任务，必须指定以下参数，否则会投递失败：

```
--channel openclaw-weixin \
--to o9cq804w47SH7hYDuhx9MN93h2sM@im.wechat \
--account a156aada4521-im-bot
```

- 先生微信用户 ID：`o9cq804w47SH7hYDuhx9MN93h2sM@im.wechat`
- 微信通道 accountId：`a156aada4521-im-bot`
- 缺 `--to` 会报 `Delivering to openclaw-weixin requires target`
- 缺 `--account`（多账号场景下）可能发错账号

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
