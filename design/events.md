# Sự kiện trong trận (6B.2)

> Mưa thiên thạch đã **bỏ** (2026-11-21): mỗi vùng có một sự kiện riêng hợp với địa hình của vùng, và sự kiện vùng
> chỉ có từ màn 5 (`events.min_stage`). Kế hoạch và số liệu khởi đầu: [`region-events-plan.md`](region-events-plan.md).

## Tham khảo

| Nguồn | Điều lấy |
|---|---|
| Diablo, Treasure Goblin ([Diablo Wiki](https://breezewiki.discard.no/diablo/wiki/Treasure_Goblin), [Diablo 4 guide](https://www.gamerguides.com/diablo-iv/guide/equipment/treasure-goblins)) | Không đánh, chạy tới chỗ an toàn và **rơi vàng dọc đường** (vệt vàng cũng giúp lần theo); đủ xa thì **mở cổng thoát**; **đánh trúng thì ngắt cổng**; hạ được thì rơi rất nhiều vàng. |

**Học:** phần thưởng lớn nhưng có hạn giờ, buộc người chơi rời chỗ an toàn để đuổi. **Tránh:** quái sự kiện xuất
hiện ngoài màn rồi chạy mất trước khi người chơi thấy. **Quyết định:** xuất hiện cách người chơi 300 px (trong màn),
có câu báo, chậm hơn người chơi một chút.

## Yêu Tinh Vàng (`gold_goblin`, hành vi `flee`)

- Xuất hiện một lần mỗi vùng (ải 1–9 giây 100, ải 11–19 giây 140, ải 21–29 giây 160), báo "Yêu tinh vàng xuất hiện! Đuổi theo!".
- Không gây sát thương; chạy thẳng ra xa người chơi (tốc 120, người chơi 158), rơi một đồng xu mỗi 0,7 s.
- Sau 14 s đứng lại mở cổng tím 2,5 s; trúng đòn thì cổng vỡ, chạy tiếp; cổng mở xong thì trốn ("Yêu tinh vàng đã trốn mất!").
- Hạ được: 25 vàng + 1 rương. Sprite `gold-goblin` (yêu tinh đổi màu vàng, áo tím).
- Code: `Enemies._flee`, `gold_trail`, `escaped`, `kill_gold`, `kill_chest`; `spawn_dist` cho quái sự kiện xuất hiện gần.
  Test: `tests/unit/run/flee_test.gd`.

## Vòng thử thách (`ChallengeRing`)

Tham khảo thêm: Risk of Rain 2, vùng giữ của dịch chuyển / Void Fields ([wiki Shrines](https://riskofrain2.wiki.gg/wiki/Shrines),
[Void Fields](https://riskofrain2.wiki.gg/wiki/Void_Fields), [Focused Convergence](https://rogueranker.com/focused-convergence-ror2/)):
chỉ tích năng khi đứng trong vùng; vùng nhỏ thì nhanh. **Quyết định:** vòng bán kính 70 cách người chơi 220 px (kẹp
trong bản đồ), đứng trong tổng 8 s thì xong (ra ngoài giữ nguyên tiến độ), hạn 30 s; xong rơi rương + 10 vàng.

- Mỗi vùng một lần (`stages.json` regions[].events: Đồng cỏ 70 s, Rừng 90 s, Đầm 110 s); không có ở chế độ thử thách.
- Số liệu ở `run_config.json` events.ring. Vẽ: vòng vàng dẹt trên đất, cung tiến độ, số giây còn lại; câu báo khi
  mở, khi xong ("Hoàn thành thử thách!") và khi hỏng ("Thử thách thất bại").
- Test: `tests/unit/run/challenge_ring_test.gd` (gồm lỗi vòng nằm ngoài biên bản đồ).

## Sự kiện riêng của vùng (`src/run/region_events/`, 2026-11-21)

Thay Mưa thiên thạch (bài học còn giữ, Risk of Rain 2 Glowing Meteorite và Last Epoch: báo trước rõ, tương phản với
nền, không chồng vòng). Tham khảo thêm (chưa mở lại được trong ngày, xem `region-events-plan.md` §3): Vampire
Survivors (mỗi màn hiểm hoạ riêng), Brotato / Halls of Torment (hiểm hoạ ngắn, có báo trước, có thưởng). Mỗi vùng một
lần, ở chỗ cũ của thiên thạch (`stages.json`: Đồng cỏ 180 s, Rừng 170 s, Đầm 150 s); không có ở màn 1–4, không có ở
thử thách. Cờ chụp `--event=<kind>@<giây>`. Số liệu `run_config.json` events.<kind>.

| Vùng | Sự kiện | Cách chơi | Số liệu | Test |
|---|---|---|---|---|
| Đồng cỏ | Lốc cỏ (`tornado`) | Né đường thẳng: vòng báo 1,5 s + vạch hướng, lốc chạy qua chỗ người chơi 170 px/s trong 9 s | người 8 / chạm (hit_invuln), quái 30 / 0,5 s; 3 hạt (vàng) dọc đường | `tornado_test.gd` |
| Rừng Âm U | Cây đổ (`falling_trees`) | Đổi không gian: 3 cây gần nhất (≤ 300 px) đổ về phía người chơi, báo 1,2 s bằng dải sáng | người 14 / cây, quái 60; thân cây chặn đường 4 s, chỗ cây cũ còn gốc cụt | `falling_trees_test.gd` |
| Đầm Lầy Độc | Nước độc dâng (`poison_tide`) | Đọc vùng nguy hiểm: 3 vũng (ưu tiên vũng có sẵn) sôi 1,5 s, nở tới 110 px, giữ 7 s, rút | 6 máu/s, không trừ giáp (như vũng đầm); vũng cách nhau, luôn có lối ra; 2 vàng khi rút | `poison_tide_test.gd` |

Cổng màn: `region_event_gate_test.gd`. Ảnh: `production/qa/evidence/region-events/`.

## Rương vàng (`Pickups.GOLD_CHEST`)

Tham khảo: Vampire Survivors, rương cho 1 / 3 / 5 món, rương hiếm hơn cho nhiều hơn ([Steam: luck và số món](https://steamcommunity.com/app/1794680/discussions/0/3201493834358639726),
[Zi'Appunta: rương vàng](https://rogueranker.com/zi-appunta-vampire-survivors/)); Diablo III, Resplendent Chest ([DiabloWiki](https://di.diablowiki.net/Golden_Chest)):
hiếm, ánh vàng, chắc chắn có đồ tốt và rải vàng. **Học:** cùng chỗ rơi với rương thường, chỉ hiếm hơn và nhìn là biết.
**Tránh:** thêm một loại phần thưởng mới khó hiểu. **Quyết định:**
- Mọi rương rơi ra (tinh anh, Yêu tinh vàng, Vòng thử thách) có 8% là **Rương vàng** (`run_config.json` events.gold_chest).
- Nhặt: chọn **liền 3 thẻ** (tiêu đề "Rương vàng! Chọn một (còn n lượt)"), **+30 vàng**, **chắc chắn một món trang bị**,
  tính là 3 rương khi chia Mảnh thẻ.
- Sprite `chest-gold` (nâng cấp từ `chest`: cùng dáng, thân vàng, khóa ngọc đỏ, sao lấp lánh). Cờ chụp `--gold-chest`.
- Test: `tests/unit/run/gold_chest_test.gd`.

## Thử thách dễ hơn và đa dạng hơn (người dùng 2026-11-21)

- **Vòng thử thách** dễ hơn: bán kính 110 (cũ 70), đứng tổng 5 s (cũ 8), hạn 40 s (cũ 30).
- **Thu thập sao** (`FieldChallenge` collect): 5 ngôi sao rải trong 260 px quanh người chơi, nhặt hết trong 20 s → rương + 10 vàng.
- **Săn tinh anh** (`FieldChallenge` hunt): tinh anh của vùng xuất hiện cách 320 px, có vòng đỏ đánh dấu, hạ trong 25 s →
  rương + 15 vàng.
- Mỗi vùng 4 sự kiện xen kẽ (`stages.json` regions[].events): Đồng cỏ vòng 70 s / săn 130 s / thiên thạch 180 s / sao 230 s;
  Rừng sao 60 / vòng 90 / thiên thạch 170 / săn 220; Đầm săn 80 / vòng 110 / thiên thạch 150 / sao 200.
- **Mưa thiên thạch** là sự kiện của vùng (không phải lỗi): tới giây đã định, vòng đỏ hiện quanh người chơi rồi thiên thạch
  rơi sau 1,2 s, trúng cả người lẫn quái. Câu báo giờ nói rõ: "Sự kiện vùng: Mưa thiên thạch! Tránh vòng đỏ, dụ quái vào".
- Cờ chụp: `--event=K@T` (ring | collect | hunt | meteor).
