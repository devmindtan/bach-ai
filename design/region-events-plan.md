# Kế hoạch: sự kiện vùng theo từng bản đồ

Trạng thái: **đã xong 2026-11-21** (bước 2–7; bước tra cứu Internet mục 3 vẫn còn). Người viết: OpenCode 2026-11-21. Người thực hiện: agent khác.
Mục tiêu: thay **Mưa thiên thạch** bằng **một sự kiện riêng cho mỗi vùng**, hợp với địa hình và quái của vùng đó;
màn 1–4 không có sự kiện vùng, từ màn 5 mới có.

## 1. Quyết định đã chốt với người dùng (2026-11-21)

| Việc | Quyết định |
|---|---|
| Mốc màn | **Cả lượt chơi**: màn 1–4 yên, từ màn 5 sự kiện vùng mới bật (mọi vùng). |
| Sự kiện chung | **Giữ nguyên** Vòng thử thách / Thu thập sao / Săn tinh anh; chỉ thay Mưa thiên thạch. |
| Mưa thiên thạch | Người dùng đã tắt (`run_config.json` → `events.meteor.enabled: false`). **Không bật lại**; code cũ chỉ dùng làm mẫu rồi xoá (bước 7). |
| Số sự kiện mỗi vùng | 4: 3 sự kiện chung + 1 sự kiện riêng (thay chỗ thiên thạch). |

## 2. Hiện trạng cần biết trước khi sửa

- Lịch: `assets/data/stages.json` → `regions[].events` (mỗi vùng 4 mốc, hiện có 1 `meteor`).
- Số liệu: `assets/data/run_config.json` → `events` (`ring`, `meteor`, `gold_chest`, `collect`, `hunt`, `source_names`, `source_icons`).
- Nối dây trong `src/run/run.gd`:
  - khai báo `_ring_times` / `_meteor_times` / `_field_events` (dòng ~181–189),
  - dựng lịch theo vùng + `--event` (dòng ~252–267),
  - `event_enabled()` (dòng ~2004) — đọc `events.<kind>.enabled`, mặc định `true`,
  - gọi mỗi khung hình `_step_meteors(dt)` (dòng ~664) và vẽ `_draw_meteors()` (dòng ~2664),
  - thân sự kiện: `_step_meteors()` + `_draw_meteors()` (dòng ~3046–3105).
- Mẫu để copy: `src/run/meteor_shower.gd` (`start(cfg)` / `step(dt, player_pos, rng)` / `busy()` / `hits()`),
  test `tests/unit/run/meteor_shower_test.gd`.
- Sự kiện chung: `src/run/field_challenge.gd` + `challenge_ring.gd` — **không sửa luật** của chúng.
- Vũng độc: `src/run/obstacles.gd` (`pools: [{p, r}]`, `pool_dps`, `in_pool()`), áp dụng ở `run.gd` `_step_pools_hazard()`.
- Địa hình/quái mỗi vùng: `design/regions.md`, `assets/data/waves/stage_001|011|021.json`,
  vật cản `regions[].obstacles` (đồng cỏ: đá; rừng: cây; đầm: 16 vũng độc, dps 4).
- Quy ước: tên hiển thị tiếng Việt, id/file tiếng Anh; số liệu nằm trong JSON, không hardcode trong code;
  mỗi bước là một commit có test + ảnh; chạy `gamekit test bach-ai` (nền hiện tại 367 passed).

## 3. Tham khảo (bắt buộc đọc lại trước khi chốt số liệu)

Hôm nay **không tra được Internet**: `websearch` trả HTTP 402, `curl` tới trang tham khảo trả 403
(2026-11-21). Vì vậy phần dưới là **giả thuyết từ hiểu biết sẵn có, chưa kiểm chứng trong ngày**:

| Nguồn (chưa mở lại được) | Điều tin là đúng | Dùng cho |
|---|---|---|
| Risk of Rain 2 — Glowing Meteorite (đã dẫn trong `design/events.md`) | Báo trước bằng vòng trên đất, nổ trúng cả người lẫn quái | Mẫu "báo trước rõ" đã dùng; sự kiện mới giữ nguyên tắc này |
| Vampire Survivors — Mad Forest / Inlaid Library / Dairy Plant | Mỗi màn có đồ vật và hiểm họa riêng của màn, không dùng lại của màn khác | Mỗi vùng một sự kiện, không chung chung |
| Brotato / Halls of Torment | Hiểm họa theo đợt ngắn, có báo trước, thưởng thêm nếu né giỏi | Nhịp 8–10 s, có thưởng nhẹ |

**Người thực hiện phải:** thử lại bước tra cứu (2–3 bài/wiki về hiểm họa theo biome), ghi nguồn + "học / tránh /
quyết định" vào mục này trước khi tinh chỉnh hình ảnh và số liệu. Không có Internet thì giữ nguyên ghi chú này và
nói rõ đã bỏ bước.

## 4. Ba sự kiện đề xuất

Nguyên tắc chung: báo trước ≥ 1 s, đọc được trên nền của chính vùng đó, **dùng thứ đã có trong vùng** (vật cản,
vũng độc, quái), trúng cả người lẫn quái khi hợp lý, kết thúc bằng thưởng nhẹ. Số liệu là **điểm khởi đầu**,
chỉnh sau khi chơi thử; tất cả nằm trong `run_config.json`.

### 4A. Đồng cỏ — Lốc cỏ (`tornado`)

- **Vì sao hợp:** đồng cỏ mở, ít vật cản; lốc dạy né theo đường thẳng và dùng khoảng trống của map.
- **Diễn biến:** báo 1,5 s (vòng bụi cỏ xoáy + tiếng gió) tại điểm cách người chơi ~220 px; lốc chạy thẳng
  170 px/s xuyên qua khu vực người chơi trong 9 s, bán kính 70.
- **Sát thương:** người chơi 8 mỗi lần trúng, tối đa theo `hit_invuln` 0,6 s (đi qua `_take_hit` để giáp / khiên /
  lướt / bất tử áp dụng như mọi đòn); quái 30 mỗi 0,5 s và bị đẩy ra.
- **Thưởng:** 3 hạt giống (coin) rơi dọc đường lốc đã đi.
- **Đọc trên nền:** cột bụi vàng nhạt + lá cỏ bay trên nền xanh `2f4a2c`; không dùng đỏ (đỏ dành cho đòn của quái).
- **Config:** `events.tornado` `{telegraph: 1.5, speed: 170, radius: 70, duration: 9, player_damage: 8,
  monster_damage: 30, tick: 0.5, seeds: 3}`.

### 4B. Rừng Âm U — Cây đổ (`falling_trees`)

- **Vì sao hợp:** rừng đã có `obstacle-tree`; cây đổ biến vật trang trí thành hiểm họa và làm đổi không gian đi lại.
- **Diễn biến:** 3 đợt, cách 2,5 s. Mỗi đợt chọn một cây cách người chơi ≤ 300 px; báo 1,2 s (bóng cây đổ + bụi),
  rồi cây đổ về phía người chơi: dải dài 150, rộng 46 tính từ gốc cây.
- **Sát thương:** người chơi 14 (một lần mỗi đợt), quái 60. Thân cây nằm lại 4 s làm vật cản tạm rồi mờ dần.
- **Thưởng:** không thêm đồ rơi; thưởng là cơ hội dọn quái bằng cây (giống ý đồ của thiên thạch cũ).
- **Đọc trên nền:** bóng cây tối đậm + bụi sáng trên nền `223a2c`; dải báo trước có viền sáng để không lẫn với bóng
  trang trí sẵn có.
- **Config:** `events.falling_trees` `{waves: 3, interval: 2.5, warn: 1.2, range: 300, length: 150, width: 46,
  player_damage: 14, monster_damage: 60, linger: 4}`.

### 4C. Đầm Lầy Độc — Nước độc dâng (`poison_tide`)

- **Vì sao hợp:** đầm đã có 16 vũng độc (dps 4); sự kiện phóng đại đúng cơ chế sẵn có thay vì thêm hệ thống mới.
- **Diễn biến:** báo 1,5 s (mặt nước sôi + bong bóng); 3 vũng trong 280 px quanh người chơi (ưu tiên vũng có sẵn)
  lớn dần lên bán kính 110 trong 1,5 s, giữ 7 s, rồi rút về như cũ.
- **Sát thương:** 6 máu/giây khi đứng trong, **không trừ giáp** — đúng luật vũng độc hiện tại
  (`_step_pools_hazard`), để người chơi không phải học một luật thứ hai. Quái không bị (như vũng cũ).
- **Thưởng:** khi rút, 2 ngọc độc (coin) ở tâm 2 vũng — hái được nhưng phải bước vào chỗ vừa là vũng.
- **Đọc trên nền:** viền vũng sáng dần khi dâng; trên nền `2b3a2a`-ish của đầm phải thấy rõ, kèm bong bóng.
- **Config:** `events.poison_tide` `{pools: 3, range: 280, grow: 1.5, radius: 110, hold: 7, dps: 6, gems: 2}`.

## 5. Cổng màn 5 (áp cho **mọi** sự kiện vùng)

- Dữ liệu: `run_config.json` → `events.min_stage: 5` (số nguyên; `1` = luôn bật).
- Code: thêm hàm tĩnh cạnh `event_enabled()` (dòng ~2004), ví dụ
  `static func events_open(config: Dictionary, stage_number: int) -> bool`, trả `stage_number >= int(...)`.
  Trong bước dựng lịch (dòng ~252): nếu `not events_open(cfg, stage_number)` thì **bỏ toàn bộ** mốc sự kiện vùng
  (ring, collect, hunt, sự kiện riêng). Chế độ thử thách vốn không dùng lịch này — giữ nguyên.
- `--event=K@T` (dùng cho ảnh) phải **vẫn chạy** ở màn < 5: áp `_forced_events` **sau** bước lọc trên.
- Test: `tests/unit/run/region_event_gate_test.gd` — màn 1, 4 → `false`; màn 5, 6 → `true`; config thiếu
  `min_stage` → `true` (tương thích save/cấu hình cũ).

## 6. Hợp đồng code (giữ đúng mẫu đang có, không thêm framework)

- Thư mục mới `src/run/region_events/`: `tornado.gd`, `falling_trees.gd`, `poison_tide.gd`.
  Mỗi lớp theo mẫu `MeteorShower`: `start(cfg)`, `step(dt, player_pos, rng)` trả dữ liệu cho run,
  `busy()` (đang báo hoặc đang diễn ra), `source` (id nguồn sát thương, thêm vào `events.source_names` /
  `source_icons`: "Sự kiện: …").
- Chọn lớp: `run.gd` đọc `kind` của vùng, `match` để tạo đúng lớp; giữ **một** biến `region_event` cho lượt chạy
  (mỗi vùng chỉ có một sự kiện riêng). Không dùng `MeteorShower` cho sự kiện mới.
- `run.gd`:
  - thay `_meteor_times` bằng `_region_event_times: Array` (mốc `t` của sự kiện riêng của vùng),
  - `_step_meteors()` → `_step_region_event()` gọi chỗ dòng ~664; giữ nguyên cách chặn chồng sự kiện
    (`busy()` của ring/field/sự kiện riêng — không bắt đầu cái mới khi cái khác đang chạy),
  - `_draw_meteors()` → `_draw_region_event()` gọi chỗ dòng ~2664; **không** gọi `_draw_meteors()` nữa.
- Không để rơi rác: mọi mảng/hiệu ứng tạm (`_tornado_seeds`, thân cây nằm lại…) dọn khi sự kiện kết thúc, và reset
  trong `_apply_stage`/lúc bắt đầu lượt để chơi lại vẫn sạch.
- Hiệu năng: không cấp phát mỗi khung hình; test đã có bench 30/200 quái — sự kiện không được làm frame 200 quái
  vượt ~18 ms (đo lại như mục 9).

## 7. Các bước thực hiện (mỗi bước = một commit xanh)

1. **Chuẩn bị hiểu biết.** Đọc `design/events.md`, `design/regions.md`, `obstacles.gd`, `run.gd` các dòng ở mục 2.
   Dùng `tools/gdgraph/gdgraph games/bach-ai` + `graphify explain "_step_meteors"` để khỏi đọc cả file.
   Không sửa gì. (Nếu Internet có, hoàn tất mục 3 trước.)
2. **Dữ liệu + cổng màn.** `run_config.json`: thêm `events.min_stage: 5`, ba khối config ở mục 4, ba dòng
   `source_names` / `source_icons`; cập nhật `_doc` của `events`. `stages.json`: đổi `kind: "meteor"` thành
   `tornado` / `falling_trees` / `poison_tide` (giữ mốc thời gian cũ). Thêm test dữ liệu + test cổng màn.
   Kiểm: `gamekit test bach-ai`; commit `feat(events): per-region event data and the stage-5 gate`.
3. **Lốc cỏ.** Lớp + test đơn vị + nối dây + vẽ + ảnh. Kiểm: test, `gamekit shot` (ảnh ở mục 8), commit
   `feat(events): Lốc cỏ in the meadow`.
4. **Cây đổ.** Như bước 3, commit `feat(events): Cây đổ in the forest`.
5. **Nước độc dâng.** Như bước 3, commit `feat(events): Nước độc dâng in the marsh`.
6. **Bỏ thiên thạch.** Chỉ sau khi ba sự kiện trên xanh: xoá `src/run/meteor_shower.gd` (+`.uid`), test của nó,
   `events.meteor` trong config, nhánh `meteor` trong `--event` và mọi tham chiếu còn lại. Kiểm: test + ảnh cũ
   vẫn mở được. Commit `refactor(events): drop the meteor shower now that every region has its own event`.
7. **Tài liệu.** `design/events.md`: thay mục Mưa thiên thạch bằng 3 mục theo vùng (giữ nguồn tham khảo + "học /
   tránh / quyết định"); `design/regions.md`: thêm cột "Sự kiện riêng"; ghi chú vào `production/roadmap.md`
   (yêu cầu 2026-11-21 đã xong). Commit `docs(design): region events replace the meteor shower`.

## 8. Test và ảnh bắt buộc

| Loại | Nội dung |
|---|---|
| Đơn vị | Mỗi lớp: báo trước → đang chạy → kết thúc; hàm `busy()`; sát thương đúng một lần/đợt (cây), đúng tick (lốc), đúng vị trí (vũng); dọn trạng thái sau khi xong; chạy 2 lượt liên tiếp không rò rỉ. |
| Dữ liệu | Mọi `kind` trong `stages.json` có config + tên/icon nguồn; `min_stage` = 5; không còn `meteor` sau bước 6. |
| Cổng màn | Hàm tĩnh: màn 1/4 tắt, 5/6 bật, thiếu khóa → bật; `--event` vẫn chạy ở màn 1. |
| Tích hợp | `gamekit test bach-ai` (0 failed) và 1 lượt tự động (`--god --demo`) qua đúng mốc sự kiện ở cả 3 vùng. |
| Ảnh | `gamekit shot bach-ai res://src/run/run.tscn <frames> -- --stage=5 --event=tornado@3 --god --demo --seed=7` (tương tự cho `falling_trees`, `poison_tide`, và một ảnh màn 1 với `--event=…` để chứng minh cổng màn chỉ chặn lịch, không chặn ảnh). Lưu vào `production/qa/evidence/region-events/`, xem ở ×2 từng vùng. |
| Hiệu năng | Đo lại bench 200 quái (lệnh trong `AGENTS.md`/roadmap) khi sự kiện đang chạy; ghi số vào commit/roadmap. |

## 9. Tiêu chí nghiệm thu

- Màn 1–4: không có bất kỳ sự kiện vùng nào (ring/collect/hunt/riêng) — chứng minh bằng test + ảnh.
- Từ màn 5: mỗi vùng có 4 mốc; sự kiện riêng xuất hiện đúng một lần/lượt, không chồng với sự kiện khác.
- Ba sự kiện riêng khác nhau về **cách chơi**, không chỉ đổi màu: né đường thẳng (lốc), đổi không gian đi lại
  (cây đổ), đọc và né vùng nguy hiểm (nước dộc dâng).
- Mỗi sự kiện đọc được trên nền vùng đó khi xem ảnh ×2; có báo trước ≥ 1 s; có thưởng khi xử lý tốt.
- Không còn tham chiếu `MeteorShower`/`meteor` trong code, config, lịch, test.
- Tên hiển thị tiếng Việt; id/file tiếng Anh; số liệu nằm trong JSON.
- `gamekit test bach-ai` xanh, ảnh trong `production/qa/evidence/region-events/`, mọi bước đã commit.

## 10. Không làm (ngoài phạm vi)

- Không đổi luật Vòng thử thách / Thu thập sao / Săn tinh anh (chỉ giữ nguyên).
- Không bật lại Mưa thiên thạch, không "thử xem còn hợp không".
- Không thêm hệ thống thời tiết/ngày đêm toàn cục, không đổi nhạc theo sự kiện (nhạc vùng đã có).
- Không sửa `templates/`, `tools/lpc-generator/`, không vẽ nhân vật mới.
- Không đổi mốc thời gian sự kiện của vùng trong bước này (giữ 180/170/150); chỉ đổi loại sự kiện.

## 11. Rủi ro và cách tránh

| Rủi ro | Cách tránh |
|---|---|
| `run.gd` đã 3.269 dòng, dễ hỏng | Mỗi sự kiện một file riêng, chỉ sửa đúng 4 điểm nối dây; commit từng sự kiện. |
| Sự kiện chồng nhau (ring/field đang chạy) | Giữ nguyên cờ `busy()` và điều kiện "chỉ bắt đầu khi không có sự kiện khác"; có test. |
| Số liệu sai làm game khó | Để trong JSON, chơi thử `--god --demo` + một lượt tay; chỉnh sau, ghi lại số đã chọn. |
| Vũng độc dâng làm mất lối đi | Giới hạn 3 vũng, ưu tiên vũng có sẵn, không phủ kín vùng quanh người chơi; test "còn lối đi". |
| Cây đổ đè lên tường/vật cản | Chọn cây trong `obstacles` sẵn có; dải đổ không tạo vật cản vĩnh viễn (4 s rồi bỏ). |
| Ảnh không chứng minh được cổng màn | Chụp thêm màn 1 không `--event` và màn 5 có `--event`; so sánh. |

## 12. Câu hỏi còn mở (hỏi người dùng nếu chạm tới)

- Số liệu sát thương/thời lượng cuối cùng cần người dùng chơi thử; kế hoạch chỉ đưa điểm khởi đầu.
- Có muốn giữ file `meteor_shower.gd` để tái dùng cho boss/màn khác sau này không? Mặc định: xoá (git còn lịch sử).
