# 日子有数 0.3.0

个人离线倒数日与纪念日应用。Flutter 实现，Android 优先，预留 iOS 工程。界面采用已确认的 A「温暖手账」设计。

## 安装

本次安装包：`dist/life-days-0.3.0.apk`（约 54 MB），支持 Android 7.0/API 24 及以上，包含 ARM64、ARMv7、x86_64。

包名和签名与 0.1.0 / 0.2.0 相同，版本号递增，可直接覆盖安装。不要先卸载旧版，以免清除应用数据。当前仍使用个人测试证书签名。

## 功能与日期规则

- 纪念日：从起始日期持续累计，跨周年不归零；可选起始日算第 1 天；详情显示下一个周年。
- 倒计时：不重复、每周、每年。未重复的事件过期后显示“已结束 · 过去 N 天”，可手动归档。
- 生日模板：倒计时 + 每年重复；当天显示生日祝福，次日自动计算下一次。可选填写真实出生年份后显示年龄。
- 农历日期：支持 1900–2100 年的农历年月日，自动换算公历；可记农历纪念日或每年重复的农历生日。
- 闰月生日：可选有闰月过闰月、无闰月过普通月，或每年只过普通月；普通月生日不额外在闰月重复。
- 农历三十遇小月：可选本月廿九或下月初一。
- 2 月 29 日：年度事件可选非闰年按 2 月 28 日或 3 月 1 日计算。
- 图标、备注、置顶；全部/纪念日/倒计时/归档分类；详情编辑、删除、归档和恢复。
- JSON/CSV 导入预览、校验与去重合并；JSON 分享导出备份。

天数按手机本地日历日期计算，忽略当天的小时和分钟。默认纪念日起始当天为 0 天，第二天为 1 天。农历换算离线运行。应用没有通知提醒、桌面小组件或云同步。

## 电脑输入 → 手机导入

双击打开 `tools/电脑事件编辑器.html`，选择类型、填写事件并下载 JSON；将文件传到手机，点击应用的“电脑导入”入口。该编辑器不联网，关闭或刷新前请下载文件。

也可以用 Excel/WPS 打开 `examples/events.csv`，将日期列设为文本，另存为 **CSV UTF-8**。JSON 模板为 `examples/events.json`。

字段说明：

| 字段 | 含义 |
|---|---|
| title / date | 必填；名称和 YYYY-MM-DD 日期 |
| type | anniversary 纪念日 / countdown 倒计时 |
| repeat | none / weekly / yearly；纪念日须为 none |
| pinned / inclusive | 置顶 / 纪念日起始日算第 1 天 |
| birthday / show_age | 生日模式 / 根据出生年份显示年龄；生日须 countdown + yearly |
| leap_policy | 公历闰日：feb28 / mar1 |
| calendar | solar（默认）/ lunar |
| lunar_year / lunar_month / lunar_day | 农历事件必填整数；年份 1900–2100，月份 1–12，闰月用 -1 至 -12，日期 1–30；必须为实际存在的农历日期 |
| lunar_leap_policy | prefer-leap（默认）/ regular |
| lunar_short_policy | last（默认）/ next |
| icon / notes | 图标 / 备注 |
| archived | 是否归档 |

农历事件的 `date` 仍需填写对应的原始公历日期，导入时会校验双历一致性；电脑编辑器会自动换算。农历不支持每周重复。农历示例见 `examples/lunar-birthdays.json` 和 `examples/lunar-birthdays.csv`。

布尔值用 true/false，CSV 也接受 1/0。单次最多 5 MB、5000 条；任何记录错误都会阻止本次导入。相同名称、日期、类型、重复规则和历法的事件跳过，不覆盖旧事件；需要更改已有事件时请在应用中编辑。

旧文件不含 type 时：过去且不重复的事件识别为纪念日，其余识别为倒计时。导入后会保存明确类型。旧版应用数据首次打开自动迁移到版本 3，并在应用私有目录保留对应的 `events-v1-backup.json` 或 `events-v2-backup.json` 原始备份。迁移前的年度事件保持倒计时，可以编辑并开启“这是生日”。

卸载应用会清除数据。定期导出 JSON 到电脑。备份不加密。

## 本机构建

工具链安装在 `/Users/khalid/workspace/.toolchains`，包含 Flutter 3.47.9、Java 21、Android SDK/NDK/CMake。

```sh
LIFE_DAYS_MAVEN_MIRROR=1 LIFE_DAYS_DIRECT=1 tools/build-apk.sh
```

`LIFE_DAYS_MAVEN_MIRROR=1` 启用可选 Maven 镜像；`LIFE_DAYS_DIRECT=1` 仅为当前构建关闭代理设置，不修改系统代理。构建输出为 `build/app/outputs/flutter-apk/app-release.apk`；`dist/` 为本次交付文件。

## 验证

静态检查通过；34 项 Flutter 自动测试通过，覆盖累计天数、重复日期、生日年龄、闰年、导入校验、旧版迁移与原始备份、数据重导入、编辑表单、手机小屏分类/详情/置顶、归档恢复，以及农历换算锚点、闰月、小月顺延跨年、农历年龄、双历导入校验和农历表单保存。

APK 已检查版本、包名、架构、启动入口及签名，并与旧版签名核对一致。当前没有连接安卓设备，尚未进行真机安装、文件选择、分享与系统杀进程后的存储验收；iOS 尚未构建或验证。
