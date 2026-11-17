# Tiến trình: ải 1–30, slot nhân vật, phần thưởng mốc cấp

Đợt 3 (`production/roadmap.md`). Dữ liệu: `assets/data/stages.json`, `assets/data/milestones.json`,
`assets/data/waves/*.json`. Code: `src/core/stages.gd`, `src/meta/slot.gd`, `src/meta/slot_store.gd`.

## Ải

- 30 ải, 3 vùng × 10 ải. Ải 10, 20, 30 là **ải boss**.
- Mỗi vùng có lịch quái mẫu (`waves`) cho ải thường và một cho ải boss (`boss_waves`); một ải có file riêng
  `waves/stage_NNN.json` thì dùng file đó. Mỗi vùng có màu nền riêng (`ground`).
- Độ khó tăng theo số ải `n` (mọi hệ số trong `stages.json` → `scale`):

| Đại lượng | Công thức | Ải 1 | Ải 10 | Ải 20 | Ải 30 |
|---|---|---|---|---|---|
| Máu quái × | `1 + hp_lin·(n−1) + hp_quad·(n−1)²` | 1,00 | 2,67 | 5,29 | 8,71 |
| Sát thương quái × | `1 + dmg_lin·(n−1)` | 1,00 | 1,54 | 2,14 | 2,74 |
| Mật độ quái × | `min(rate_max, 1 + rate_lin·(n−1))` | 1,00 | 1,27 | 1,57 | 1,87 |

  Hàm đơn điệu tăng, không nhảy vọt giữa hai ải liền nhau (test `stages_test.gd`). Đường cong vẽ ở dashboard (tab Ải).

| Vùng | Ải | Quái | Boss |
|---|---|---|---|
| Đồng cỏ | 1–10 | thạch nhầy, dơi, yêu tinh | Vua Thạch Nhầy (ải 10) |
| Rừng Âm U | 11–20 | dơi theo bầy, yêu tinh nhiều hơn, tinh anh dày hơn | Vua Thạch Nhầy (ải 20, máu × hệ số ải) |
| Đầm Lầy Độc | 21–30 | yêu tinh và tinh anh chiếm phần lớn | Vua Thạch Nhầy (ải 30) |

  Loài quái và boss riêng cho từng vùng sẽ vẽ ở đợt 6 (100 ải); đợt 3 chỉ đổi tỉ lệ quái và màu nền.

## Slot nhân vật

- Tối đa 4 slot. Mỗi slot: tên, class (chọn khi tạo, không đổi), ải cao nhất đã vượt, số lần vượt từng ải,
  vàng, đá, túi đồ và đồ đang mặc.
- Lưu `user://slots/<id>.json` có `version`. File hỏng hoặc phiên bản mới hơn: slot đó hiện "Không đọc được"
  (chỉ xoá được), các slot khác vẫn chơi bình thường.
- Lần đầu mở game bản này: `user://profile.json` cũ (túi đồ) chuyển vào slot đầu tiên.
- Chọn, tạo, đổi tên, xoá nhân vật ở màn **Chọn nhân vật** (`design/ux/front-end.md`).

## Chọn ải

- Mở được từ ải 1 tới ải *cao nhất đã vượt + 1* (tối đa 30).
- Màn chọn ải: lưới 3 hàng (vùng) × 10 ô. Ô khoá mờ có ổ khoá; ô đã vượt có dấu ✓; ô boss có viền vàng và
  đầu lâu.

## Kết quả và phần thưởng

- Thắng: vàng `gold_base + gold_per_stage·n`; đá `gems_first` (ải boss `gems_boss_first`) lần đầu, `gems_repeat` các lần
  sau; vàng nhặt trong trận cộng thêm. Thua: chỉ giữ vàng đã nhặt.
- Màn kết quả hiện vàng, đá nhận được; khi thắng có nút **Ải tiếp ▶**.
- Đá dùng cho gacha ở đợt 5; đợt 3 chỉ tích luỹ.

## Phần thưởng mốc cấp 10/20/30

Người dùng 2026-11-17: mốc là **cấp của nhân vật trong trận**, phần thưởng **chỉ có tác dụng trong trận đó**.
Lên cấp 10, 20, 30 → bảng "Mốc cấp N! Chọn một phần thưởng" mở trước thẻ lên cấp thường; chọn **1 trong 3**.
Hết trận thì mất; trận sau làm lại từ đầu. Không có gì lưu vào slot.

Tham khảo: Arcana của Vampire Survivors (nhận giữa trận từ rương boss phút 11 và 21, chọn trong vài lá, chỉ có
tác dụng trong trận đó; [Prima Games](https://primagames.com/tips/all-arcana-powerups-in-vampire-survivors-explained),
[BlueStacks](https://www.bluestacks.com/blog/game-guides/vampire-survivors/vps-arcana-card-guid-en.html)). Bách Ải
dùng mốc cấp thay cho rương boss vì mỗi ải là một trận 5 phút.

- **Chiêu độc nhất:** chiêu riêng của class, không có trong bộ thẻ thường; vào ngay ở cấp 1, sau đó lên cấp bằng
  thẻ như chiêu khác (bậc hình I–V).
- **Nội tại mới:** luôn bật tới hết trận, có điều kiện riêng.
- **Luật mới:** đổi luật trận từ lúc chọn.

| Mốc cấp | Chiêu độc nhất (Kiếm sĩ / Pháp sư) | Nội tại mới | Luật mới |
|---|---|---|---|
| 10 | **Địa chấn**: nứt đất dưới quái ngẫu nhiên, choáng / **Cầu hư không**: cầu tím bay xuyên quái, làm chậm | **Khát máu**: hạ tinh anh hoặc boss hồi 20% máu tối đa | **Song kích**: +1 số lượng mọi chiêu |
| 20 | **Thái dương xạ**: tia nắng xuyên 5 quái, gây bỏng / **Bão tuyết**: lốc băng quanh người, làm chậm rồi đóng băng | **Hộ thể**: mỗi 25 s có Khiên từ 4 s (miễn sát thương) | **Thêm lựa chọn**: lên cấp có 4 thẻ |
| 30 | **Búa thần**: búa giáng xuống quái gần nhất, choáng / **Bão sét**: sét đánh nhiều quái, giật lan | **Bất tử**: một lần, chết thì sống lại với 50% máu | **Bứt tốc**: được chọn ngay 2 thẻ lên cấp |

- Nhảy nhiều cấp một lúc (ví dụ 9 → 11) vẫn mở đúng một bảng cho mỗi mốc đã qua, mỗi mốc một lần mỗi trận.
- Hiển thị: bảng chọn giữa trận; bảng Nhân vật (mục "Phần thưởng mốc cấp (trận này)"); sảnh (hàng "Mốc cấp
  10 · 20 · 30" với 3 chiêu độc nhất của class); dashboard (tab Ải, mục phần thưởng mốc).

## Kiểm thử

- `tests/unit/core/stages_test.gd`: công thức đơn điệu tăng, không nhảy vọt; ải boss; chọn file lịch quái.
- `tests/unit/meta/slot_test.gd`: lưu/đọc, phiên bản, file hỏng không làm mất slot khác, phần thưởng lần đầu/lặp lại,
  slot không giữ phần thưởng mốc.
- `tests/unit/run/milestone_test.gd`: mỗi phần thưởng có tác dụng trong trận; cấp 10/20/30 mở bảng chọn mỗi mốc
  một lần. `tests/integration/meta/session_test.gd`: phần thưởng không ghi vào slot, trận sau bắt đầu không có.
- `tests/integration/data/data_consistency_test.gd`: chiêu độc nhất có trong `upgrades_<class>.json` với `unique`,
  không xuất hiện trong bộ thẻ khi chưa có.
