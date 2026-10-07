# Driver Automation

DevTools extension để inspect và verify Flutter Driver protocol qua VM Service
hiện tại của Flutter DevTools.

Extension cung cấp ba console độc lập:

- Finder JSON → Verify
- Command JSON → Execute
- RequestData JSON → Send

Ba console được hiển thị ở ba tab riêng biệt. Trong lúc gửi request, tab tương
ứng hiển thị progress indicator và khoá nút submit; sau khi thành công hoặc lỗi,
trạng thái được reset để có thể thao tác tiếp. Mỗi editor có `Format` và
`Reset`; RequestData bắt buộc là JSON object theo cấu trúc `E2eCommand`.
Mỗi lần mở hoặc reset template sẽ tạo một `requestId` UUID v4 mới.
Session history có thể xoá bằng nút `Clear` trong panel `HISTORY`.

Finder và Command editor có `Schemas` để xem built-in protocol schema,
property, kiểu dữ liệu, field bắt buộc, enum/constant và example JSON. Example
chỉ để tham khảo, không được chèn tự động vào editor. Khi Verify/Execute, JSON
được parse trước rồi mới validate theo `ProtocolSchemaRegistry`; JSON chưa hoàn
chỉnh chỉ báo lỗi parse. Schema chưa biết vẫn được gửi raw và hiển thị cảnh báo
để custom Finder/Command không bị chặn.

Request driver có timeout mặc định 30 giây; health-check kết nối có timeout 5
giây. Khi VM Service mất kết nối, không trả response hoặc request timeout,
extension ghi lỗi qua `dart:developer` và hiển thị trạng thái lỗi cùng nút
`Retry connection`. Nội dung response không được diễn giải ở tầng transport.

Extension gọi `ext.flutter.driver` trên main isolate, không tạo connection riêng
và không lưu test case, scenario hay automation workflow.

## Core

VM Service và lifecycle connection dùng `devtools_app_shared`:

- `ServiceManager` quản lý connection hiện tại của DevTools.
- `isolateManager` xác định main isolate sau hot restart.
- `DriverAutomationService` chỉ là adapter gọi
  `callServiceExtensionOnMainIsolate('ext.flutter.driver')`.
- UI dùng các shared component như `AreaPaneHeader`,
  `RoundedOutlinedBorder`, `DevToolsButton` và `AutoDisposeMixin`.
- `ProtocolSchemaRegistry` là source of truth duy nhất cho schema browser và
  schema validation. Schema runtime có thể thêm bằng `registerFinder`,
  `registerCommand` hoặc `merge`.

`devtools_extensions` chỉ cung cấp bootstrap `DevToolsExtension` để khởi tạo
các shared manager và kết nối với DevTools.

## Chạy local

Từ thư mục này:

```bash
flutter pub get
flutter run -d chrome
```

Để driver xuất hiện, Flutter application cần gọi
`enableFlutterDriverExtension()` trước `runApp()`.
