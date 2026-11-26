# Album (bách khoa)

Bản thử trên web: `design-web/games/bach-ai/screen-album.html` (người dùng duyệt bố cục 2026-11-23). Code: `src/front/album.gd`.

Màn mới ở sảnh (bach-ai `production/roadmap.md` mục 5): mọi quái, boss, kỹ năng, vật phẩm. Quái/boss **mở khoá sau
khi hạ lần đầu** (lưu trong slot), chưa mở thì hiện bóng đen "?".

## Tham khảo

| Nguồn | Lấy | Tránh |
|---|---|---|
| Vampire Survivors, Bestiary / Collection ([danh sách bestiary](https://primagames.com/tips/all-bestiary-members-in-vampire-survivors-listed), [wiki Enemies](https://vampire-survivors.fandom.com/wiki/Enemies)) | Hạ quái lần đầu thì mở mục; lưới ô vuông, ô chưa mở là bóng tối | Không có trang chi tiết đủ chỉ số |
| Brotato, Encyclopedia ([Switch 2 Edition](https://www.wikiwand.com/en/articles/Brotato_%E2%80%93_Nintendo_Switch_2_Edition)) | Bách khoa tách theo mục (vũ khí, vật phẩm, quái) | — |

**Quyết định:** 3 mục dạng thẻ (Quái, Boss, Kỹ năng; người dùng bỏ mục Vật phẩm 2026-11-23: trong trận không còn vật phẩm) đổi bằng Q/E (LB/RB); lưới 7 cột bên trái, khung chi
tiết bên phải; quái ghi loài, hệ yếu (đỏ), hệ kháng (xám), chỉ số ở ải 1, số lần hạ; kỹ năng có ô **mô phỏng** (`src/front/skill_sim.gd`, 2026-11-23): anh hùng tung chiêu vào slime hình nhân bằng
sprite thật của game, lặp lại, mỗi vòng sang bậc hình kế (Bậc I→V); slime chớp đỏ khi trúng như trong trận. Góc nhìn ×2,
hiệu ứng cao hơn khung (Cột thánh quang) thì cả cảnh thu về ×1 (giống rule `fitView` của sân demo Sprite Lab).

## Bố cục 1280×720

- Trái trên: tiêu đề "Album", dòng tiến độ "Đã mở 7 / 13 quái · 10 kỹ năng". Phải trên: Quay lại (Esc).
- Hàng thẻ mục (150×44) dưới tiêu đề, mục đang mở viền vàng.
- Lưới ô 88×88, cách 8, 7 cột; ô đang chọn viền trắng + vàng; ô chưa mở: bóng đen + "?".
- Khung chi tiết 508×570: ảnh lớn, tên, loài · vùng, yếu/kháng, bảng chỉ số, ghi chú, ô mô phỏng (kỹ năng).

## Ảnh

`production/ui/01n-album.png` (Quái), `01n2-album-skills.png` (Kỹ năng); bản web `design-web/games/bach-ai/shots/album-tab*.png`.

Lưu: `slot.bestiary` (id quái → số lần hạ), cộng ở cuối mỗi trận từ `Enemies.kills_kind`.

