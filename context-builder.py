#!/usr/bin/env python3
"""
情境信息构建脚本 — 天气 + 当前时间 + 今日日程
输出格式：标准文本块，供瑶光作为系统上下文注入

使用方式：
  python3 context-builder.py          # 打印情境信息
  python3 context-builder.py --check  # 验证模式（输出 JSON）
"""

import json
import urllib.request
import datetime
import sys

TIMEZONE = "Asia/Shanghai"


def get_time_context():
    now = datetime.datetime.now()
    weekdays = ["星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"]
    return {
        "datetime": now.strftime("%Y-%m-%d %H:%M"),
        "weekday": weekdays[now.weekday()],
        "hour": now.hour
    }


def get_weather():
    """从 wttr.in 获取天气（简约格式）"""
    url = "https://wttr.in/Shanghai?format=j1"
    try:
        req = urllib.request.urlopen(url, timeout=10)
        data = json.loads(req.read())
        current = data["current_condition"][0]
        return {
            "temp": current["temp_C"],
            "feels_like": current["FeelsLikeC"],
            "humidity": current["humidity"],
            "weather_desc": current["weatherDesc"][0]["value"],
            "wind_speed": current["windspeedKmph"],
            "wind_dir": current["winddir16Point"]
        }
    except Exception as e:
        return {"error": f"天气数据获取失败: {e}"}


def get_schedule():
    """解析 schedule.yaml（当前简单实现，Phase 2 支持重复日程）"""
    try:
        import yaml
        with open("schedule.yaml", "r") as f:
            data = yaml.safe_load(f)
    except FileNotFoundError:
        return {"events": []}
    except Exception:
        return {"events": []}

    now = datetime.datetime.now()
    today = now.strftime("%Y-%m-%d")
    hour = now.hour
    minute = now.minute

    if data is None:
        return {"events": []}
    today_events = []
    for event in data.get("events", []) or []:
        if event["date"] == today:
            event_hour, event_min = map(int, event["time"].split(":"))
            # 返回未来3小时内+当前已开始的日程
            if (event_hour > hour or (event_hour == hour and event_min >= minute)) and \
               (event_hour <= hour + 3):
                today_events.append(event)

    return {"events": today_events}


def build_context():
    """组装完整情境信息"""

    now_ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")

    lines = []
    lines.append(f"情境信息: [更新于 {now_ts}]")
    lines.append("")

    # 时间
    time_ctx = get_time_context()
    lines.append("## 📅 当前时间")
    lines.append(f"- {time_ctx['datetime']} {time_ctx['weekday']}")
    lines.append("")

    # 天气
    weather = get_weather()
    if "error" not in weather:
        lines.append("## 🌤️ 天气")
        lines.append(f"- {weather['weather_desc']}，{weather['temp']}°C（体感 {weather['feels_like']}°C）")
        lines.append(f"- 湿度 {weather['humidity']}%，{weather['wind_dir']}风 {weather['wind_speed']}km/h")
    else:
        lines.append(f"## 🌤️ 天气")
        lines.append(f"- {weather['error']}")
    lines.append("")

    # 日程
    schedule = get_schedule()
    if schedule["events"]:
        lines.append("## 📋 今日日程")
        for e in schedule["events"]:
            lines.append(f"- {e['time']} {e['title']}")
    else:
        lines.append("## 📋 今日日程")
        lines.append("- 暂无近期日程安排")
    lines.append("")

    # 时段问候
    hour = time_ctx["hour"]
    if hour < 6:
        lines.append("💡 深夜时段，瑶光应安静待命，除非紧急事件不主动打扰")
    elif hour < 9:
        lines.append("💡 早晨时段，可主动问候和汇报日程")
    elif hour < 12:
        lines.append("💡 上午时段，正常工作模式")
    elif hour < 14:
        lines.append("💡 午间时段")
    elif hour < 18:
        lines.append("💡 下午时段，正常工作模式")
    elif hour < 22:
        lines.append("💡 晚间时段")
    else:
        lines.append("💡 深夜时段，除非紧急不主动打扰")

    return "\n".join(lines)


def check_mode():
    """检查模式：验证所有组件是否正常工作，输出 JSON"""
    result = {
        "status": "ok",
        "checks": {}
    }

    # 检查时间
    time_ctx = get_time_context()
    result["checks"]["time"] = {
        "status": "ok",
        "data": time_ctx
    }

    # 检查天气
    weather = get_weather()
    if "error" not in weather:
        result["checks"]["weather"] = {
            "status": "ok",
            "data": weather
        }
    else:
        result["checks"]["weather"] = {
            "status": "error",
            "message": weather["error"]
        }
        result["status"] = "degraded"

    # 检查日程
    schedule = get_schedule()
    result["checks"]["schedule"] = {
        "status": "ok",
        "data": schedule
    }

    return result


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--check":
        print(json.dumps(check_mode(), indent=2, ensure_ascii=False))
    else:
        print(build_context())
