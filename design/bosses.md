# Boss từng vùng

Mỗi vùng có boss riêng ở ải boss (ải 10/20/30), 2–3 đòn **có báo trước**, đổi pha ở 50% máu (kế hoạch 6A,
`production/upgrade-plan.md`).

## Tham khảo

| Nguồn | Điều lấy |
|---|---|
| Path of Exile 2, Rotten Druid ([hướng dẫn boss, GamerGuides](https://gamerguides.com/path-of-exile-2/guide/campaign/act-1/the-mysterious-shade-the-rotten-druid-boss-guide)) | Boss cây gọi rễ: rễ trồi lên **sát chỗ người chơi**, nối tiếp nhau; đòn mới thêm khi máu xuống. |
| Elden Ring, Scadutree Avatar ([Fextralife](https://eldenring.wiki.fextralife.com/Scadutree+Avatar)) | Pha 2 hung hãn hơn; **vòng sáng trên mặt đất báo trước** chỗ cành gai đâm lên. |
| Vua Thạch Nhầy của mình (`design/elite-affixes.md`, đợt 6A) | Pha 2 ở 50%: ửng đỏ + "nổi giận!", đòn dày hơn. |

**Học:** đòn vùng luôn có vòng báo, rễ nhắm vào chỗ người chơi đang đứng nên phải di chuyển. **Tránh:** rễ trồi
không báo, hoặc phủ kín màn (phải còn đường né). **Quyết định:** vòng báo 0,9 s rồi rễ đâm; một rễ nhắm đúng chỗ
đứng, các rễ còn lại rải trong 110 px.

## Mộc Yêu (Rừng Âm U, ải 20) · `tree_boss`, hành vi `boss_tree`

| Đòn | Pha 1 | Pha 2 (≤ 50% máu) |
|---|---|---|
| Rễ trồi: vòng nâu rêu 0,9 s → rễ đâm (30 sát thương, bán kính 30) | 3 rễ mỗi 3,2 s | 6 rễ mỗi 2,0 s |
| Gọi rừng: sói + 2 Ma Trơi quanh boss | mỗi 11 s | như pha 1 |
| Chạm thân | 20 | 20 |

Sprite: `tree-boss` (48×48), rễ `tree-roots` (`root_sprite`). Code: `Enemies._boss_tree`, `_add_blast(root=true)`;
vẽ trong `run.gd` (vòng báo rễ, `roots_done`). Test: `tests/unit/run/boss_tree_test.gd`.

## Cóc Chúa (Đầm Lầy Độc, ải 30) · `toad_king`, hành vi `boss_slime` + `pool`

Tham khảo thêm: Nioh, Giant Toad ([Fextralife](https://nioh.wiki.fextralife.com/Giant+Toad)): pha 2 ở 50% máu, cầu
độc chậm né được; Tomb Raider Reloaded, Giant Frog ([wiki](https://tombraider.fandom.com/wiki/Giant_Frog)): nhảy đè,
phun độc. **Học:** đòn độc chậm để né, nhảy đè có báo. **Quyết định:** mỗi cú đáp để lại vũng độc lớn, sân hẹp dần.

| Đòn | Pha 1 | Pha 2 (≤ 50% máu) |
|---|---|---|
| Nhảy đè (gồng 0,9 s → đáp: 38 sát thương) + **vũng độc** bán kính 56, 5 s | mỗi 4,2 s | mỗi 2,6 s, gồng 0,65 s, sóng xung kích |
| Phun chùm 7 đạn độc chậm (quạt 70°) | mỗi 3,6 s | như pha 1 |
| Gọi 4 Cóc Độc ở 75/50/25% máu | | |

Sprite `toad-king` (48×48). Test: `tests/unit/run/boss_toad_test.gd`.

## Pha 2 mới của Mộc Yêu và Cóc Chúa (người dùng 2026-11-19)

Ý tưởng của người dùng (bảng chỉ số, chiêu, ngoại hình). Người dùng chốt: Cóc pha 2 **thay** phun bào tử và tách cóc con
bằng bộ chiêu mới; Hấp thụ đệ **hồi máu theo số đệ**; thanh máu **hiện tên pha**.

Tham khảo thêm: [Salt & Steel: boss design](https://salt-and-steel.pages.dev/docs/15/boss-design), [Wanderfolk: bosses](https://wanderfolk-website.pages.dev/wiki/combat/bosses),
[Roblox: boss phases](https://robloxbossfightscriptphases.pages.dev), [Medium: multi-phase boss in Unity](https://medium.com/@scott.sourile/designing-a-multi-phase-boss-encounter-in-unity-pt-1-b06ed37aa3f0):
chuyển pha có dấu hiệu hình/tiếng riêng và **bất tử ngắn**; chuyển pha ngắn (≤ 3 s) có lực hơn; chiêu mới nào cũng có báo.

### Chuyển pha (chung, `phase2` trong `monsters.json`)

Khi máu xuống `rage_at` (50%): boss **bất tử 1,5 s**, đứng yên, rung + chớp trắng/đỏ, **đẩy người chơi ra** (320 px/s, giảm dần: khoảng 64 px), câu báo "<tên> · <tên pha>!", tên pha hiện trên thanh máu. Sau đó dùng sprite pha 2 (`rage_sprite`) và chỉ số pha 2:

| Chỉ số | Mộc Yêu → Cổ Thụ Trụi Lá | Cóc Chúa → Cóc Độc Bào Tử |
|---|---|---|
| Tốc chạy | ×1,7 (26 → 44; người chơi 158 không chạy nhanh hơn được bằng mặc định nên giữ dưới người chơi: xem ghi chú) | ×1,25 |
| Nhận sát thương | ×1,3 (mất tán lá) | ×0,9 |
| Hồi chiêu | ×0,75 (rễ, gọi đệ) | ×0,65 (nghỉ giữa chuỗi nhảy) |
| Chạm thân | ×1,2 | ×1,3 |
| Đẩy lùi | boss vốn không bị đẩy | như cũ |
| Bán kính va chạm | ×0,85 | ×1,1 |

Ghi chú tốc chạy: đề xuất "+60–80%, nhanh hơn tốc gốc người chơi một chút" dựa trên game không có lướt; Bách Ải
có lướt và tốc người chơi 158 ≫ 26, nên ×1,7 vẫn chậm hơn người chơi; áp lực đến từ tường rễ chặn đường.

### Cổ Thụ Trụi Lá (Mộc Yêu pha 2)

- **Bão lá rụng** (lúc chuyển pha): 24 chiếc lá bay tỏa tròn 360°, chậm (90 px/s), 12 sát thương; lách qua khe.
- **Rễ trồi** như pha 1 (6 rễ mỗi 2 s × 0,75).
- **Tường rễ gai**: mỗi 7 s, một đường rễ dài 260 px **chắn ngang** phía trước người chơi (vuông góc hướng boss → người
  chơi, cách người chơi 70 px): báo 0,6 s rồi mọc lên, đứng 4 s; **chặn cả người chơi lẫn quái**; mọc lên trúng người
  chơi: 20 sát thương.
- **Hấp thụ đệ**: quái boss gọi ra (pha 2) còn sống sau 6 s bị rễ kéo vào người boss: mỗi con hồi 2% máu, tối đa 10%
  mỗi lần gọi; vẽ dây rễ nối quái → boss.

### Cóc Độc Bào Tử (Cóc Chúa pha 2)

- **Nhảy liên hoàn 3 nhịp**: 3 cú nhảy liền về phía người chơi (gồng ngắn 0,3 s giữa các cú); **cú thứ 3 cao nhất**,
  đáp xuống tạo **sóng xung kích** đỏ/cam lan từ tâm (24 sát thương) và **hất văng** người chơi lẫn quái thường.
- **Vũng độc bào tử**: mỗi cú đáp để lại vũng **tím** 7 s (thay vũng xanh pha 1).
- **Phóng lưỡi kéo**: giữa các chuỗi nhảy, boss đứng yên **nháy đỏ 1 s** (vạch hướng lưỡi) rồi phóng lưỡi thẳng hướng đã
  ngắm (dài 300 px); trúng thì **kéo người chơi sát boss** và boss dậm tại chỗ ngay (38 sát thương). Né: chạy vuông góc
  hoặc lướt.
- Không còn phun bào tử và tách cóc con ở pha 2 (`split_at` chỉ còn 75%).

### Animation chuyển trạng thái (người dùng 2026-11-20: "các boss thiếu animation chuyển trạng thái")

Tham khảo: mẫu khựng → animation chuyển tiếp (gầm, biến hình) → pha 2 ([ludonauta: Hollow Knight style boss in Godot](https://ludonauta.itch.io/platformer-essentials/devlog/1089921/hollow-knight-inspired-boss-fight-in-godot-4));
gói asset boss tách riêng animation "vào pha 2" ([goblin boss phase 2](https://otsoga.itch.io/goblin-boss-phase-2)). **Quyết định:** sheet pha 2 của mỗi
boss có `transform` 12 khung, game trải đều nó trong 1,5 s bất tử (`Enemies.anim_of`), chỉ rung nhẹ, không chớp màu nữa:
Mộc Yêu rùng mình → tán rách, lá bung → lộ lõi ngọc → rễ co, cuộn thành chân → đứng dậy gầm; Cóc run → mụn đỏ dần → nấm
phình, hóa tím → bào tử nổ → gầm; Vua Thạch Nhầy run → nháy xanh/đỏ, đỏ dày dần → chớp trắng lúc gồng → đỏ hẳn, dấu giận
bật ra. Vua Thạch Nhầy có `phase2` không tên (chỉ chuyển pha 1,5 s + đẩy lùi), vẫn báo "nổi giận" như cũ.

### Sprite pha 2 (nâng cấp từ sprite đã duyệt, không vẽ lại)

Người dùng 2026-11-20: thân dưới Cổ Thụ Trụi Lá "xấu, phải hùng hổ hơn" → hai chân rễ to dạng bó rễ xoắn, chân vòng
kiềng đứng rộng, ống chân có gai, bàn chân 3 vuốt rễ + cựa, đất văng sau gót; hông bè; thân chúi tới và nhún mỗi bước;
mặt luôn cau, nhe nanh (tham khảo: [OpenGameArt treant](https://opengameart.org/content/treant-monster), [pixie.haus menacing treant](https://pixie.haus/pixelart/332489/sentient-tree-creature-aggressive-pose-animation)).


- `tree-boss-bare`: cùng thân, tán rụng sạch để lộ ngọn khô và **lõi tinh thể xanh ngọc** phát sáng; bộ rễ cuộn thành
  **hai chân thô** có chu kỳ chạy (move 8 khung).
- `toad-king-spore`: cùng thân cóc, cụm nấm trên lưng **phình to, tím rực**, nhả khói bào tử; nốt sần hai bên **đỏ rực**
  phập phồng.

## Quái hộ tống và nội tại boss (người dùng 2026-11-21)

Sau 5:00 (boss ra) quái vẫn sinh nhưng **ít mà mạnh** (đợt `escort` trong `waves/stage_0N0.json`: một loài thường của
vùng + thỉnh thoảng tinh anh). Khi boss còn sống, **nội tại** của nó (`monsters.json` → `aura`) buff mọi quái sinh ra:

| Boss | Nội tại | Hiệu ứng |
|---|---|---|
| Vua Thạch Nhầy | Thần dân nhầy | quái +60% máu |
| Mộc Yêu | Rễ nuôi | quái +50% máu, hồi 2% máu/giây (giai đoạn 2 hút chúng để hồi máu) |
| Cóc Độc Bào Tử | Khí độc | quái +35% sát thương, +25% máu |

Quái được buff có quầng màu của boss; tên nội tại báo giữa màn hình khi boss tới. Boss chết thì quái mới không còn buff.

## Hạ boss: đoạn kết (người dùng 2026-11-21)

Boss chết thì chưa hiện bảng thắng ngay: mọi quái trên sân chạy hoạt ảnh chết (không tính hạ, không rơi đồ), thời gian
chậm lại (×0,35) trong 3 giây thật, màn hình rung, giữa màn hình "Chiến thắng! Đã hạ <tên boss>", nhạc tắt; hết 3 giây
mới hiện bảng Vượt ải (`run_config.json` → `boss_outro`).
