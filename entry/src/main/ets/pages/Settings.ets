/**
 * ============================================================
 *  SettingsPage — 设置页面
 * ============================================================
 *  数据存储（与 Index.ets 共享同一 Store）：
 *    Store 名 : life_timer_store
 *    ┌──────────────┬─────────┬──────────────────────────────┐
 *    │ Key          │ Type    │ 说明                         │
 *    ├──────────────┼─────────┼──────────────────────────────┤
 *    │ birthDate    │ string  │ YYYY-MM-DD 格式的出生日期    │
 *    │ lifeExpectancy│ number │ 预期寿命（岁，1~150）        │
 *    │ offset       │ number  │ 所有习惯累计偏移天数          │
 *    │ habits       │ string  │ JSON 序列化的 HabitItem[]    │
 *    └──────────────┴─────────┴──────────────────────────────┘
 *  数据流：
 *    Settings 修改 → savePref() 写 Store → router.back()
 *    → Index.onPageShow() → loadData() 读 Store → UI 刷新
 * ============================================================
 */
import dataPreferences from '@ohos.data.preferences';
import router from '@ohos.router';

/** 与 Index.ets 共享的 Preferences Store 名称 */
const STORE_NAME = 'life_timer_store';

interface LoadResult {
  birthDate: Date;
  lifeExpectancy: number;
}

/** 从 Preferences 加载出生日期和预期寿命 */
async function loadPref(context: Context): Promise<LoadResult> {
  let birthDate = new Date(1997, 0, 1);
  let lifeExpectancy = 40;

  try {
    const store = await dataPreferences.getPreferences(context, STORE_NAME);
    const bd = await store.get('birthDate', '');
    const le = await store.get('lifeExpectancy', 40);
    if (bd !== '') {
      birthDate = new Date(bd as string);
    }
    if (typeof le === 'number') {
      lifeExpectancy = le as number;
    }
  } catch (_) { /* 首次运行，用默认值 */ }

  return { birthDate: birthDate, lifeExpectancy: lifeExpectancy };
}

/** 保存到 Preferences（格式与 Index.ets 保持一致） */
async function savePref(context: Context, birthDate: Date, lifeExpectancy: number) {
  try {
    const store = await dataPreferences.getPreferences(context, STORE_NAME);
    // 使用 YYYY-MM-DD 格式，与 Index.ets 保持一致
    const dateStr = `${birthDate.getFullYear()}-${String(birthDate.getMonth() + 1).padStart(2, '0')}-${String(birthDate.getDate()).padStart(2, '0')}`;
    await store.put('birthDate', dateStr);
    await store.put('lifeExpectancy', lifeExpectancy);
    await store.flush();
  } catch (_) { /* ignore */ }
}

@Entry
@Component
struct SettingsPage {
  @State birthDate: Date = new Date(1997, 0, 1);
  @State lifeExpectancy: number = 40;

  aboutToAppear() {
    loadPref(getContext(this)).then((r: LoadResult) => {
      this.birthDate = r.birthDate;
      this.lifeExpectancy = r.lifeExpectancy;
    });
  }

  build() {
    Column() {
      // ---------- 顶部导航栏 ----------
      Row() {
        // 返回按钮
        Button({ type: ButtonType.Normal }) {
          Text('‹ 返回')
            .fontSize(18)
            .fontColor('#44aaff')
        }
        .backgroundColor('transparent')
        .onClick(() => {
          router.back();
        })

        Blank()

        Text('⚙️ 基础设置')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#c0c0d0')

        Blank()
      }
      .width('100%')
      .padding({ top: 12, bottom: 4, left: 8, right: 8 })

      // ---------- 设置内容 ----------
      Scroll() {
        Column() {
          // ---- 出生日期卡片 ----
          Column() {
            Row() {
              Text('🎂 出生日期')
                .fontSize(15)
                .fontColor('#aaaabb')
            }
            .width('100%')
            .margin({ bottom: 8 })

            DatePicker({
              start: new Date(1900, 0, 1),
              end: new Date(),
              selected: this.birthDate
            })
              .height(140)
              .disappearTextStyle({
                color: '#444466',
                font: { size: '12fp' }
              })
              .textStyle({
                color: '#ccccdd',
                font: { size: '14fp' }
              })
              .selectedTextStyle({
                color: '#ffffff',
                font: { size: '16fp' }
              })
              .onDateChange((value: Date) => {
                this.birthDate = value;
                savePref(getContext(this), value, this.lifeExpectancy);
              })
          }
          .backgroundColor('#16162a')
          .borderRadius(16)
          .padding(16)
          .width('100%')

          // ---- 预期寿命卡片 ----
          Column() {
            Row() {
              Text('📅 预期寿命')
                .fontSize(15)
                .fontColor('#aaaabb')
              Blank()
              Row() {
                TextInput({ text: this.lifeExpectancy.toString() })
                  .width(80)
                  .height(40)
                  .type(InputType.Number)
                  .backgroundColor('#1e1e34')
                  .fontColor('#ffffff')
                  .fontSize(15)
                  .borderRadius(8)
                  .textAlign(TextAlign.Center)
                  .onChange((value: string) => {
                    const num: number = parseInt(value, 10);
                    if (!isNaN(num) && num > 0 && num <= 150) {
                      this.lifeExpectancy = num;
                    }
                  })
                  .onBlur(() => {
                    savePref(getContext(this), this.birthDate, this.lifeExpectancy);
                  })
                Text('岁')
                  .fontSize(14)
                  .fontColor('#8888aa')
                  .margin({ left: 6 })
              }
            }
            .width('100%')
          }
          .backgroundColor('#16162a')
          .borderRadius(16)
          .padding(16)
          .width('100%')
          .margin({ top: 12 })

          // ---- 页面说明 ----
          Text('修改后将自动保存，返回主页面后自动刷新')
            .fontSize(12)
            .fontColor('#555577')
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 20 })
        }
        .width('100%')
        .padding(16)
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0d0d1a')
  }
}
