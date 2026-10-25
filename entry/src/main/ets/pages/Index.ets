/**
 * ============================================================
 *  LifeTimerPage — 主页（生命倒计时 + 习惯管理）
 *  HarmonyOS 7 毛玻璃设计风格
 * ============================================================
 *  导航结构（底部 Tab）：
 *    ┌──── 主页（Tab 0）────┐   ┌──── 我的（Tab 1）────┐
 *    │  - 生命倒计时看板     │   │  - 基础设置           │
 *    │  - 习惯调整（好/坏）   │   │    · 出生日期         │
 *    │  - 习惯编辑器弹窗     │   │    · 预期寿命         │
 *    └───────────────────────┘   │  - 数据管理           │
 *                                │    · 重置偏移量       │
 *                                └──────────────────────┘
 *  数据存储：life_timer_store（两个 Tab 共用）
 *    ┌──────────────┬─────────┬──────────────────────────────┐
 *    │ Key          │ Type    │ 说明                         │
 *    ├──────────────┼─────────┼──────────────────────────────┤
 *    │ birthDate    │ string  │ YYYY-MM-DD 格式的出生日期    │
 *    │ lifeExpectancy│ number │ 预期寿命（岁，1~150）        │
 *    │ offset       │ number  │ 所有习惯累计偏移天数          │
 *    │ habits       │ string  │ JSON 序列化的 HabitItem[]    │
 *    └──────────────┴─────────┴──────────────────────────────┘
 *  数据流：
 *    Tab 0（主页）：用户操作习惯 → saveData() 写入 Store
 *    Tab 1（我的）：修改设置 → saveData() 写入 Store → 实时刷新
 *  核心算法：
 *    总天数 = 预期寿命 × 365
 *    已过天数 = 当前时间 - 出生日期
 *    剩余天数 = 总天数 - 已过天数 + habitOffset
 *  设计风格：HarmonyOS 7 毛玻璃（Frosted Glass）
 *    卡片、导航栏、按钮统一使用 backdropBlur + 半透明底色
 * ============================================================
 */
import dataPreferences from '@ohos.data.preferences';

interface HabitItem {
  id: number;
  name: string;
  delta: number;
}

@Entry
@Component
struct LifeTimerPage {
  @State birthDate: Date = new Date(1997, 0, 1);
  @State lifeExpectancy: number = 40;
  @State habitOffset: number = 0;
  @State remainingDays: number = 0;
  @State remainingPercent: number = 0;
  @State elapsedPercent: number = 0;
  @State currentTimeStr: string = '';
  @State habits: HabitItem[] = [];
  @State showHabitEditor: boolean = false;
  @State editingHabitId: number = -1;
  @State editHabitName: string = '';
  @State editHabitDelta: string = '';
  @State currentTab: number = 0;
  @State progressColor: string = '#44cc77';
  private readonly STORE_NAME: string = 'life_timer_store';
  private timerId: number = -1;

  // ==================== 生命周期 ====================

  aboutToAppear(): void {
    this.loadData();
    this.startTimer();
  }

  onPageShow(): void {
    this.loadData();
  }

  aboutToDisappear(): void {
    this.stopTimer();
  }

  startTimer(): void {
    this.stopTimer();
    this.timerId = setInterval(() => {
      this.updateCurrentTime();
      this.calculateRemaining();
    }, 60000);
  }

  stopTimer(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  updateCurrentTime(): void {
    const now: Date = new Date();
    const y: number = now.getFullYear();
    const m: string = String(now.getMonth() + 1).padStart(2, '0');
    const d: string = String(now.getDate()).padStart(2, '0');
    const h: string = String(now.getHours()).padStart(2, '0');
    const min: string = String(now.getMinutes()).padStart(2, '0');
    this.currentTimeStr = `${y}.${m}.${d} ${h}:${min}`;
  }

  calculateRemaining(): void {
    const now: Date = new Date();
    const baseTotal: number = this.lifeExpectancy * 365;
    const adjustedTotal: number = baseTotal + this.habitOffset;
    const birth: Date = new Date(this.birthDate);
    const elapsedTime: number = now.getTime() - birth.getTime();
    const elapsedDays: number = Math.floor(elapsedTime / (1000 * 60 * 60 * 24));
    const remaining: number = adjustedTotal - elapsedDays;
    this.remainingDays = Math.max(0, remaining);
    this.elapsedPercent = Math.min(100, (elapsedDays / adjustedTotal) * 100);
    this.remainingPercent = Math.max(0, 100 - this.elapsedPercent);
    this.progressColor = this.calcProgressColor();
  }

  async loadData(): Promise<void> {
    try {
      const pref: dataPreferences.Preferences = await dataPreferences.getPreferences(getContext(), this.STORE_NAME);
      const birthStr: string = pref.getSync('birthDate', '1997-01-01') as string;
      this.birthDate = new Date(birthStr);
      const exp: number = pref.getSync('lifeExpectancy', 40) as number;
      this.lifeExpectancy = typeof exp === 'number' && exp > 0 ? exp : 40;
      const offset: number = pref.getSync('offset', 0) as number;
      this.habitOffset = typeof offset === 'number' ? offset : 0;
      const habitsStr: string = pref.getSync('habits', '[]') as string;
      const parsed: object = JSON.parse(habitsStr);
      this.habits = Array.isArray(parsed) ? (parsed as HabitItem[]) : [];
    } catch (_err) {
      this.birthDate = new Date(1997, 0, 1);
      this.lifeExpectancy = 40;
      this.habitOffset = 0;
      this.habits = [];
    }
    this.initDefaultHabits();
    this.calculateRemaining();
    this.updateCurrentTime();
  }

  async saveData(): Promise<void> {
    try {
      const pref: dataPreferences.Preferences = await dataPreferences.getPreferences(getContext(), this.STORE_NAME);
      const y: number = this.birthDate.getFullYear();
      const m: string = String(this.birthDate.getMonth() + 1).padStart(2, '0');
      const d: string = String(this.birthDate.getDate()).padStart(2, '0');
      pref.putSync('birthDate', `${y}-${m}-${d}`);
      pref.putSync('lifeExpectancy', this.lifeExpectancy);
      pref.putSync('offset', this.habitOffset);
      pref.putSync('habits', JSON.stringify(this.habits));
      pref.flushSync();
    } catch (_err) {}
  }

  handleResetWithConfirm(): void {
    AlertDialog.show({
      title: '重置确认',
      message: '确定要重置所有习惯偏移数据吗？此操作不可撤销！',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '重置', fontColor: '#ff4466',
        action: () => {
          this.habitOffset = 0;
          this.saveData();
          this.calculateRemaining();
        }
      }
    });
  }

  initDefaultHabits(): void {
    if (this.habits.length === 0) {
      const defaults: HabitItem[] = [
        { id: 1, name: '🏃 晨跑30分', delta: 2 },
        { id: 2, name: '📖 阅读1小时', delta: 1 },
        { id: 3, name: '🚬 吸烟', delta: -3 },
        { id: 4, name: '🌙 熬夜', delta: -1 }
      ];
      this.habits = defaults;
      this.applyHabit();
      this.saveData();
    }
  }

  applyHabit(): void {
    let total: number = 0;
    for (const h of this.habits) {
      total += h.delta;
    }
    this.habitOffset = total;
    this.calculateRemaining();
  }

  /** 点击单个习惯：应用其 delta → 加减剩余天数 */
  applySingleHabit(habit: HabitItem): void {
    this.habitOffset += habit.delta;
    this.calculateRemaining();
    this.saveData();
  }

  openAddHabit(): void {
    this.editingHabitId = -1;
    this.editHabitName = '';
    this.editHabitDelta = '';
    this.showHabitEditor = true;
  }

  openEditHabit(habit: HabitItem): void {
    this.editingHabitId = habit.id;
    this.editHabitName = habit.name;
    this.editHabitDelta = String(habit.delta);
    this.showHabitEditor = true;
  }

  deleteHabit(habit: HabitItem): void {
    AlertDialog.show({
      title: '删除习惯',
      message: `确定要删除「${habit.name}」吗？`,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '删除', fontColor: '#ff4466',
        action: () => {
          this.habits = this.habits.filter(h => h.id !== habit.id);
          this.applyHabit();
          this.saveData();
        }
      }
    });
  }

  confirmSaveHabit(): void {
    const name: string = this.editHabitName.trim();
    const deltaNum: number = parseInt(this.editHabitDelta) || 0;
    if (!name) return;
    if (this.editingHabitId === -1) {
      const maxId: number = this.habits.reduce((max, h) => Math.max(max, h.id), 0);
      this.habits = [...this.habits, { id: maxId + 1, name, delta: deltaNum }];
    } else {
      this.habits = this.habits.map(h =>
        h.id === this.editingHabitId ? { id: h.id, name: name, delta: deltaNum } : h
      );
    }
    this.saveData();
    this.showHabitEditor = false;
  }

  cancelEditHabit(): void {
    this.showHabitEditor = false;
  }

  /** 进度条颜色：剩余越多越绿(#44cc77)，剩余越少越红(#ff4466) */
  calcProgressColor(): string {
    const p = this.remainingPercent / 100;
    const r = Math.round(255 - (255 - 68) * p);
    const g = Math.round(68 + (204 - 68) * p);
    const b = Math.round(102 + (119 - 102) * p);
    return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`;
  }

  // ==================== build ====================

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [['#070714', 0], ['#0d0d24', 0.5], ['#12122e', 1]]
        })

      // Tab 内容区（手动切换，不用 Tabs 内建 bar）
      Column() {
        if (this.currentTab === 0) {
          this.HomeTab()
        } else {
          this.ProfileTab()
        }
      }
      .width('100%')
      .height('100%')
      .padding({ bottom: 96 })

      // ── 悬浮玻璃导航栏 ──
      Row() {
        Column() {
          Text('🏠').fontSize(22)
          Text('主页').fontSize(11).margin({ top: 2 })
        }
        .width('50%')
        .height(44)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.currentTab === 0 ? 'rgba(255,255,255,0.12)' : 'transparent')
        .backdropBlur(this.currentTab === 0 ? 12 : 0)
        .borderRadius(22)
        .onClick(() => { this.currentTab = 0 })

        Column() {
          Text('⚙️').fontSize(22)
          Text('设置').fontSize(11).margin({ top: 2 })
        }
        .width('50%')
        .height(44)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.currentTab === 1 ? 'rgba(255,255,255,0.12)' : 'transparent')
        .backdropBlur(this.currentTab === 1 ? 12 : 0)
        .borderRadius(22)
        .onClick(() => { this.currentTab = 1 })
      }
      .width('calc(100% - 32px)')
      .height(60)
      .padding({ left: 4, right: 4 })
      .backgroundColor('rgba(22, 22, 42, 0.7)')
      .backdropBlur(24)
      .borderRadius(30)
      .border({ width: 1, color: 'rgba(255,255,255,0.08)' })
      .shadow({ radius: 16, color: 'rgba(0,0,0,0.4)', offsetX: 0, offsetY: 6 })
      .position({ bottom: 24 })

      if (this.showHabitEditor) {
        Column() {
          Column() {
            Text(this.editingHabitId === -1 ? '添加习惯' : '编辑习惯')
              .fontSize(18).fontColor('#ffffff').fontWeight(FontWeight.Bold)

            TextInput({ text: this.editHabitName, placeholder: '习惯名称' })
              .width('100%').height(44)
              .backgroundColor('rgba(255,255,255,0.06)')
              .borderRadius(22).fontColor('#ffffff')
              .placeholderColor('rgba(255,255,255,0.3)')
              .margin({ top: 20 })
              .padding({ left: 16 })
              .onChange((val: string) => { this.editHabitName = val })

            TextInput({ text: this.editHabitDelta, placeholder: '影响天数（正=延寿，负=减寿）' })
              .width('100%').height(44)
              .backgroundColor('rgba(255,255,255,0.06)')
              .borderRadius(22).fontColor('#ffffff')
              .placeholderColor('rgba(255,255,255,0.3)')
              .margin({ top: 12 })
              .padding({ left: 16 })
              .onChange((val: string) => { this.editHabitDelta = val })

            Row() {
              Button('取消')
                .height(40).layoutWeight(1)
                .backgroundColor('rgba(255,255,255,0.08)')
                .backdropBlur(12)
                .borderRadius(20).fontColor('rgba(255,255,255,0.7)')
                .border({ width: 1, color: 'rgba(255,255,255,0.06)' })
                .onClick(() => { this.cancelEditHabit() })

              if (this.editingHabitId !== -1) {
                Button('删除')
                  .height(40).layoutWeight(1)
                  .backgroundColor('rgba(255,68,102,0.15)')
                  .backdropBlur(12)
                  .borderRadius(20).fontColor('#ff4466')
                  .border({ width: 1, color: 'rgba(255,68,102,0.15)' })
                  .margin({ left: 12 })
                  .onClick(() => {
                    const habit = this.habits.find(h => h.id === this.editingHabitId);
                    if (habit) this.deleteHabit(habit);
                    this.cancelEditHabit();
                  })
              }

              Button('保存')
                .height(40).layoutWeight(1)
                .backgroundColor('rgba(68, 170, 255, 0.2)')
                .backdropBlur(12)
                .borderRadius(20).fontColor('#44aaff')
                .border({ width: 1, color: 'rgba(68,170,255,0.15)' })
                .margin({ left: 12 })
                .onClick(() => { this.confirmSaveHabit() })
            }
            .width('100%').margin({ top: 20 })
          }
          .width('85%').padding(24)
          .backgroundColor('rgba(22, 22, 42, 0.85)')
          .backdropBlur(20)
          .borderRadius(24)
          .border({ width: 1, color: 'rgba(255,255,255,0.06)' })
        }
        .width('100%').height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(0,0,0,0.5)')
        .backdropBlur(8)
        .onClick(() => { this.cancelEditHabit() })
      }
    }
    .width('100%')
    .height('100%')
  }

  // ==================== @Builder ====================

  @Builder
  HomeTab() {
    Column() {
      // 标题区
      this.titleSection()

      // 可滚动内容
      Scroll() {
        Column() {
          // 倒计时卡片
          this.countdownCard()
          // 习惯卡片
          this.habitsCard()
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 8 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  titleSection() {
    Row() {
      Column() {
        Text('⏳ 生命倒计时')
          .fontSize(22)
          .fontColor('#ffffff')
          .fontWeight(FontWeight.Bold)
      }
      .layoutWeight(1)

      Text(this.currentTimeStr)
        .fontSize(13)
        .fontColor('rgba(255,255,255,0.5)')
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 14, bottom: 14 })
    .backgroundColor('rgba(22, 22, 42, 0.45)')
    .backdropBlur(18)
    .borderRadius(18)
    .border({ width: 1, color: 'rgba(255,255,255,0.05)' })
    .margin({ top: 12, left: 16, right: 16 })
  }

  @Builder
  countdownCard() {
    Column() {
      // 天数主显区
      Row() {
        Text(this.remainingDays.toLocaleString())
          .fontSize(52)
          .fontColor('#ffffff')
          .fontWeight(FontWeight.Bold)
        Text('天')
          .fontSize(18)
          .fontColor('rgba(255,255,255,0.4)')
          .margin({ left: 6, bottom: 8 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      Text('剩余天数')
        .fontSize(14)
        .fontColor('rgba(255,255,255,0.5)')
        .margin({ top: -4 })

      // 进度条（值=已剩余%，颜色随剩余量变化）
      Progress({ value: this.remainingPercent, total: 100, type: ProgressType.Linear })
        .width('100%')
        .height(8)
        .color(this.progressColor)
        .backgroundColor('rgba(255,255,255,0.08)')
        .borderRadius(4)
        .margin({ top: 16 })

      // 百分比标签
      Row() {
        Text(`已剩余 ${this.remainingPercent.toFixed(1)}%`)
          .fontSize(12)
          .fontColor('rgba(255,255,255,0.35)')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 6 })

      // 偏移信息
      Row() {
        Text(`习惯偏移`)
          .fontSize(12)
          .fontColor('rgba(255,255,255,0.3)')
        Text(this.habitOffset >= 0 ? `+${this.habitOffset}天` : `${this.habitOffset}天`)
          .fontSize(13)
          .fontColor(this.habitOffset >= 0 ? '#44cc77' : '#ff4466')
          .fontWeight(FontWeight.Medium)
          .margin({ left: 4 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ top: 10 })
    }
    .width('100%')
    .padding(20)
    .backgroundColor('rgba(22, 22, 42, 0.55)')
    .backdropBlur(20)
    .borderRadius(20)
    .border({ width: 1, color: 'rgba(255,255,255,0.06)' })
    .margin({ top: 12 })
  }

  @Builder
  habitsCard() {
    Column() {
      // 标题行
      Row() {
        Text('🎯 习惯调整')
          .fontSize(18)
          .fontColor('#ffffff')
          .fontWeight(FontWeight.Bold)

        Button() {
          Text('＋ 添加习惯').fontSize(14).fontColor('#ffffff')
        }
        .height(38)
        .padding({ left: 18, right: 18 })
        .backgroundColor('rgba(68,170,255,0.2)')
        .backdropBlur(12)
        .borderRadius(19)
        .border({ width: 1, color: 'rgba(255,255,255,0.08)' })
        .onClick(() => { this.openAddHabit() })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      if (this.habits.length > 0) {
        if (this.habits.filter((h: HabitItem) => h.delta > 0).length > 0) {
          Text('✅ 好习惯').fontSize(12).fontColor('#44cc77')
            .width('100%').margin({ top: 12 })
          Row() { }.width('100%').height(6)
          Grid() {
            ForEach(this.habits.filter((h: HabitItem) => h.delta > 0), (habit: HabitItem) => {
              GridItem() { this.habitTile(habit) }
            }, (habit: HabitItem) => String(habit.id) + '_' + String(habit.delta))
          }
          .columnsTemplate('1fr 1fr')
          .columnsGap(8)
          .rowsGap(8)
        }
        if (this.habits.filter((h: HabitItem) => h.delta < 0).length > 0) {
          Text('❌ 坏习惯').fontSize(12).fontColor('#ff4466')
            .width('100%').margin({ top: 10 })
          Row() { }.width('100%').height(6)
          Grid() {
            ForEach(this.habits.filter((h: HabitItem) => h.delta < 0), (habit: HabitItem) => {
              GridItem() { this.habitTile(habit) }
            }, (habit: HabitItem) => String(habit.id) + '_' + String(habit.delta))
          }
          .columnsTemplate('1fr 1fr')
          .columnsGap(8)
          .rowsGap(8)
        }
      } else {
        Text('暂无习惯，点击右上角 ＋ 添加')
          .fontSize(13).fontColor('rgba(255,255,255,0.3)')
          .margin({ top: 24 })
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor('rgba(22, 22, 42, 0.55)')
    .backdropBlur(20)
    .borderRadius(20)
    .border({ width: 1, color: 'rgba(255,255,255,0.06)' })
    .margin({ top: 12 })
  }

  @Builder
  habitTile(habit: HabitItem) {
    Row() {
      // 左侧：习惯信息
      Column() {
        Text(habit.name)
          .fontSize(13)
          .fontColor('#ffffff')
          .lineHeight(18)

        Text(habit.delta > 0 ? `+${habit.delta}天` : `${habit.delta}天`)
          .fontSize(11)
          .fontColor(habit.delta > 0 ? '#44cc77' : '#ff4466')
          .fontWeight(FontWeight.Medium)
          .lineHeight(16)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(60)
    .padding({ left: 16, right: 16 })
    .backgroundColor('rgba(255,255,255,0.06)')
    .backdropBlur(12)
    .borderRadius(30)
    .border({ width: 1, color: 'rgba(255,255,255,0.06)' })
    // 点击 → 应用习惯 delta，加减剩余天数
    .onClick(() => {
      this.applySingleHabit(habit);
    })
    // 长按 → 打开编辑弹窗
    .gesture(
      LongPressGesture({ repeat: false, duration: 400 })
        .onAction(() => { this.openEditHabit(habit) })
    )
  }

  @Builder
  resetButton() {
    Row() {
      Text('🗑️ 重置所有习惯数据')
        .fontSize(14)
        .fontColor('#ff4466')
    }
    .width('100%')
    .height(44)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('rgba(255,68,102,0.1)')
    .backdropBlur(12)
    .borderRadius(22)
    .border({ width: 1, color: 'rgba(255,68,102,0.12)' })
    .margin({ top: 8 })
    .onClick(() => { this.handleResetWithConfirm() })
  }

  @Builder
  ProfileTab() {
    Column() {
      Text('⚙️ 设置')
        .fontSize(22).fontColor('#ffffff').fontWeight(FontWeight.Bold)
        .width('100%').padding({ left: 20, top: 16 })

      Scroll() {
        Column() {
          this.settingsCard()
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 16 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  settingsCard() {
    Column() {
      // ── 📅 出生日期 区块 ──
      Column() {
        Text('📅 出生日期')
          .fontSize(12).fontColor('rgba(255,255,255,0.45)')
          .width('100%')
        DatePicker({
          start: new Date(1900, 0, 1),
          end: new Date(),
          selected: this.birthDate
        })
        .width('100%').height(140)
        .onDateChange((value: Date) => {
          this.birthDate = value;
          this.calculateRemaining();
          this.saveData();
        })
      }
      .width('100%')
      .padding(14)
      .backgroundColor('rgba(255,255,255,0.04)')
      .borderRadius(22)
      .border({ width: 1, color: 'rgba(255,255,255,0.06)' })

      // ── 🎯 预期寿命 区块 ──
      Column() {
        Text('🎯 预期寿命（岁）')
          .fontSize(12).fontColor('rgba(255,255,255,0.45)')
          .width('100%')
        TextInput({ text: String(this.lifeExpectancy), placeholder: '1~150' })
          .width('100%').height(36)
          .backgroundColor('rgba(255,255,255,0.06)')
          .borderRadius(18).fontColor('#ffffff')
          .placeholderColor('rgba(255,255,255,0.3)')
          .type(InputType.Number)
          .padding({ left: 14 })
          .onChange((val: string) => {
            const n: number = parseInt(val);
            this.lifeExpectancy = isNaN(n) ? 0 : Math.max(0, Math.min(150, n));
          })
          .onBlur(() => {
            this.calculateRemaining();
            this.saveData();
          })
      }
      .width('100%')
      .padding(14)
      .backgroundColor('rgba(255,255,255,0.04)')
      .borderRadius(22)
      .border({ width: 1, color: 'rgba(255,255,255,0.06)' })
      .margin({ top: 10 })

      // ── 📊 数据 区块 ──
      Column() {
        Row() {
          Text('📊 当日偏移').fontSize(13).fontColor('rgba(255,255,255,0.6)')
          Text(`${this.habitOffset > 0 ? '+' : ''}${this.habitOffset} 天`)
            .fontSize(13).fontColor(this.habitOffset >= 0 ? '#44cc77' : '#ff4466')
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .height(36)

        Row() { }.width('100%').height(1)
          .backgroundColor('rgba(255,255,255,0.06)')
          .margin({ top: 4, bottom: 8 })

        Row() {
          Text('🗑️ 重置所有数据')
            .fontSize(13).fontColor('#ff4466')
        }
        .width('100%').height(40)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(255,68,102,0.08)')
        .backdropBlur(12)
        .borderRadius(20)
        .border({ width: 1, color: 'rgba(255,68,102,0.1)' })
        .onClick(() => { this.handleResetWithConfirm() })
      }
      .width('100%')
      .padding(14)
      .backgroundColor('rgba(255,255,255,0.04)')
      .borderRadius(22)
      .border({ width: 1, color: 'rgba(255,255,255,0.06)' })
      .margin({ top: 10 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('rgba(22, 22, 42, 0.55)')
    .borderRadius(26)
    .border({ width: 1, color: 'rgba(255,255,255,0.05)' })
    .backdropBlur(20)
  }
}
