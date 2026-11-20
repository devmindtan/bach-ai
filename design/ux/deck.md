# Màn Bộ thẻ

Luật: `design/skill-tree-v2.md` §2. Mở từ sảnh (nút "Bộ thẻ"). `src/front/deck.tscn`.

## Tham khảo

| Nguồn | Điều lấy |
|---|---|
| Trình dựng bộ bài: [Archidekt grid view](https://archidekt.com/news/3108703), [Table Commander builder](https://beta.tablecommander.com/docs/decks/builder), [MythicHub](https://mythichub.com/blog/deckbuilder-evolved) | Bộ sưu tập dạng **lưới có ảnh thẻ**; thẻ đã chọn **viền vàng**, cùng một cách đánh dấu ở mọi chỗ; có dạng danh sách gọn cho bộ đang sửa. |
| Hearthstone ([deck layout](https://hearthstone.wiki.gg/wiki/Template:Deck_layout/row_layout)) | Bộ sưu tập một bên, **danh sách bộ đang dựng** bên kia, đếm số thẻ còn trống. |
| Hearthstone ([Hero Power](https://hearthstone.wiki.gg/wiki/Hero_Power)), Vampire Survivors ([nhân vật và vũ khí khởi đầu](https://vampire-survivors.fandom.com/wiki/Characters)) | Thứ luôn có (hero power / vũ khí khởi đầu) **đứng riêng, to hơn**, không lẫn trong bộ sưu tập và không có nút bỏ. (2026-11-20) |
| Last Epoch ([chuyên môn chiêu](https://maxroll.gg/last-epoch/resources/passives-and-skills)) | Từ thẻ chiêu mở thẳng **cây của chiêu đó**. |

## Bố cục

- Trên: "Bộ thẻ · <tên>", ví (Mảnh thẻ), "Quay lại (Esc)" bên phải. Dưới tiêu đề: 3 tab **Bộ 1 / Bộ 2 / Bộ 3** (tab
  đang dùng viền vàng; bấm là dùng bộ đó).
- Trái: bộ sưu tập, hai nhóm **Chiêu** rồi **Chỉ số**, mỗi thẻ một ô (icon 48, tên dưới). Thẻ trong bộ: viền vàng + dấu ✓;
  **chiêu khởi đầu** là một ô to 2×2 riêng đầu nhóm Chiêu (nền vàng, icon 96, nhãn "CHIÊU KHỞI ĐẦU",
  "Luôn trong bộ · 0 điểm"); các chiêu khác lưới 5 cột bên cạnh. Khung chi tiết của nó không có nút bỏ, chỉ
  một dòng vàng "★ Chiêu khởi đầu: luôn trong bộ" (người dùng 2026-11-20). Bấm ô: chọn để xem chi tiết; nút "Thêm vào bộ" / "Bỏ khỏi bộ" ở khung chi tiết.
- Phải: khung chi tiết thẻ (icon, tên, loại, mô tả, lý do không thêm/bỏ được) và, với thẻ chiêu có cây, dòng
  "Cây thẻ: x/y điểm" + nút **Cây thẻ**. Dưới: đếm "Chiêu a/8 · Chỉ số b/6" và nút **Bộ mặc định**.
- Mọi thay đổi lưu ngay.
