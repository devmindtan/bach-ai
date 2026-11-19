# Bảng lên cấp: xem nhân vật và ẩn thẻ

Người dùng 2026-11-18: khi đang chọn thẻ lên cấp, cho phép **ẩn bảng** hoặc **Tab xem thông tin nhân vật** để chọn
nâng cấp cho đúng.

## Tham khảo

| Nguồn | Điều lấy |
|---|---|
| Vampire Survivors ([thảo luận Steam về bảng chỉ số khi lên cấp](https://steamcommunity.com/app/1794680/discussions/0/4634862623030102973)) | Màn lên cấp cho thấy chỉ số và trang bị đang có cạnh các lựa chọn; người chơi so sánh trước khi chọn. Bài viết cũng chỉ ra lỗi chỉ số bị đẩy ra ngoài khung khi có nhiều món, nên bảng của mình dùng cột cuộn. |
| Brotato ([hướng dẫn: chỉ số bên trái, đồ bên phải](https://www.talkandroid.com/26166-brotato-ultimate-game-guide-tips-codes/), [Upgrades wiki](https://brotato.wiki.spellsandguns.com/Upgrades)) | Chỉ số nhân vật luôn xem được trong lúc chọn nâng cấp; quyết định dựa trên chỉ số hiện tại. |

**Học:** chỉ số và chiêu đang có phải xem được ngay trong lúc chọn. **Tránh:** nhồi thêm cột chỉ số vào bảng thẻ
(thẻ đã dày chữ). **Quyết định:** dùng lại trang Nhân vật đầy đủ (Tab, như khi tạm dừng) và thêm phím H ẩn bảng để
nhìn chiến trường; game vẫn dừng trong cả hai chế độ.

## Hành vi

- Dưới tiêu đề bảng thẻ: hai nút "Ẩn bảng (H)" và "Nhân vật (Tab)" (bấm chuột được, không nhận focus).
- **Tab / C** (tay cầm Back): mở trang Nhân vật; nút "Quay lại chọn thẻ (Tab)"; Tab lần nữa quay lại thẻ.
- **H** (tay cầm LB): ẩn bảng, chỉ còn một dải nhỏ ở trên "Đang xem chiến trường · H: hiện lại thẻ · Tab: nhân vật";
  H lần nữa hoặc nút "Hiện thẻ (H)" trên dải hiện lại thẻ.
- Phím 1/2/3 chỉ chọn thẻ khi bảng thẻ đang hiện (tránh chọn mù).
- Code: `run.toggle_level_view()`, `RunPanels.show_peek()` / `reshow()`. Test: `milestone_test.gd`.
- Phím Tab được bắt trong `run._input` (trước GUI): Godot dùng Tab để chuyển focus giữa các nút, nên ở `_unhandled_input` nó không bao giờ tới (lỗi 2026-11-18).

## Lật thẻ (6D.2, 2026-11-19)

Tham khảo: Vampire Survivors / Hades mở lựa chọn bằng hiệu ứng ngắn rồi mới cho chọn; quy tắc UI của dự án: mọi hiệu
ứng phải **bỏ qua được**. **Quyết định:** khi một bộ thẻ mới mở, từng thẻ lật từ mặt sau (nền tối, ngôi sao vàng ở giữa)
sang mặt trước, lệch nhau 0,08 s, mỗi nửa vòng 0,09 s (cả bộ ~0,45 s). Bấm chuột / phím / nút tay cầm trong lúc lật thì
lật xong ngay (lần bấm đó không chọn thẻ). Mở lại cùng bộ (Tab, Ẩn bảng) không lật lại. Bản xem trước cố định (ảnh
chụp giao diện) không lật; cờ chụp `--level-now --flip-shot` để chụp hiệu ứng.
