# Kế hoạch: thiết kế lại Sóng kiếm (`cleave_wave`)

Trạng thái: **đã làm bước 1–4** (2026-11-22): người dùng bảo làm luôn; dùng mặc định xanh ngọc-trắng và cấp 4 vỡ 3 lưỡi. Người dùng: chiêu "không đẹp và khá phế". Lần đầu nhầm sang Chém kiếm;
phần đã sửa ở Chém kiếm (hitbox quạt đặc, xa hơn, hệ số 1,3) được giữ lại.
Thực hiện theo `.agents/skills/free-agent-workloop` (mỗi bước một commit có test + ảnh).

## 1. Hiện trạng (đã xem `sprite-lab/sprites/sword-wave/preview.png` và data)

| Vấn đề | Chi tiết |
|---|---|
| Hình vỡ | 16 hướng bay tạo bằng **xoay** một hình gốc (`sword-wave` cắt từ `cleave-wave`), nên hướng chéo răng cưa, thủng pixel (roadmap nợ kỹ thuật mục 4 đã ghi). |
| Không chuyển động | 6 frame `fly_*` gần như giống hệt nhau: sóng trượt đi như một tấm hình dán. |
| Trùng Chém kiếm | Cùng màu thép trắng-xanh, cùng hình trăng khuyết. Người chơi không phân biệt được sóng với nhát chém. |
| Nhỏ, ngắn | Frame 48 px, hitbox chữ nhật 18×40 **không xoay theo hướng bay**. Bay 300 px/s × 0,9 s ≈ 270 px rồi biến mất. |
| Yếu | `damage_mul` 0,9, hồi 2,75 s. Cấp 2–5 chủ yếu thêm số sóng (1/2/2/3/4) về các hướng cố định, sóng thêm thường bay vào chỗ trống. |

## 2. Tham khảo

| Nguồn | Học | Tránh |
|---|---|---|
| Halls of Torment, Swordsman ([Prima Games](https://primagames.com/tips/best-swordsman-build-in-halls-of-torment-swordsman-build-guide), [Steam](https://steamcommunity.com/app/2218750/discussions/0/3803902828476540297)) | Range = độ dài, Area = độ rộng: tách hai chỉ số cho dễ hiểu. | |
| ECS Survivors devlog: projectiles + modifiers ([itch.io](https://laurent-voisard.itch.io/ecs-survivors/devlog/953389/projectiles-a-lot-of-them-)); [RealmEye: weapon attributes](https://www.realmeye.com/wiki/weapon-attributes) | Xuyên thấu: một quái chỉ trúng **một lần** mỗi sóng. Tầm = tốc độ × thời gian sống. Độ rộng ngang tách khỏi tốc độ bay. | Sóng trúng một quái nhiều lần (khó cân) |
| GDQuest "Juicing up your game attacks" ([link](https://www.gdquest.com/library/juicy_attack)) | Smear và hạt bụi theo sau làm vật bay có tốc độ; tia lửa khi trúng. | |

**Quyết định:** sóng là **lưỡi khí lớn dần khi bay**, có vệt kéo, màu riêng, xuyên mỗi quái một lần, hitbox xoay theo
hướng bay.

## 3. Thiết kế mới

**Hình (Sprite Lab, family `sword-wave`).**
- Lưỡi khí cong **màu xanh ngọc-trắng** (khác thép của Chém kiếm). Lõi sáng, mép mờ, **vệt kéo** 3–4 dải phía sau, hạt
  gió bay ra hai mép.
- Vẽ **từng hướng bằng hình học** như `boltfx` / `dirs16`, không xoay ảnh. Mật độ gấp đôi (`px_scale` 0,5).
- 6 frame bay có chuyển động thật: vệt kéo dao động, hạt gió đổi chỗ, lõi nhấp nháy.
- Không lớp phủ vùng (quy tắc `pixel-sprite`).
- 5 bậc: bậc III thêm viền lam, bậc V thêm lõi vàng và hai lưỡi phụ nhỏ.

**Bay.**
- Tốc độ 300 → 340 px/s, thời gian sống 0,9 → 1,1 s (tầm ≈ 370 px).
- Sóng **nở rộng dần** khi bay: ×0,8 → ×1,3 độ rộng (smear dài ra). Sóng đi xa quét được nhiều quái hơn, thưởng cho
  việc nhắm hướng đông quái.

**Trúng.**
- Hitbox **xoay theo hướng bay**: dải cong theo lưỡi, hình `arc` đặc quanh tâm lưỡi, đo từ hướng gốc rồi xoay.
- Mỗi quái trúng **một lần** mỗi sóng (bỏ `rehit` 0,25 s).
- Tia lửa xanh nhỏ và đẩy lùi nhẹ ở mỗi quái trúng.

**Lên cấp** (đổi cách đánh):

| Cấp | Thay đổi |
|---|---|
| 1 | 1 sóng về hướng quái gần nhất, chảy máu |
| 2 | +25% sát thương, sóng nở to hơn (×1,5 ở cuối đường) |
| 3 | **Sóng đôi**: 2 sóng xoè ±15° về cùng hướng (thay cho "thêm sóng phía sau" hay bay vào chỗ trống) |
| 4 | Cuối đường bay sóng **vỡ thành 3 lưỡi nhỏ** toả 60° (sát thương 40%) |
| 5 | **3 sóng xoè** ±25°, xuyên cả boss không bị chặn, chảy máu mạnh hơn |

**Số liệu khởi đầu.**
- `damage_mul` 0,9 → 1,1. Hồi chiêu giữ 2,75 s (sau giới hạn −40% còn 1,65 s).
- Scale theo: sát thương ×1,1 + tốc độ chạy ×0,02 (lưỡi khí của người chạy nhanh). Theo hệ thống `scale`, chỉ là gợi
  ý, chốt ở bước 5.
- Mọi số nằm trong `upgrades_knight.json` `cleave_wave` (`grow`, `split`, `spread_deg`…).

## 4. Các bước (mỗi bước một commit)

1. ✅ **Đã kiểm (2026-11-21), không cần sửa riêng:** mỗi anim `fly_<góc>` đã có hitbox chữ nhật đo từ chính hình vẽ của
   hướng đó (`SpriteHitbox.of(sheet, anim)` trong `_step_fx`). Hướng chéo dùng hộp bao lớn hơn một chút, không lệch.
   Sprite mới (bước 2) vẽ từng hướng nên hitbox đo lại tự khớp. "Mỗi quái trúng một lần mỗi sóng" (bỏ `rehit` 0,25 s)
   làm sóng yếu đi, nên **chuyển sang bước 5**, đi cùng việc tăng `damage_mul`.
2. **Sprite mới** trong Lab (`families/sword-wave.py`):
   - vẽ hình học cho 16 hướng, 5 bậc, vệt kéo, frame động, màu xanh ngọc;
   - `art run` → xem preview → `art shot sheet` + `move` → `art test`;
   - promote.
3. **Bay + nở rộng** (`grow`): scale sprite và hitbox theo tiến độ bay. Test hitbox ở cuối đường lớn hơn đầu đường.
4. **Lên cấp mới:** sóng xoè (`spread_deg`), vỡ lưỡi (`split`), mô tả thẻ, bảng Nhân vật. Test từng cấp.
5. **Cân bằng:**
   - test đường cong độ khó;
   - một trận `--god --demo` xem tỉ trọng `damage_by` của Sóng kiếm (mục tiêu: ngang Lốc xoáy / Đất nứt cùng cấp);
   - bench 200 quái (`sim_ms`).
6. **Dashboard + web:** demo kỹ năng, bump, export, smoke-web.

## 5. Câu hỏi cho người dùng (hỏi trước bước 4)

- Màu xanh ngọc-trắng có hợp không (để khác Chém kiếm), hay muốn màu khác?
- Cấp 4 "vỡ thành 3 lưỡi" hay "dội ngược lại một lần" (boomerang)?

## Số đo cân bằng (bước 5, 2026-11-22)

`gamekit shot … -- --demo --god --sim-steps=8 --skills=blade_arc:3,cleave_wave:3,whirlwind:3,earth_strike:3`, dòng
`GK: damage` (tỉ trọng sát thương cả trận, demo tự chọn thẻ):

| damage_mul, tầm, nở | Sóng kiếm | Chém kiếm | Đất nứt | Lốc xoáy |
|---|---|---|---|---|
| 1,1 · 340 px/s × 1,1 s · ×1,3–1,6 | 58–66% | 14–15% | 12–23% | 4–5% |
| 0,6 · 320 × 1,0 · ×1,2–1,4 | 46–54% | 21–22% | 17–22% | 7–10% |
| 0,45 · như trên | 43–54% | 21–22% | 16–22% | 6–11% |

Hệ số sát thương ít tác dụng: tỉ trọng đến từ việc sóng với tới quái ở xa mà chiêu cận chiến không chạm. **Chốt 0,6**
(mỗi nhát vẫn có lực; người dùng chê chiêu cũ yếu), tầm 320 × 1,0, nở ×1,2–1,4. **Lốc xoáy chỉ 4–11%**: chiêu yếu
nhất, cần xem lại (ghi vào roadmap).
