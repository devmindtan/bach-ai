# Kế hoạch: thiết kế lại Chém kiếm (`blade_arc`)

Trạng thái: **đang làm**: bước 1 xong (2026-11-21). Người dùng: "chiêu chém kiếm không đẹp và khá phế".
Thực hiện theo `.agents/skills/free-agent-workloop` (mỗi bước một commit có test + ảnh).

## 1. Hiện trạng (đã xem `sprite-lab/sprites/sword-slash/preview.png` và ảnh trong trận)

| Vấn đề | Chi tiết |
|---|---|
| Hình mảnh, nhạt | Một vệt trăng khuyết xám 2–4 px, không thân, không vệt kéo; trên nền cỏ gần như biến mất. |
| Không có "cú trúng" | Không tia lửa, không khựng, không rung: quái mất máu mà không thấy bị chém. |
| Vùng trúng nhỏ | Hitbox đo từ chính vệt mảnh (hitmask), nên hụt quái đứng sát hoặc lệch góc. |
| Một hướng | Chỉ chém về quái gần nhất; quái vây sau lưng phải chờ thẻ Chém ngược. |
| Lên cấp nhạt | Cấp 2–5 chỉ +20% sát thương; bậc hình chỉ đổi màu, không đổi cách đánh. |

## 2. Tham khảo

| Nguồn | Học | Tránh |
|---|---|---|
| Halls of Torment, Swordsman ([Prima Games](https://primagames.com/tips/best-swordsman-build-in-halls-of-torment-swordsman-build-guide), [Steam](https://steamcommunity.com/app/2218750/discussions/0/3803902828476540297), [commonsensegamer](https://commonsensegamer.com/halls-of-torment-best-swordsman-build/)) | Đòn chính là **hình nón** trước mặt, trúng mọi quái trong nón (xuyên ~100). **Range** tăng độ dài, **Area** tăng độ rộng nón: hai chỉ số khác nhau, dễ hiểu. | Không có |
| Vampire Survivors, Whip ([BlueStacks](https://www.bluestacks.com/blog/game-guides/vampire-survivors/vps-weapon-evolution-guide-en.html), [rogueranker](https://rogueranker.com/whip-evolution-vampire-survivors/)) | Nhát ngang rộng, chu kỳ đều 1,35 s. Lên cấp **thêm nhát luân phiên trái/phải**, nên lên cấp đổi cách đánh chứ không chỉ cộng số. | Bỏ ngỏ phía dưới (người chơi ghét) |
| GDQuest, "Juicing up your game attacks" ([link](https://www.gdquest.com/library/juicy_attack)); góp ý trên itch.io ([1](https://itch.io/post/10774394), [devlog sword 2.0](https://itch.io/devlog/854486/dev-log-sword-ability-20-from-frustration-to-satisfaction-.amp)) | Smear dày (vệt kéo) làm nhát chém nhanh và nặng; tia lửa + rung nhẹ khi trúng. Hitbox phải **đoán được** ("hụt 80% đòn" là lời chê hay gặp). Chỉ gây sát thương trong pha vung, không trong pha lấy đà. | Lấy đà dài làm điều khiển chậm |

**Quyết định:** chém hình **nón rộng có thân dày**, hitbox là hình học (nón), không đo từ nét vẽ. Lên cấp đổi cách
đánh. Cú trúng có cảm giác.

## 3. Thiết kế mới

**Hình.** Nhát smear dày hình quạt, góc khoảng 140°, bán kính khoảng 70 px ở cỡ 1.
- Ba dải màu: lõi trắng ở mép ngoài, thân xanh thép, đuôi mờ dần. Vẽ ở mật độ gấp đôi (`px_scale` 0,5), dùng chung
  `fxkit`.
- Có 5 pha: lấy đà 1 frame → vung (smear mở dần) → đỉnh → tan thành vệt → bụi sáng.
- Bậc II–V thêm vật liệu: bậc III ánh xanh lam, bậc V viền vàng và lưỡi gió.
- Theo quy tắc `pixel-sprite`: **không** lớp phủ vùng.

**Trúng.** Tại mỗi quái trúng đòn:
- tia lửa trắng 3–4 tia + chớp trắng 1 frame trên quái (đã có cơ chế `flash`);
- khựng 30 ms cho cả đòn (hit-stop, chỉ khi trúng ≥ 1 quái, tối đa một lần mỗi 0,3 s);
- rung màn nhẹ 1,5.
Số liệu nằm trong `upgrades_knight.json` `blade_arc.feel`.

**Hitbox.** Hình `cone` mới trong hitbox (tâm, hướng, bán kính, nửa góc, bán kính trong 0), đo hình học như
`circle`/`rect` hiện có:
- ghi trong json của sprite;
- `gameplay_rules` kiểm: nón phủ được ít nhất 80% nét vẽ của smear.

**Lên cấp** (đổi cách đánh, giống Whip):

| Cấp | Thay đổi |
|---|---|
| 1 | Nón 140°, 1 nhát về quái gần nhất |
| 2 | +20% sát thương, nón rộng 160° |
| 3 | **Nhát thứ hai** ngay sau, về hướng ngược lại (trái/phải luân phiên) |
| 4 | Chảy máu (như hiện tại) + mép nón bắn **lưỡi gió** ngắn 60 px xuyên 2 quái |
| 5 | Nhát cuối chuỗi xoay **360°** mỗi 3 lần vung |

Thẻ Chém ngược vẫn giữ, nhưng thành "nhát sau +25% mỗi cấp" chồng lên cấp 3.

**Số liệu.**
- Giữ `damage_mul` 1,3 và `offset` 30. Cooldown 0,9 → 1,0 s để bù vùng rộng hơn.
- Kiểm bằng test đường cong độ khó và bench 200 quái (vùng rộng có thể tăng số lần trúng mỗi nhát).

## 4. Các bước (mỗi bước một commit)

1. ✅ **Hitbox nón** (2026-11-21, `737f7ba`): addon đã có hình `arc` (vành tròn cắt theo góc); lỗi là `inner` đo từ nét
   mảnh (vành 10 px). Thêm `"swept": true` trong spec hitbox (gamekit 1.26.8) → `inner` 0 = nón đặc; test
   `blade_arc_reach_test`.
2. **Sprite mới trong Lab.**
   - Tạo `families/sword-slash.py` (5 bậc), xem preview, `art shot sheet/move`, `art test`.
   - Promote vào game.
3. **Cảm giác trúng.**
   - `feel` trong data; tia lửa, chớp trắng, hit-stop, rung trong `run.gd`.
   - Test hit-stop tối đa một lần mỗi 0,3 s.
   - Ảnh nhiều frame.
4. **Lên cấp mới.**
   - Nhát luân phiên, lưỡi gió, xoay 360° qua `blade_arc` trong `upgrades_knight.json`.
   - Test từng cấp.
   - Cập nhật mô tả thẻ và bảng Nhân vật.
5. **Cân bằng.**
   - Test đường cong độ khó, bench 200 quái (`sim_ms`).
   - Chạy `--god --demo` một trận và xem `damage_by` (tỉ trọng của Chém kiếm).
6. **Dashboard + web.**
   - Demo kỹ năng trên dashboard dùng hitbox nón.
   - Bump, export, smoke-web.

## 5. Câu hỏi cho người dùng (hỏi trước bước 4)

- Cấp 5 xoay 360° có hợp ý không, hay muốn nhát cuối là một nhát chém dài (lao về trước)?
- Màu: giữ thép trắng-xanh, hay mỗi bậc một màu nguyên tố?
