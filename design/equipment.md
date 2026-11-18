# Trang bị

Trạng thái: **bản đầu + tái thiết kế 2026-11-17 (legendary/epic tier)**. Dữ liệu `items.json` → `equipment`; hồ sơ người chơi
`src/meta/profile.gd` (`user://profile.json`); test `tests/unit/meta/profile_test.gd` và `tests/integration/data/data_consistency_test.gd`.

## Tham khảo trước khi thiết kế

- **Wikipedia — Vampire Survivors** (wiki CC-BY-SA): game dùng gold → mua relic lâu dài + golden eggs one-shot
  để tăng permanent attributes; chance per stage tăng; chest từ elite cho item. Với Bách Ải, trang bị là
  "relic" của slot (legacy/equip), đánh boss 10/20/30 để mở mốc rồi nhọn dần qua các slot.
- **Kenney (CC0)**: tham quan packs khi cần vẽ item mới; không lấy asset trực tiếp.
- **Lospec** (27 palettes): dùng cho tone rarity + region colours; chưa tạm dùng.
- **LPC** (trong repo): học layering, không copy sprite.

## Các thay đổi so với bản đầu

1. **Rarity thêm `legendary`** — `common < rare < epic < legendary`; màu `#f2b64a` (vàng rực) cho legendary.
   Dùng cho đồ có stat đáng kể / thay đổi build, dành cho boss ải 20/30 và cao cấp nhất.
2. **Thêm 16 món mới** (10 epic + 6 legendary theo class), dùng lại icon có sẵn — không vẽ thêm sprite:

   Kiếm sĩ (epic): Mũ rồng (iron_helm), Giáp rồng (steel_chest), Găng rồng (war_gloves), Ủng rồng (swift_boots), Kiếm rồng (steel_sword).
   Kiếm sĩ (legendary): Mũ Thần Hộ (iron_helm), Giáp Thần Hộ (steel_chest), Kiếm Thần Hộ (god_hammer).
   Pháp sư (epic): Mũ hư không (wizard_hat), Áo choàng hư không (mage_robe), Vòng tay hư không (arcane_bracer), Giày hư không (woven_shoes), Gậy hư không (crystal_staff).
   Pháp sư (legendary): Vương miện hư không (wizard_hat), Áo choàng trái tim (mage_robe), Gậy Vĩnh Cửu (crystal_staff).

   Mọi icon phải có trong `assets/sprites/custom/ui-icons/ui-icons.json` — kiểm bằng `tests/integration/data/data_consistency_test.gd`.
3. **RARITY bổ sung màu legendary (#f2b64a)** trong `src/lobby/lobby.gd` và `src/run/run_panels.gd` để hiển thị đúng legendary.

4. **Mỗi ô có class-specific common/rare/epic/legendary** cho Pháp sư và Kiếm sĩ, tránh tình trạng một class thiếu vũ khí phổ thông.
5. **Các file liên quan**: `design/equipment.md` (đây) và `design/progression.md` (gacha/mục 4 slot), `design/buffs.md`.

## Nguyên tắc cho lần thiết kế lớn (legendary)

1. **Golden weapons thay vì thả hàng**; visible epic làm cho người chơi chú ý nhưng không quá nhỏi lên.
2. **Legendary không phải "common mà số to hơn"** — mỗi legendary phải là "build-định-hướng": Mũ Thần Hộ giúp tank, Gậy Vĩnh Cửu tăng damage và tốc độ cast.
3. **Tất cả các thiết bị phân biệt theo class**: knight chỉ được loại tank/sword/armor; không mua Gậy hư không cho knight (checked in `data_consistency_test.gd`).

## Nhắc lại rule tính năng chính

- **Mặc**: sảnh Báo Trang bị: mỗi ô dòng, "Chọn (n)" mở modal picker; chọn món = mặc ngay, bỏ chọn = tháo.
- **Nhận**: thắng ải tặng 1 món ngẫu nhiên; 25% từ rương elite; boss ải 1/20/30 tặng mốc.
- **Lưu theo slot**: character slot thay cho `user://profile.json` kể từ phase 3.
- **Icons**: toàn bộ trong `ui-icons` (nếu cần thêm `gen.py` + promote).

## Tiếp theo

1. **Hình trên người**: vẽ lớp giáp theo ô (Sprite Lab, cùng tư thế minifig), `SpriteSheet.compose_layers` thay
   đúng ô khi mặc (nhân vật đã vẽ theo lớp cho việc này).
2. **Nâng cấp / phân rã** đồ bằng vàng (làm cùng đợt cây kỹ năng).
3. **Thêm đồ theo vùng ải** (vùng tối có tint tím, Đầm Lầy Độc: đất/độc) — sau khi có Sprite Lab hoàn chỉnh cho item.
4. **Slot-specific legendary mechanic**: ví dụ Mũ Thần Hộ cho slot chính, Gậy Vĩnh Cửu cho slot phụ — cần copeople phase 4.

## Cường hoá (2026-11-18)

- Mỗi món lên được +1 tới +5 bằng vàng; mọi bản trùng của món đó dùng chung bậc. Mỗi bậc thêm 20% hiệu ứng gốc
  (+5 = ×2,0). Giá bậc tiếp: `giá theo độ hiếm × (bậc hiện tại + 1)`; thường 30, hiếm 60, sử thi 120, huyền thoại 200.
- Màn trang bị: cột chi tiết ghi "Cường hoá +n/5" và nút "Cường hoá … vàng" (tắt khi thiếu vàng hoặc đã +5);
  tên món ghi "+n". Code: `Profile.enhance`, `enhance_cost`, `effects_of`; test `profile_test.gd`.
