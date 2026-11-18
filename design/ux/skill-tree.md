# Màn cây kỹ năng

Luật: `design/skill-tree.md`. Mở từ sảnh (nút "Cây kỹ năng"). `src/front/skill_tree.tscn`.

## Tham khảo

| Nguồn | Điều lấy |
|---|---|
| Hades, [Mirror of the Night](https://hades.wiki.fextralife.com/Mirror+of+the+Night), [đặt lại](https://www.gameskinny.com/tips/how-to-reset-the-mirror-of-night-in-hades/) | Danh sách tài năng theo hàng, mỗi ô ghi giá bằng tiền tệ riêng; **nút đặt lại ở góc dưới phải, ghi rõ giá (1 Chthonic Key) và hoàn đủ** tiền đã tiêu. |
| Soulstone Survivors, [cây kỹ năng](https://www.gamepressure.com/newsroom/soulstone-survivors-unique-skills-skill-tree-and-prestige/zf4c7a) | Nhánh tách theo vai trò, mỗi nhánh một màu / icon riêng. |
| [Abratabia: inventory UI](https://www.abratabia.com/game-ui-design/inventory-ui.php) (bố cục chi tiết cố định, đã dùng ở màn trang bị) | Cột chi tiết bên phải: tên, mô tả, số trước → sau, nút hành động chính. |

## Bố cục

- Trên: "Cây kỹ năng · <tên>" bên trái; ví (Tinh hoa, Tẩy Tủy Đan, vàng) cạnh tiêu đề; "Quay lại (Esc)" bên phải.
- Giữa: 3 cột nhánh (icon + tên + vai trò ở đầu cột), mỗi cột 3 thẻ node từ tầng 1 xuống tầng 3, nối bằng vạch
  dọc (sáng khi tầng trên đã mở). Thẻ: icon, "Tên I/II/III", mô tả, giá (Tinh hoa) hoặc "Đã mở ✓".
  Trạng thái: đã mở (viền vàng, nền sáng), mua được (viền vàng mờ), chưa mở được (mờ, ghi điều kiện). Thẻ đang
  xem viền trắng.
- Phải: chi tiết node đang xem: tên, tầng, nhánh, mô tả, chỉ số trước → sau (▲ xanh), lý do chưa mua được, nút
  **Mở** (nút chính). Dưới cùng: khung **Đặt lại cây**: giá (1 Tẩy Tủy Đan + vàng), số Tinh hoa sẽ hoàn, nút đặt lại
  (bấm hai lần), tắt kèm lý do khi thiếu.
- Bàn phím / tay cầm: các thẻ là nút; Enter mở; Esc về sảnh.
