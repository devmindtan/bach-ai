# Bách Ải: kế hoạch theo đợt

Thiết kế: [`design/game-brief.md`](../design/game-brief.md) · Quái vật: [`design/monsters.md`](../design/monsters.md)
Nguyên tắc: **làm cho vòng lặp cốt lõi vui trước**, rồi mới tới hệ thống lâu dài. Mỗi đợt kết thúc bằng một bản chạy
được, có test và ảnh chụp, và một câu hỏi được trả lời bằng chơi thử. Đợt sau chỉ bắt đầu khi đợt trước đạt.

## Đã quyết (2026-11-16)

| Chủ đề | Quyết định |
|---|---|
| Thể loại | survivors-like + RPG theo class |
| Lượt chơi | **Mỗi ải là một lượt mới**: vào ải bắt đầu cấp 1, lên cấp chọn 1/3 nâng cấp theo class, hết lượt thì cấp mất |
| Sức mạnh lâu dài | Cây kỹ năng theo class, trang bị (vũ khí, giáp), gacha, hiệu ứng mốc mỗi 10 ải, tất cả gắn với **slot nhân vật** |
| Hiệu ứng ải 10/20/30 | Vượt ải 10, 20, 30 (mở rộng: mỗi 10 ải) → chọn 1/3 hiệu ứng đặc biệt **vĩnh viễn** cho slot |
| Quái vật | Vẽ mới trong Sprite Lab, cùng phong cách tối giản 48 px với nhân vật |
| Nền tảng | **PC trước** (Steam: Windows/Linux, bàn phím + tay cầm); mobile sau (đợt 8) |
| Engine | Godot 4.7.2, GDScript, gamekit (test, shot, export) |
| Gacha | Quay bằng **đá gacha trong game**, cày được bằng cách chơi (vượt ải, boss, nhiệm vụ). **Nạp tiền tính sau** (2026-11-16, you said) |
| Nhân vật & đòn đánh | Nhân vật **chỉ có góc ngang trái/phải** (trái = lật): `idle`, `run`, `hurt`, `death`. Đòn đánh là **sprite hiệu ứng riêng** (có hitbox), không vẽ vào thân (2026-11-16, you said) |
| Mặc giáp | Nhân vật vẽ **theo lớp** (tóc, mặt, thân áo, tay áo, bàn tay, quần, giày, khăn, vũ khí); đồ mặc thay lớp của ô trang bị, game ghép lớp rồi viền (`SpriteSheet.compose_layers`) (2026-11-16, you said) |
| Phản hồi đòn đánh | Hiện **số sát thương** bay lên khi đánh trúng; **thanh máu quái chỉ hiện khi bị đánh** (2 s sau mỗi đòn) (2026-11-16, you said) |

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
- **Lưu:** `user://slots/<id>.json` có số phiên bản schema; mỗi slot = class + cây kỹ năng + túi đồ + ải đã vượt + hiệu ứng mốc.
- **Sprite:** làm trong Sprite Lab, đưa vào game bằng `gamekit art promote <tên> bach-ai`, vẽ bằng `SpriteSheet`.

---

## Đợt 0: Nền móng · cỡ S
**Mục tiêu:** dự án sẵn sàng để làm đợt 1.
- `gamekit new bach-ai` (xong), brief, roadmap, danh sách quái (tài liệu này).
- `project.yaml`: rigor (đề xuất `standard` từ đợt 3 vì có nhiều hệ thống liên quan nhau; đợt 1–2 dùng `minimal`).
- InputMap, cấu trúc thư mục `src/core`, `src/run`, `src/ui`, `src/meta`; schema dữ liệu ghi trong `design/data-schemas.md`.
**Xong khi:** `gamekit test bach-ai` chạy (0 test), `gamekit run` mở cảnh trống, mọi file đã commit.

## Đợt 1: Lượt chơi cốt lõi (vertical slice) · cỡ L
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
**Câu hỏi:** hai lượt cùng class có ra hai build khác nhau thật không?
- Class **Pháp sư** (tầm xa: fireball, frost-shard…).
- Mỗi class: ~8 chiêu chủ động + ~8 nội tại, mỗi cái tối đa cấp 5; thẻ hiển thị cấp hiện tại → kế tiếp; (tiến hoá chiêu: để đợt 6).
- Quái tinh anh (to hơn, hào quang, nhiều máu, rơi rương); rương = chọn thêm 1 nâng cấp.
- **Boss ải 10:** Vua Slime (tách nhỏ khi bị đánh).
- Cảm giác đánh: số sát thương, nháy trắng, rung nhẹ, khựng khung hình khi chí mạng; vật phẩm rơi: vàng, nam châm, bình máu.
**Xong khi:** mỗi class có thể chơi trọn một lượt với ít nhất 3 hướng build khác nhau (ghi lại 3 build mẫu); boss có 2 đòn.

## Đợt 3: Tiến trình ải 1–30 + slot nhân vật · cỡ M
**Câu hỏi:** độ khó tăng có đều không, người chơi có muốn "thêm một ải nữa" không?
- `stages.json` + công thức scale (máu/sát thương/mật độ quái theo ải, loài quái theo vùng, boss mỗi 10 ải); ghi đè tay khi cần.
- Màn chọn ải (1 → ải cao nhất đã mở), màn kết quả (vàng, đá gacha, điểm kỹ năng nhận được).
- **Slot nhân vật:** tạo (chọn class, đặt tên), chơi, xoá; lưu `user://slots`.
- **Hiệu ứng mốc ải 10/20/30:** vượt ải → chọn 1/3 hiệu ứng vĩnh viễn (ví dụ: "mỗi 10 giây phát nổ quanh người", "chiêu đầu tiên +1 đạn", "hồi 1% máu mỗi lần hạ quái tinh anh").
**Test:** công thức scale (đơn điệu tăng, không nhảy vọt), lưu/đọc slot (phiên bản schema, file hỏng → báo lỗi, không mất slot khác).
**Xong khi:** vượt được ải 1–30 với 2 class trong thời gian hợp lý; đường cong độ khó vẽ thành biểu đồ để xem.

## Đợt 4: Cây kỹ năng + trang bị · cỡ L
**Câu hỏi:** đầu tư lâu dài có làm người chơi thấy rõ nhân vật mạnh lên giữa các lượt không?
- **Cây kỹ năng theo class**: điểm từ vượt ải / lên cấp tài khoản; nhánh (ví dụ Kiếm sĩ: Phòng thủ / Cuồng nộ / Kiếm khí); có nút đặt lại (mất ít vàng).
- **Trang bị:** ô vũ khí, mũ, áo, găng, giày; độ hiếm (thường → huyền thoại); chỉ số chính + dòng phụ + **hiệu ứng đặc biệt** ở hiếm cao; rơi từ boss/rương.
- Túi đồ, so sánh chỉ số, cường hoá bằng vàng.
**Xong khi:** một slot có cây kỹ năng 20 điểm và bộ trang bị mạnh vượt ải 30 nhanh hơn rõ rệt (số đo thời gian/máu còn lại).

## Đợt 5: Gacha · cỡ M
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
- 5 vùng × 20 ải (đồng cỏ, nghĩa địa, hang băng, núi lửa, hư không); mỗi vùng 3–4 loài quái mới + 2 boss.
- Class **Cung thủ** và **Sát thủ** (chiêu và giáp đã có trong Sprite Lab; cần vẽ nhân vật).
- Tiến hoá chiêu (chiêu cấp 5 + nội tại phù hợp → bản tiến hoá).
- **Mô phỏng cân bằng:** bot chạy headless từng ải với build mẫu, ghi thời gian sống/DPS → điều chỉnh công thức.
**Xong khi:** ải 100 vượt được với build đầu tư hợp lý, không vượt được với build trống (số đo từ mô phỏng).

## Đợt 7: Hoàn thiện + Steam · cỡ L
- Âm thanh, nhạc theo vùng; cài đặt (âm lượng, phím, độ phân giải); tay cầm đầy đủ; tiếng Việt + tiếng Anh.
- Steam qua GodotSteam: thành tựu, lưu đám mây; trang cửa hàng (ảnh, trailer); bản demo (ải 1–10).
- `gamekit export`, kiểm tra trên Windows thật.

## Đợt 8: Mobile (sau khi có bản PC)
- Joystick ảo, UI theo ngón tay, tỉ lệ màn hình; export Android, rồi iOS.

## Sau đó
- Chế độ endgame (ải vô tận, thử thách tuần, boss rush), thêm class, mùa sự kiện.

---

## Cách làm từng đợt (workflow)
1. Đầu đợt: chốt danh sách việc từ mục của đợt (có thể dùng `/create-stories` khi rigor = standard).
2. Sprite cần cho đợt: làm trong Sprite Lab (`gamekit art new/run/shot`), duyệt, rồi `gamekit art promote <tên> bach-ai`.
3. Code: logic thuần + test trước, rồi gắn vào cảnh; `gamekit test bach-ai` và `gamekit shot bach-ai` sau mỗi thay đổi nhìn thấy được.
4. Cuối đợt: chơi thử, ghi câu trả lời cho "Câu hỏi" của đợt vào `production/playtests/`, cập nhật bảng "Quyết định còn mở", rồi mới sang đợt sau.
