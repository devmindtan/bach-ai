# Điều khiển cảm ứng (J4)

## Tham khảo

- Vampire Survivors bản di động (PC Gamer, ra mắt 12/2022: https://www.pcgamer.com/vampire-survivors-gets-surprise-mobile-release-and-its-free):
  có tuỳ chọn hiện cần điều khiển trên màn hình. Bài TouchArcade
  (https://toucharcade.com/2022/12/09/vampire-survivors-mobile-review-controller-cloud-save-sync-dlc-unlock-iphone-ipad-pro/)
  khen chơi bằng một ngón. Lấy: cần nổi, đặt ngón ở đâu thì cần hiện ở đó; người chơi chỉ cần một ngón để đi.
- Các game survivors khác trên itch.io (ví dụ Ceaseless Castle, Simian Survivors: devlog "touch controls"): người chơi
  xin thêm kiểu cần **cố định**. Lấy: có thêm tuỳ chọn Cố định.
- Tránh: điều khiển chập chờn (người đánh giá phàn nàn "điều khiển thành kẻ thù chính") → có vùng chết 15%, cần
  nhả ra là dừng ngay, mở bảng (lên cấp, tạm dừng) là tự nhả.

## Quyết định

- Hiện khi máy có màn cảm ứng (`DisplayServer.is_touchscreen_available()`), hoặc khi chụp bằng cờ `--touch`.
- Cài đặt → "Cần điều khiển" (chỉ hiện trên máy cảm ứng): **Nổi** (mặc định: chạm vào 55% bên trái, dưới thanh HUD)
  / **Cố định** (góc dưới trái, tâm 150,560) / **Tắt**.
- Bán kính 70 px, núm 30 px; hướng và độ mạnh đổ vào các action `move_*` như tay cầm.
- Nút **Lướt** tròn 54 px ở góc dưới phải, chỉ hiện khi đã có thẻ Lướt; mờ khi đang hồi chiêu.
- Tạm dừng: dùng bánh răng sẵn có trên HUD (đã nhận chạm). Lưu ý: bánh răng nhỏ (~24 px), nếu thử trên máy thật
  thấy khó bấm thì phóng to.
- Màn ngang 1280×720 như bản máy tính; không làm bố cục dọc.

## Ảnh

`production/qa/evidence/touch-controls/01-fixed-stick-dash.png` (`--touch --touch-stick=1 --skills=dash:1`).
Chưa thử trên điện thoại thật.
