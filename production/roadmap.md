# Bách Ải: kế hoạch theo đợt

Thiết kế: [`design/game-brief.md`](../design/game-brief.md) · Quái vật: [`design/monsters.md`](../design/monsters.md)
Nguyên tắc: **làm cho vòng lặp cốt lõi vui trước**, rồi mới tới hệ thống lâu dài. Mỗi đợt kết thúc bằng một bản chạy
được, có test và ảnh chụp, và một câu hỏi được trả lời bằng chơi thử. Đợt sau chỉ bắt đầu khi đợt trước đạt.

## Đã quyết (2026-11-16)

| Chủ đề | Quyết định |
|---|---|
| Thể loại | survivors-like + RPG theo class |
| Lượt chơi | **Mỗi ải là một lượt mới**: vào ải bắt đầu cấp 1, lên cấp chọn 1/3 nâng cấp theo class, hết lượt thì cấp mất |
| Sức mạnh lâu dài | Cây kỹ năng theo class, trang bị (vũ khí, giáp), gacha, tất cả gắn với **slot nhân vật** |
| Mốc cấp 10/20/30 | Lên cấp 10, 20, 30 trong một trận → chọn 1/3 phần thưởng: **chiêu độc nhất**, **nội tại mới** hoặc **luật mới**, chỉ có tác dụng trong trận đó (2026-11-17, you said: mốc là cấp trong trận, không phải ải; không nâng nội tại cũ). Chi tiết: `design/progression.md` |
| Quái vật | Vẽ mới trong Sprite Lab, cùng phong cách tối giản 48 px với nhân vật |
| Nền tảng | **PC trước** (Steam: Windows/Linux, bàn phím + tay cầm); mobile sau (đợt 8) |
| Engine | Godot 4.7.2, GDScript, gamekit (test, shot, export) |
| Gacha | Quay bằng **đá gacha trong game**, cày được bằng cách chơi (vượt ải, boss, nhiệm vụ). **Nạp tiền tính sau** (2026-11-16, you said) |
| Nhân vật & đòn đánh | Nhân vật **chỉ có góc ngang trái/phải** (trái = lật): `idle`, `run`, `hurt`, `death`. Đòn đánh là **sprite hiệu ứng riêng** (có hitbox), không vẽ vào thân (2026-11-16, you said) |
| Mặc giáp | Nhân vật vẽ **theo ô trang bị**: giáp đầu, giáp ngực, giáp tay, giáp chân, vũ khí, trên một lớp nền là mặt (2026-11-17, you said: không cắt sâu hơn); đồ mặc thay đúng ô đó, game ghép lớp rồi viền (`SpriteSheet.compose_layers`) (2026-11-16, you said) |
| Phản hồi đòn đánh | Hiện **số sát thương** bay lên khi đánh trúng; **thanh máu quái chỉ hiện khi bị đánh** (2 s sau mỗi đòn) (2026-11-16, you said) |
| Luật gameplay | Game 2D sinh tồn kiểu Vampire Survivors; mọi kỹ năng/hiệu ứng phải qua luật ở `design/gameplay-rules.md` (`assets/data/gameplay_rules.json`), test chặn luật bắt buộc, dashboard chấm các kỹ năng của game (2026-11-16, you said) |

## Quyết định còn mở (cần trước đợt ghi trong ngoặc)

| Câu hỏi | Đề xuất mặc định | Trước đợt |
|---|---|---|
| Tên chính thức | "Bách Ải" là tên tạm | 7 |
| Cơ chế nạp (mua đá bằng tiền thật) | Hoãn: đá chỉ cày trong game. Thiết kế ví đá và giao dịch sao cho sau này thêm nguồn "nạp" mà không sửa gacha. Khi quyết định cần xét luật hộp quà ngẫu nhiên (công bố tỉ lệ; một số nước cấm), đánh giá trên Steam, cân bằng "trả tiền để thắng" | 7 |
| Bán game kiểu nào trên Steam | Trả tiền một lần (premium), không quảng cáo | 7 |
| Thời lượng một lượt | 5 phút (ải 1–20), 6–8 phút về sau, boss ải 10/20/… | 1 (thử) |
| Có 4 class không | Bắt đầu 2 (Kiếm sĩ, Pháp sư); Cung thủ, Sát thủ ở đợt 6 (giáp và chiêu đã có trong Sprite Lab) | 6 |

## Tài nguyên đã có (tận dụng)

Trong `../../sprite-lab/sprites/`:
- **Nhân vật:** `swordsman`, `mage` (idle, run, jump, attack, spell, hurt, death).
- **Chiêu / đạn:** fireball, frost-shard, frost-nova, ice-pillar, lightning-strike, thunder-javelin, meteor-fall, meteor-burst, arcane-bolt, arcane-circle, void-orb (pháp sư); cleave-wave, whirlwind, ground-slam, earth-spikes, holy-column (kiếm sĩ); arrow, piercing-arrow, poison-arrow, arrow-rain, scatter-volley, hunter-snare (cung); shuriken, throwing-knife, poison-dart, shadow-slash, shadow-dash, smoke-bomb (sát thủ).
- **Buff:** arcane-empower, haste-rune, heal-bloom, magnetic-shield.
- **Trang bị:** iron-sword, greatsword, battle-axe, war-hammer, oak-bow, magic-staff, round-shield, tower-shield; bộ giáp knight / mage / ranger / assassin; steel-chestplate.

Cần vẽ mới: **quái vật** (xem `design/monsters.md`), viên kinh nghiệm, vàng, rương, tile nền theo vùng, icon nâng cấp.

## Kiến trúc kỹ thuật (áp dụng từ đợt 1)

- **Hiệu năng:** survivors cần vài trăm quái cùng lúc. Không dùng một node vật lý cho mỗi quái: `EnemyManager` giữ quái trong mảng (pool), va chạm bằng lưới không gian (spatial hash), vẽ hàng loạt (`SpriteSheet` trong `_draw` hoặc `MultiMeshInstance2D`). Mục tiêu: **500 quái ở 60 fps** trên PC tầm trung; đo ở đợt 1 trước khi làm nội dung.
- **Dữ liệu, không hardcode:** `assets/data/classes.json`, `upgrades_<class>.json`, `monsters.json`, `stages.json`, `waves/*.json`, và sau này `skill_tree_<class>.json`, `items.json`, `perks.json`, `gacha_banners.json`.
- **Logic thuần trong `src/core/` có unit test:** công thức sát thương, đường kinh nghiệm, rút 3 nâng cấp (RNG có seed, có trọng số), lịch đợt quái, scale độ khó theo ải, roll gacha + bảo hiểm (pity), kiểm tra cây kỹ năng.
- **Input qua InputMap** (`move_*`, `pause`, `choose_1..3`, `confirm`): thêm tay cầm, sau này joystick cảm ứng, mà không sửa gameplay.
- **Lưu:** `user://slots/<id>.json` có số phiên bản schema; mỗi slot = class + cây kỹ năng + túi đồ + ải đã vượt.
- **Sprite:** làm trong Sprite Lab, đưa vào game bằng `gamekit art promote <tên> bach-ai`, vẽ bằng `SpriteSheet`.

---

## Đợt 0: Nền móng · cỡ S
**Mục tiêu:** dự án sẵn sàng để làm đợt 1.
- `gamekit new bach-ai` (xong), brief, roadmap, danh sách quái (tài liệu này).
- `project.yaml`: rigor (đề xuất `standard` từ đợt 3 vì có nhiều hệ thống liên quan nhau; đợt 1–2 dùng `minimal`).
- InputMap, cấu trúc thư mục `src/core`, `src/run`, `src/ui`, `src/meta`; schema dữ liệu ghi trong `design/data-schemas.md`.
**Xong khi:** `gamekit test bach-ai` chạy (0 test), `gamekit run` mở cảnh trống, mọi file đã commit.

## Đợt 1: Lượt chơi cốt lõi (vertical slice) · cỡ L
**Trạng thái (2026-11-17):** xong phần làm; còn chờ người chơi thử trả lời câu hỏi của đợt. 500 quái
141 fps (`production/qa/bench-2026-11-17.md`). Có thêm ngoài kế hoạch: bảng Nhân vật, ô hồi chiêu, bảng
sát thương cuối trận, cài đặt, 4 buff ngẫu nhiên (`design/buffs.md`). Cân bằng độ khó để sau (người dùng).
**Câu hỏi:** một lượt 5 phút với Kiếm sĩ có vui không, có muốn chơi lượt 2 không?
- Di chuyển 8 hướng, camera bám, sân giới hạn mềm; hitbox nhỏ hơn sprite.
- Chiêu tự đánh: `kiếm chém vòng cung` (theo hướng đi) + 1 chiêu mở qua nâng cấp (`cleave-wave`).
- `EnemyManager` + spatial hash + **thử tải 500 quái** (kịch bản headless đo fps, ghi số liệu).
- 3 quái: slime (bò), dơi (bay nhanh, theo bầy), goblin (lao tới). Lịch đợt theo thời gian từ `waves/stage_001.json`.
- Kinh nghiệm: quái rơi viên exp, hút khi lại gần, đường exp từ công thức; lên cấp → dừng game → 3 thẻ (6–8 nâng cấp đầu: chiêu mới, +sát thương, +tốc độ đánh, +máu, +tốc chạy, +tầm hút).
- Máu, bất tử ngắn khi trúng đòn, chết → màn thua; sống 5:00 → màn thắng.
- HUD: máu, thanh exp + cấp, đồng hồ, số quái hạ; tạm dừng.
**Test:** công thức exp và sát thương, rút 3 nâng cấp (không trùng, đúng trọng số với seed cố định), lịch đợt.
**Xong khi:** chơi trọn 5 phút không lỗi; 500 quái ≥ 60 fps (có số đo); ảnh chụp đầu lượt, giữa lượt, màn lên cấp, thắng, thua; ít nhất một người chơi thử trả lời câu hỏi của đợt.

## Đợt 2: Độ sâu build · cỡ L
**Trạng thái (2026-11-17):** xong phần làm. Kiếm sĩ 7 chiêu + 9 thẻ, Pháp sư 7 chiêu + 8 thẻ, nội tại mỗi class
(`design/classes.md`), debuff lên quái (`design/statuses.md`), quái tinh anh + rương, boss Vua Thạch Nhầy ở ải 10
(`--stage=10` tới khi có chọn ải ở đợt 3), bậc hình I–V cho mọi chiêu có hình, đạn bay 16 hướng, quái yếu thưa dần
theo thời gian. Còn: rung màn/khựng khi chí mạng (chưa có chí mạng), ghi 3 build mẫu mỗi class khi chơi thử.
**Câu hỏi:** hai lượt cùng class có ra hai build khác nhau thật không?
- Class **Pháp sư** (tầm xa: fireball, frost-shard…).
- Mỗi class: ~8 chiêu chủ động + ~8 nội tại, mỗi cái tối đa cấp 5; thẻ hiển thị cấp hiện tại → kế tiếp; (tiến hoá chiêu: để đợt 6).
- Quái tinh anh (to hơn, hào quang, nhiều máu, rơi rương); rương = chọn thêm 1 nâng cấp.
- **Boss ải 10:** Vua Slime (tách nhỏ khi bị đánh).
- Cảm giác đánh: số sát thương, nháy trắng, rung nhẹ, khựng khung hình khi chí mạng; vật phẩm rơi: vàng, nam châm, bình máu.
**Xong khi:** mỗi class có thể chơi trọn một lượt với ít nhất 3 hướng build khác nhau (ghi lại 3 build mẫu); boss có 2 đòn.

## Đợt 3: Tiến trình ải 1–30 + slot nhân vật · cỡ M
**Trạng thái (2026-11-17):** xong phần làm (`design/progression.md`). 30 ải / 3 vùng có màu nền riêng, công thức
tăng độ khó (đường cong ở dashboard, tab Ải), slot nhân vật (tối đa 4, file hỏng không làm mất slot khác), màn
chọn ải, phần thưởng thắng (vàng, đá), phần thưởng mốc cấp 10/20/30 trong trận (6 chiêu độc nhất có bậc I–V, 3 nội tại mới,
3 luật mới). Còn: chơi thử ải 1–30 với 2 class để chỉnh hệ số (`stages.json` → `scale`); loài quái và boss riêng
từng vùng (đợt 6, hiện các vùng dùng chung thạch nhầy / dơi / yêu tinh / Vua Thạch Nhầy).
**Câu hỏi:** độ khó tăng có đều không, người chơi có muốn "thêm một ải nữa" không?
- `stages.json` + công thức scale (máu/sát thương/mật độ quái theo ải, loài quái theo vùng, boss mỗi 10 ải); ghi đè tay khi cần.
- Màn chọn ải (1 → ải cao nhất đã mở), màn kết quả (vàng, đá gacha, điểm kỹ năng nhận được).
- **Slot nhân vật:** tạo (chọn class, đặt tên), chơi, xoá; lưu `user://slots`.
- **Phần thưởng mốc cấp 10/20/30:** lên cấp trong trận → chọn 1/3 phần thưởng cho trận đó: chiêu độc nhất của class, nội tại mới, hoặc luật mới (`design/progression.md`).
**Test:** công thức scale (đơn điệu tăng, không nhảy vọt), lưu/đọc slot (phiên bản schema, file hỏng → báo lỗi, không mất slot khác).
**Xong khi:** vượt được ải 1–30 với 2 class trong thời gian hợp lý; đường cong độ khó vẽ thành biểu đồ để xem.

## Đợt 4: Cây kỹ năng + trang bị · cỡ L
**Trạng thái (2026-11-18):** cây kỹ năng xong (`design/skill-tree.md`): 3 nhánh × 3 tầng mỗi class, mua bằng
Tinh hoa (tinh anh rơi 1, boss rơi 10), đặt lại bằng Tẩy Tủy Đan + vàng; chế độ Thử thách (`design/challenge.md`)
rơi Tẩy Tủy Đan; màn trang bị (búp bê giấy, túi đồ lọc/sắp xếp, so sánh); cường hoá đồ +1..+5 bằng vàng; dòng phụ
(sử thi, huyền thoại, mở ở +2) và hiệu ứng đặc biệt (6 món huyền thoại, mở ở +3). Còn: đồ vẽ lên người nhân vật;
chơi thử để chỉnh giá node, lượng Tinh hoa rơi, số liệu dòng phụ / hiệu ứng đặc biệt.
**Câu hỏi:** đầu tư lâu dài có làm người chơi thấy rõ nhân vật mạnh lên giữa các lượt không?
- **Cây kỹ năng theo class**: điểm từ vượt ải / lên cấp tài khoản; nhánh (ví dụ Kiếm sĩ: Phòng thủ / Cuồng nộ / Kiếm khí); có nút đặt lại (mất ít vàng).
- **Trang bị:** ô vũ khí, mũ, áo, găng, giày; độ hiếm (thường → huyền thoại); chỉ số chính + dòng phụ + **hiệu ứng đặc biệt** ở hiếm cao; rơi từ boss/rương.
- Túi đồ, so sánh chỉ số, cường hoá bằng vàng.
**Xong khi:** một slot có cây kỹ năng 20 điểm và bộ trang bị mạnh vượt ải 30 nhanh hơn rõ rệt (số đo thời gian/máu còn lại).

## Đợt 5: Gacha · cỡ M
**Trạng thái (2026-11-18):** lõi xong (`design/gacha.md`, `assets/data/gacha.json`): 2 banner, 10 đá/lượt, tỉ lệ
công khai trên màn, pity huyền thoại ở lượt 50 mỗi banner, món trùng đổi vàng; test tỉ lệ 200k lượt. Còn: chốt số
(tỉ lệ, pity, giá) khi chơi thử; nhiệm vụ ngày / thành tựu cho thêm đá; hiệu ứng quay. Lịch sử quay: xong
(tab Lịch sử, 100 lượt mỗi banner).
**Câu hỏi:** quay gacha có hồi hộp mà không làm hỏng cân bằng không?
- Banner vũ khí và banner giáp; tỉ lệ công khai trong game; **bảo hiểm (pity)** sau N lần; trùng → nguyên liệu cường hoá.
- Đá gacha kiếm trong game: vượt ải (lần đầu nhiều hơn, cày lại ít hơn), boss, nhiệm vụ ngày, thành tựu; lịch sử quay.
- **Ví đá tách riêng** (`Wallet`: số dư + nhật ký giao dịch có nguồn: `stage_clear`, `boss`, `daily`, …) để sau này thêm
  nguồn `purchase` mà không đụng logic gacha.
- Cân nhịp cày: ước lượng số lần quay/giờ chơi ở từng chặng ải, ghi vào `design/` khi làm đợt 5.
- Màn quay có hiệu ứng theo độ hiếm.
**Test:** mô phỏng 1.000.000 lượt quay khớp tỉ lệ khai báo (sai số nhỏ), pity luôn kích hoạt đúng lần N.
**Xong khi:** tỉ lệ thực đo khớp tỉ lệ công bố; người chơi cày đủ đá cho vài lượt quay mỗi buổi chơi (số đo).

## Đợt 6: Nội dung đủ 100 ải · cỡ XL
**Kế hoạch nâng cấp (2026-11-18):** `production/upgrade-plan.md` (quái vật, bản đồ, gameplay, giao diện, class mới).
- 5 vùng × 20 ải (đồng cỏ, nghĩa địa, hang băng, núi lửa, hư không); mỗi vùng 3–4 loài quái mới + 2 boss.
- Class **Cung thủ** và **Sát thủ** (chiêu và giáp đã có trong Sprite Lab; cần vẽ nhân vật).
  Ghi chú 2026-11-21 (đánh giá ngoài, người dùng đưa vào kế hoạch): dựng nhân vật trên `sprite-lab/lib/minifig.py`
  (6 lớp giấy: head, chest, arms, legs, feet, weapon) như kiếm sĩ / pháp sư; dùng lại `ranger-*`, `bow-*`, `arrow-rain`,
  `assassin-*`, `dagger-*`, `shadow-dash` có sẵn; cần thêm bộ chiêu 5 bậc, cây kỹ năng, cây thẻ, cân bằng bằng mô phỏng.
- Tiến hoá chiêu (chiêu cấp 5 + nội tại phù hợp → bản tiến hoá).
- **Mô phỏng cân bằng:** bot chạy headless từng ải với build mẫu, ghi thời gian sống/DPS → điều chỉnh công thức.
**Xong khi:** ải 100 vượt được với build đầu tư hợp lý, không vượt được với build trống (số đo từ mô phỏng).

## Đợt 7: Hoàn thiện + Steam · cỡ L
**🔒 KHOÁ (người dùng 2026-11-18):** không làm, kể cả khi đợt 6 xong, cho tới khi người dùng ưng ý và tự mở.
**Trạng thái (2026-11-18):** âm thanh xong phần lõi (`design/audio.md`: 31 hiệu ứng + 3 nhạc nền tạo bằng
`gamekit audio`, âm lượng Nhạc / Hiệu ứng trong Cài đặt); bản 0.2.0 xuất được Linux + Web (font dự phòng cho ký hiệu
trên Web). Còn: nhạc theo vùng, đổi phím, tay cầm, tiếng Anh, Steam.
- Âm thanh, nhạc theo vùng; cài đặt (âm lượng, phím, độ phân giải); tay cầm đầy đủ; tiếng Việt + tiếng Anh.
- Steam qua GodotSteam: thành tựu, lưu đám mây; trang cửa hàng (ảnh, trailer); bản demo (ải 1–10).
- `gamekit export`, kiểm tra trên Windows thật.

## Đợt 8: Mobile (sau khi có bản PC)
**🔒 KHOÁ (người dùng 2026-11-18):** không làm, kể cả khi đợt 6 xong, cho tới khi người dùng ưng ý và tự mở.
- Joystick ảo, UI theo ngón tay, tỉ lệ màn hình; export Android, rồi iOS.
- Ghi chú 2026-11-21 (đánh giá ngoài): khi mở đợt này, `gamekit ui-shots` chụp mỗi màn ở 1280×720 và một độ phân giải
  dọc của điện thoại; mở rộng `ui_layout_rules_test.gd` kiểm khung chữ / nút không tràn ở cả hai.

## Nợ kỹ thuật & chất lượng (làm dần, người dùng 2026-11-21)
Từ hai bản đánh giá ngoài 2026-11-21; các việc nhanh đã làm (nền đấu cache, cảnh báo FX thiếu, F1 overlay, cache JSON,
gom bậc chiêu, bỏ GIF khỏi git, boss FX cỡ nguyên, tuỳ chọn Hiệu ứng). Còn lại, theo thứ tự lợi ích / công sức:
1. **Bụi đòn dậm của boss** (`boss-slam` khung bụi) là đám chấm phủ lên boss, cùng lỗi với hiệu ứng cháy cũ: vẽ lại bằng
   khối đặc có viền, mờ bằng alpha của game. · cỡ S
2. **Kiểm boss tách** (Vua Thạch Nhầy 75/50/25%): chụp đúng khoảnh khắc tách, xác nhận không đè hình hai vua và không
   khựng khi sinh slime con (ảnh 2026-11-21 chưa bắt được lúc tách: `production/qa/evidence/boss-split/`). · cỡ S
3. **Nạp sprite khi cần**: `_ready` nạp mọi sprite của class / quái / aura; nạp theo chiêu, quái thật sự có trong ải
   (đo thời gian vào trận trước / sau). · cỡ M
4. **Đồng bộ mật độ hiệu ứng cũ** lên chuẩn `px_scale` 0,5 (hiệu ứng chiêu vật lý đang phóng theo cỡ chiêu, hệ số lẻ):
   vẽ lại ở mật độ gấp đôi theo `boltfx` / `icefx`. · cỡ L
5. **Gom giá trị mặc định**: 305 chỗ `.get("khoá", mặc_định)` lặp lại số đã có trong JSON; đọc qua một lớp dữ liệu có
   schema để sửa JSON không lệch âm thầm. · cỡ L
6. **Tách `run.gd`** — tiến độ 2026-11-22: 3.341 → 3.003 dòng qua các lát `BossView`, `RegionEvents`, `ChallengeEvents`,
   `RunArgs`, `ObstacleView`, `RunSheet` (mỗi lát một commit, test + ảnh giữ nguyên). Còn: lên cấp / thẻ (`_open_level_up`,
   `choose`), ví + rơi đồ (`_drops`), camera, bọc mảng `Enemies`.
   Mô tả gốc: **Tách `run.gd`** (≈3.200 dòng: mô phỏng, vẽ, FX, lên cấp, ví, camera, boss) thành các node / lớp riêng; **bọc mảng
   của `Enemies`** (36 chỗ `run.gd` truy cập trực tiếp). Làm sau mục 5, từng phần một, test giữ nguyên. · cỡ XL
Đo trước / sau bằng `godot --path . res://src/run/run.tscn -- --bench=200` **có GPU** (cửa sổ thật). Chạy dưới
`xvfb-run` thì vẽ bằng CPU: `frame_ms` (~42 ms) không so được với số GPU (~9,6 ms); `sim_ms` vẫn so được.

**Đã xong sau đó (2026-11-21):** mục 1 (bụi dậm: cụm bụi quanh mép, mờ bằng alpha, `9d3bbe2`); mục 2 (boss tách:
không đè hình hai vua, chỉ một vương miện; sửa quầng nội tại của slime con che boss: quầng vẽ trước mọi quái,
`production/qa/evidence/boss-split/06-…`, `07-…`); mục 3 (chỉ nạp sprite chiêu dùng được trong trận: kiếm sĩ
98 → 73 sprite, 103 → 36 ms; pháp sư 117 → 81, 129 → 64 ms). Mục 8 (test đường cong độ khó: mỗi ải khó hơn ải trước, tăng tối đa 40%;
hiện +7…+25%, ải boss +18…+27%, ải 11 +37%; `tests/integration/data/difficulty_curve_test.gd`). Mục 9 (`gamekit tidy` bỏ 10 agent Unity / Unreal của
game Godot; chạy lại sau mỗi lần nâng framework). Mục 4 phần lớn (Chém kiếm, Lốc xoáy và các bậc ở mật độ
gấp đôi `px_scale` 0,5; `tierfx` mang `px_scale` sang bậc). **Còn:** Sóng kiếm (`sword-wave` cắt từ `cleave-wave` rồi
xoay 16 hướng: phải vẽ lại từng hướng như `boltfx`, cỡ M). Mục 5 phần `run_config`: test `config_defaults_test` quét mọi
`cfg.get(…, số)` trong `src/`, số mặc định phải bằng JSON hoặc trung tính 0 / 1 (sửa 2 chỗ lệch: `max_enemies` 600 → 200,
`gold_chance` 0,1 → 0,12). **Còn:** mở rộng cách kiểm này cho `monsters.json`, `upgrades_*.json`, `items.json`.
Mục 6–7 đang làm theo lát (mỗi lát giữ nguyên test và hình): lát 1 `StatusView` (`src/run/status_view.gd`: trạng thái trên
quái, `run.gd` 3.341 → 3.308 dòng); lát 2 `RunDebug` (`src/run/run_debug.gd`: bench + overlay F1, còn 3.256 dòng). Lát kế: tham số dòng lệnh, bench + overlay debug, vẽ boss (root walls, bolts,
waves), level-up / ví, rồi hành vi quái theo kiểu Strategy trong `enemies.gd`.

**Đánh giá ngoài lần 3 (2026-11-21), đã kiểm từng ý:**
- Đã làm: save ghi qua file tạm + giữ `.bak`, tự khôi phục khi file hỏng (`e68f57a`); tối đa 2 hiệu ứng trạng thái vẽ
  trên một quái, theo `priority` (`statuses.json`).
- Đã có sẵn, không cần làm: chống vỡ tiếng (`sound.gd` có `gap`, `voices`, `jitter` theo từng âm); save có `version`
  và hàm migrate (`slot.gd`); pickup / quái / số sát thương là mảng dữ liệu, không tạo-huỷ node, nên không cần object pool.
- Không làm (lý do): `design/skill-tree.md` đã ghi "thay bằng v2" nhưng vẫn giữ phần tiền tệ và đặt lại đang dùng, và
  `01i-skill-tree.png` là màn hiện tại, không phải bản cũ.
- Đưa vào kế hoạch:
  7. **Tách hành vi quái / kỹ năng** theo kiểu Strategy (`src/run/enemies/behaviors/`, `src/run/skills/`): gộp với mục 6,
     làm cùng lúc tách `run.gd`. · cỡ XL
  8. **Test đường cong độ khó** các ải trung gian (2–9, 12–19, 22–29, dùng công thức) và bước nhảy ở ải boss: đo bằng
     mô phỏng, chặn bằng test. · cỡ M
  9. **Tinh gọn `.claude/` của game** (agent / rule Unity, Unreal, console): `.claude/` là bản sao của framework và được
     nâng bằng `UPGRADING.md`, nên chỉ làm qua cấu hình `project.yaml` (tắt engine khác) hoặc khi framework hỗ trợ, không
     xoá tay. · cỡ M
  10. Cung thủ / Sát thủ: đã nằm ở Đợt 6.

## Yêu cầu người dùng 2026-11-21 (làm theo thứ tự này)
1. **Boss chết có màn kết:** hoạt ảnh boss chết + chậm thời gian + dòng chúc mừng, rồi mới hiện bảng thắng. · S
2. **Vũng độc ải 2x:** chỉ gây sát thương theo thời gian khi đứng trong vũng (không thành trạng thái trúng độc mang
   theo), thêm hiệu ứng độc trên người khi đứng trong vũng. · S
3. **Tỉ lệ thẻ theo cấp:** cấp càng cao càng dễ ra thẻ hiếm trở lên (ví dụ cấp 1: Thường 70 / Hiếm 20 / Sử thi 7 / Huyền
   thoại 3, mỗi cấp dịch dần, có trần); bảng tỉ lệ hiển thị trong game và dashboard; thẻ chỉ số không giới hạn cấp;
   hết thẻ nâng được thì luôn ra thẻ chỉ số, không để trống. · M
4. **Thử thách trong trận:** dễ hoàn thành hơn và đa dạng hơn; giải thích + báo rõ sự kiện Mưa thiên thạch. · M
5. **Tinh gọn tiếp:** `gamekit tidy` bỏ `docs/engine-reference/{unity,unreal,web}` và template chứng nhận console của
   game Godot (giữ Steam / itch vì Đợt 7); gộp phần còn dùng của `design/skill-tree.md` vào `skill-tree-v2.md` rồi lưu
   trữ bản cũ ở `design/archive/`. · S
6. Đã có trong kế hoạch: tách `enemies.gd` / `run.gd` (mục 6–7, đang làm theo lát); Cung thủ / Sát thủ (Đợt 6).

**Đã xong (2026-11-21):** 1 màn kết hạ boss (`a7e6ee1`), 2 hiệu ứng độc (`7a63e2b`), 3 tỉ lệ thẻ theo cấp + thẻ chỉ số
không giới hạn + bảng tỉ lệ (`c05a9f8`), 4 thử thách dễ hơn + Thu thập sao + Săn tinh anh + câu báo thiên thạch
(`5fff077`), 5 tinh gọn (`ec120e4`, gộp skill-tree v1 vào v2).

**Tạm đóng (người dùng 2026-11-21):** Mưa thiên thạch không khớp nội dung của vùng → `run_config.json`
`events.meteor.enabled = false`. Làm lại sau: mỗi vùng có sự kiện đúng chủ đề của vùng đó.

## Yêu cầu người dùng 2026-11-21 (đợt 2)

**Đã xong:** Chém kiếm xa hơn + hệ số 1.3 (`83d023e`); icon Bất khuất cân (`4ff7ee5`); sự kiện vùng: Lốc cỏ
(`842b4e1`), Cây đổ (`c78eb26`), Nước độc dâng (`ffb2c1e`), cổng màn 5 (`fd1f455`). Bước 6–7 của
`design/region-events-plan.md` xong (bỏ thiên thạch, tài liệu, gốc cây cụt).

**Việc lớn (tham khảo ≥ 2 game cùng thể loại → tài liệu thiết kế → code theo lát):**

1. **Cơ chế giáp.** ✅ 2026-11-21 (`21bc90f`, `design/armor.md`): giáp % kiểu Brotato. Còn: xuyên giáp của quái/boss. Trước đó giáp chỉ là trừ phẳng (`armor`: mỗi đòn trừ N, tối thiểu 1; thẻ Da thép / Áo phép +2,
   đồ). Cần thiết kế: giáp theo tỉ lệ (vd. giảm % = giáp/(giáp+K)) hay phẳng, xuyên giáp của quái/boss, giáp từ
   trang bị và cây kỹ năng, hiện trên bảng Nhân vật. Hỏi người dùng nếu tham khảo không chốt được.
2. **Hệ thống scale theo chỉ số.** Lát 1 ✅ 2026-11-21: `"scale"` trong skills, 5 chiêu scale theo máu/giáp/tốc độ, bảng Nhân vật + dashboard ghi "Scale theo". Còn: mở rộng cho mọi chiêu, thẻ/đồ theo lối xây dựng. Mỗi chiêu khai báo nó scale theo chỉ số nào (sát thương, giáp, máu tối đa,
   tốc độ chạy, tầm hút…) với hệ số riêng, ví dụ `"scale": {"damage": 1.3, "armor": 0.5}`; vẫn giữ chỉ số riêng
   của chiêu (`skill_damage.<id>`). Kéo theo: thẻ/đồ có ý nghĩa cho nhiều lối xây dựng (kiếm sĩ trâu scale giáp,
   pháp sư scale tốc độ…), bảng Nhân vật ghi "scale theo", dashboard hiện cột này. Tham khảo: Brotato (chỉ số
   scale ghi trên vũ khí), Halls of Torment, Vampire Survivors.
3. ✅ 2026-11-22 **Thiết kế lại Sóng kiếm** (bước 1–4 xong; còn bước 5 đo tỉ trọng sát thương, bước 6 dashboard) và **Cột thánh quang** (ấn thánh báo trước, cột mép thẳng, rơi vào chỗ quái đông). **Thiết kế lại Sóng kiếm** (người dùng 2026-11-21: "không đẹp, khá phế"): kế hoạch `design/cleave-wave-redesign.md`
   (vẽ từng hướng, vệt kéo, màu riêng, nở rộng khi bay, hitbox xoay theo hướng, lên cấp xoè/vỡ lưỡi). Gộp luôn
   nợ kỹ thuật mục 4 (Sóng kiếm vẽ lại từng hướng). Làm trước Album. (Lần đầu nhầm sang Chém kiếm:
   `blade-arc-redesign.md` dừng sau bước 1, giữ phần đã sửa.)
4. **Lốc xoáy yếu** (đo 2026-11-22: 4–11% sát thương cả trận khi cùng cấp với Chém kiếm / Đất nứt / Sóng kiếm).
   Đã nâng: xoáy 0,9 → 1,5 s, 3 → 6 nhịp, damage_mul 0,6 → 0,9 (≈ ×3 mỗi lần xoáy; hồi chiêu giữ, người dùng đã
   muốn chiêu vùng hồi lâu) → 8–13%. Tỉ trọng còn thấp vì Sóng kiếm hạ quái từ xa trước khi chúng tới gần; nếu vẫn
   thấy yếu khi chơi thì đổi cách đánh (kéo quái vào tâm xoáy).
5. **Album (bách khoa).** Màn mới ở sảnh: mọi kỹ năng, quái, boss, vật phẩm; quái/boss **mở khoá sau khi hạ
   lần đầu** (lưu trong slot), chưa mở thì hiện bóng đen "???"; trang chi tiết có chỉ số, chiêu, vùng xuất hiện.
   Kỹ năng có **mô phỏng** như trong trận (dùng lại sân demo của dashboard / `SpriteSheet` + hitbox). Tham khảo:
   Vampire Survivors Collection/Bestiary, Hades Codex, Brotato encyclopedia.

## Sau đó
- Chế độ endgame (ải vô tận, thử thách tuần, boss rush), thêm class, mùa sự kiện.

---

## Cách làm từng đợt (workflow)
1. Đầu đợt: chốt danh sách việc từ mục của đợt (có thể dùng `/create-stories` khi rigor = standard).
2. Sprite cần cho đợt: làm trong Sprite Lab (`gamekit art new/run/shot`), duyệt, rồi `gamekit art promote <tên> bach-ai`.
3. Code: logic thuần + test trước, rồi gắn vào cảnh; `gamekit test bach-ai` và `gamekit shot bach-ai` sau mỗi thay đổi nhìn thấy được.
4. Cuối đợt: chơi thử, ghi câu trả lời cho "Câu hỏi" của đợt vào `production/playtests/`, cập nhật bảng "Quyết định còn mở", rồi mới sang đợt sau.
