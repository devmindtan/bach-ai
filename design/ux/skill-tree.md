# Màn cây kỹ năng

Luật: `design/skill-tree-v2.md` §1 (cây v2; bản cũ `design/skill-tree.md`). Mở từ sảnh (nút "Cây kỹ năng"). `src/front/skill_tree.tscn`.

## Tham khảo

| Nguồn | Điều lấy |
|---|---|
| Hades, [Mirror of the Night](https://hades.wiki.fextralife.com/Mirror+of+the+Night), [đặt lại](https://www.gameskinny.com/tips/how-to-reset-the-mirror-of-night-in-hades/) | Danh sách tài năng theo hàng, mỗi ô ghi giá bằng tiền tệ riêng; **nút đặt lại ở góc dưới phải, ghi rõ giá (1 Chthonic Key) và hoàn đủ** tiền đã tiêu. |
| Soulstone Survivors, [cây kỹ năng](https://www.gamepressure.com/newsroom/soulstone-survivors-unique-skills-skill-tree-and-prestige/zf4c7a) | Nhánh tách theo vai trò, mỗi nhánh một màu / icon riêng. |
| Last Epoch / Path of Exile, cây bị động ([Maxroll](https://maxroll.gg/last-epoch/resources/passives-and-skills), [PoE2 wiki: Keystone](https://www.poe2wiki.net/wiki/Keystone_passive_skill)) | Nút tròn trên lưới nối cạnh, nút nhiều cấp, then chốt to hơn ở cuối; cùng kiểu với màn Cây thẻ. |
| [Abratabia: inventory UI](https://www.abratabia.com/game-ui-design/inventory-ui.php) (bố cục chi tiết cố định, đã dùng ở màn trang bị) | Cột chi tiết bên phải: tên, mô tả, số trước → sau, nút hành động chính. |

## Bố cục

- Trên: "Cây kỹ năng · <tên>" bên trái; ví (Tinh hoa, Tẩy Tủy Đan, vàng) và "Điểm đã dùng n" cạnh tiêu đề;
  "Quay lại (Esc)" bên phải.
- Trái: cây trên lưới 5 cột × 5 hàng: gốc ở trên, 3 nhánh (sát thương / nhịp đánh / sống sót) xuống dưới, 3 nút
  then chốt to hơn ở hàng cuối. Mỗi nút tròn một icon riêng, dưới nút là "cấp/tối đa" trên nền tối (cạnh nối
  chạy dưới chữ). Đã tối đa: viền vàng, nền nâu; đã học một phần: viền bạc; học được: viền vàng mờ; chưa: tối.
  Nút đang xem viền trắng. Cạnh sáng vàng khi nút cha đã học.
- Phải trên: chi tiết nút: icon 48, tên, "Then chốt · Cấp r/max", mô tả, dòng "Cần: …", chỉ số trước → sau của
  cấp kế (xanh khi tốt hơn, đỏ khi kém đi), lý do chưa học được, nút **Học (giá Tinh hoa)**.
- Phải dưới: khung **Đặt lại cây** (1 Tẩy Tủy Đan + vàng, số Tinh hoa hoàn, bấm hai lần).
- Bàn phím / tay cầm: các nút là Button; Enter chọn; Esc về sảnh.
