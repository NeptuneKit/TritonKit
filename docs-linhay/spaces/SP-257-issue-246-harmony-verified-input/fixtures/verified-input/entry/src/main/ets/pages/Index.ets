@Entry
@Component
struct Index {
  @State mode: string = 'normal';
  @State value: string = '';
  @State changes: number = 0;
  @State observed: string = '';
  private timer: number = -1;

  private reset(mode: string): void {
    if (this.timer !== -1) clearTimeout(this.timer);
    this.mode = mode;
    this.value = '';
    this.observed = '';
    this.changes = 0;
  }

  private changed(value: string): void {
    this.changes++;
    this.observed = value;
    this.value = value;
    if (this.mode === 'reject') {
      this.value = 'REJECTED';
    } else if (this.mode === 'delayed') {
      this.timer = setTimeout(() => { this.value = value + '-settled'; }, 600);
    }
  }

  aboutToDisappear(): void {
    if (this.timer !== -1) clearTimeout(this.timer);
  }

  build() {
    Column({ space: 10 }) {
      Text('SP257 Verified Input Probe').fontSize(22).id('probe-title')
      Text(`mode=${this.mode} changes=${this.changes}`).id('probe-status')
      Row({ space: 6 }) {
        Button('Normal').id('mode-normal').onClick(() => this.reset('normal'))
        Button('Duplicate').id('mode-duplicate').onClick(() => this.reset('duplicate'))
        Button('Disabled').id('mode-disabled').onClick(() => this.reset('disabled'))
      }
      Row({ space: 6 }) {
        Button('Password').id('mode-password').onClick(() => this.reset('password'))
        Button('Delayed').id('mode-delayed').onClick(() => this.reset('delayed'))
        Button('Reject').id('mode-reject').onClick(() => this.reset('reject'))
      }
      if (this.mode === 'password') {
        TextInput({ text: this.value, placeholder: 'Secure unsupported' })
          .type(InputType.Password).id('editor').height(70)
          .onChange((value: string) => this.changed(value))
      } else {
        TextArea({ text: this.value, placeholder: 'Verified input target' })
          .id('editor').height(110).enabled(this.mode !== 'disabled')
          .enableKeyboardOnFocus(false)
          .onChange((value: string) => this.changed(value))
      }
      if (this.mode === 'duplicate') {
        TextArea({ text: '', placeholder: 'Duplicate id must reject' }).id('editor').height(80)
      }
      Text(this.mode === 'password' ? 'secure-value-redacted' : `observed=${this.observed}`)
        .id('probe-observed').fontSize(15)
      Text(this.mode === 'password' ? 'secure-value-redacted' : `value=${this.value}`)
        .id('probe-value').fontSize(15)
    }.width('100%').height('100%').padding(16)
  }
}
