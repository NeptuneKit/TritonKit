import {
  tritonCapabilitySummary,
  tritonDebugSummary,
  tritonReleaseSummary,
  tritonSnapshotSummary,
} from '../triton/TritonCollectorContract';

@Entry
@Component
struct Index {
  @State message: string = 'Triton Collector Ready';
  @State taps: number = 0;

  build() {
    Row() {
      Column({ space: 12 }) {
        Text(this.message)
          .fontSize($r('app.float.page_title_font_size'))
          .fontWeight(FontWeight.Bold)
          .id('smoke-title')

        Text('tapCount=' + this.taps)
          .fontSize($r('app.float.page_body_font_size'))
          .id('smoke-counter')

        Text(tritonDebugSummary())
          .fontSize($r('app.float.page_body_font_size'))
          .id('collector-debug-manifest')

        Text(tritonCapabilitySummary())
          .fontSize($r('app.float.page_body_font_size'))
          .id('collector-capabilities')

        Text(tritonReleaseSummary())
          .fontSize($r('app.float.page_body_font_size'))
          .id('collector-release-noop')

        Text(tritonSnapshotSummary())
          .fontSize($r('app.float.page_body_font_size'))
          .id('collector-snapshot-metadata')

        Button('Validate Collector')
          .id('smoke-increment')
          .onClick(() => {
            this.taps += 1;
            this.message = 'Triton Collector Tapped';
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .height('100%')
    .padding(24)
    .backgroundColor($r('app.color.page_background'))
  }
}
