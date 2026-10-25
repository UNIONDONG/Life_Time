# Life Time — 架构说明

> 快速了解项目结构、数据流和关键设计决策。供开发者下次接手时 5 分钟内恢复上下文。

---

## 一、项目全景

```
Life_Time (HAP: entry)
├── EntryAbility.ets          # 应用入口，启动页设置为 Index
├── pages/
│   ├── Index.ets             # 唯一页面：底部 Tab 导航
│   │   ├── Tab 0「主页」      # 生命倒计时 + 习惯管理
│   │   └── Tab 1「我的」      # 基础设置 + 重置偏移量
│   └── Settings.ets          # [已废弃] 功能已并入 Index 的「我的」Tab
└── entrybackupability/
    └── EntryBackupAbility.ets # 数据备份/恢复扩展
```

---

## 二、数据流（核心！）

### 存储方案

- **技术**: `@ohos.data.preferences`（键值对持久化）
- **Store 名称**: `life_timer_store`（**两个页面共用**）

### 存储结构

| Key | Type | 写入方 | 说明 |
|-----|------|--------|------|
| `birthDate` | `string` | Index + Settings | `YYYY-MM-DD` 格式 |
| `lifeExpectancy` | `number` | Index + Settings | 预期寿命（岁），1~150 |
| `offset` | `number` | Index | 所有习惯累计偏移天数 |
| `habits` | `string` | Index | JSON 序列化的 `HabitItem[]` |

### 数据流向

```
                    ┌──────────────────┐
                    │  life_timer_store │  ← Preferences 持久化
                    └────────┬─────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼                             ▼
     ┌──────────────────┐        ┌──────────────────┐
     │  Tab 0「主页」     │        │  Tab 1「我的」     │
     │  loadData()       │        │  设置出生日期     │
     │  saveData()       │        │  设置预期寿命     │
     │  应用/管理习惯    │        │  重置偏移量       │
     └──────────────────┘        └──────────────────┘
```

### 关键时序

```
启动 App
  └→ aboutToAppear() → loadData() → 渲染 Tab 0「主页」

用户在 Tab 1「我的」修改出生日期
  └→ DatePicker.onChange → saveData() → calculateRemaining()

用户在 Tab 0「主页」添加习惯
  └→ 打开编辑器 → confirmSaveHabit() → saveData()

用户在 Tab 0「主页」应用习惯
  └→ applyHabit() → saveData() → calculateRemaining()

用户在 Tab 1「我的」重置偏移量
  └→ handleResetWithConfirm() → saveData() → calculateRemaining()
```

> **优势**：由于在同一页面内通过 Tabs 切换，不再需要页面间路由（router），设置修改后实时生效。

---

## 三、核心算法

```
总天数   = lifeExpectancy × 365
已过天数 = now - birthDate（取 UTC 日差）
剩余天数 = 总天数 - 已过天数 + habitOffset
剩余百分比 = (剩余天数 / 总天数) × 100
```

> **注意**: `habitOffset` 是用户手动"应用"习惯时累加的，不是自动计算的。

---

## 四、已踩过的坑（TODO / 注意事项）

| 坑 | 状态 | 说明 |
|----|------|------|
| ❌ 两个 Store 名不同 | ✅ 已修复 | ~~原来 Index 用 `life_timer_store`，Settings 用 `life_timer_settings`，导致设置页修改不生效~~ |
| ⚠️ 日期格式统一 | ✅ 已统一 | 统一使用 `YYYY-MM-DD` 字符串，避免 `toISOString()` 带时区的日期偏移问题 |
| ⚠️ 首次无数据 | 默认值兜底 | `loadData()` 和 `loadPref()` 均有默认值（1990-01-01 / 80岁） |
| ⚠️ 习惯列表为空 | 内置示例 | 首次进入自动初始化 5 个示例习惯 |

---

## 五、快速定位指南

| 想找什么 | 位置 | 说明 |
|---------|------|------|
| 数据加载 | `Index.ets` `loadData()` | `aboutToAppear` 时调用 |
| 数据保存 | `Index.ets` `saveData()` | 修改后即时调用 |
| 倒计时计算 | `Index.ets` `calculateRemaining()` | 核心算法 |
| 主页 Tab | `Index.ets` `build()` → TabContent 0 | 含 countdownCard + habitsCard |
| 我的 Tab | `Index.ets` `profileTab()` | 含 profileSettingsCard + profileDataCard |
| 习惯编辑器 | `Index.ets` 搜索 `showHabitEditor` | 弹出层覆盖 |
| 重置偏移量 | `Index.ets` `handleResetWithConfirm()` | 在「我的」Tab 中 |
| 底部导航栏 | `Index.ets` `TabBuilder()` | Tabs 组件 + 自定义 tabBar |

---

> **下次接手**: 先看本文件 → 看 Index.ets 顶部的架构注释 → 直接定位到目标函数。
> **注意**: Settings.ets 已废弃，所有功能集成在 Index.ets 的「我的」Tab 中。
