# Sự kiện trong trận (6B.2)

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

## Còn lại

Mưa thiên thạch có báo, rương vàng hiếm.
