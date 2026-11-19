# Màn Cây thẻ

Luật: `design/skill-tree-v2.md` §3, §5. Mở từ màn Bộ thẻ. `src/front/card_tree.tscn` (`--card=<id>`).

## Tham khảo

| Nguồn | Điều lấy |
|---|---|
| Last Epoch, cây chuyên môn ([Maxroll](https://maxroll.gg/last-epoch/resources/passives-and-skills), [Ludo](https://www.ludo.guide/guide/last-epoch/characters-builds/skills-specializations/skill-trees-explained)) | Nút tròn trên lưới, nối cạnh; số điểm "x/y" dưới nút; thanh điểm đã dùng của chiêu; nút đặt lại. |
| Diablo IV ([tương phản đã học / chưa học](https://us.forums.blizzard.com/en/d4/t/ui-feedback-more-contrast-between-learned-and-unlearned-skills/9152)), Last Epoch ([icon consistency](https://forum.lastepoch.com/t/icon-consistency/72618)) | Nút đã học **sáng, viền vàng**; chưa học **tối, mờ**; icon có nghĩa (icon thẻ + ký hiệu thay đổi), không lặp vô nghĩa. |
| Hades Mirror of the Night (đã dùng ở cây nhân vật) | Khung chi tiết với giá và nút hành động chính; đặt lại hoàn đủ. |

## Bố cục

- Trên: "Cây thẻ · <tên thẻ>", ví Mảnh thẻ, thanh "Điểm đã dùng x / max", "Quay lại (Esc)" về màn Bộ thẻ.
- Giữa trái: lưới nút (cột × hàng theo `card_trees.json`), cạnh nối nút cha → con (sáng khi nút cha đã học).
  Nút: vòng tròn 64 px, icon thẻ ở giữa, ký hiệu thay đổi ở góc dưới phải; cấp "r/max" dưới nút. Then chốt: vòng to
  hơn, viền vàng dày. Trạng thái: đã tối đa (viền vàng, nền sáng), đã học một phần (viền bạc), học được (viền mờ
  nhấp nháy nhẹ), chưa học được (tối). Nút đang xem viền trắng.
- Phải: chi tiết nút (icon to, tên, "Cấp r/max", mô tả mỗi cấp, điều kiện / lý do chưa học, giá Mảnh thẻ, nút **Học**
  là nút chính). Dưới: **Đặt lại thẻ** (bấm hai lần), ghi số Mảnh thẻ sẽ hoàn.
