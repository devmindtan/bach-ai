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

## Mưa thiên thạch (`MeteorShower`)

Tham khảo: Risk of Rain 2, Glowing Meteorite ([wiki.gg](https://riskofrain2.wiki.gg/wiki/Glowing_Meteorite),
[fandom](https://riskofrain.fandom.com/wiki/Glowing_Meteorite_(Risk_of_Rain_2))): vòng báo trên đất khoảng 1 s trước khi
rơi, nổ trúng **cả người lẫn quái**. Diễn đàn Last Epoch về vòng báo ([vòng khó thấy trên nền cùng màu](https://forum.lastepoch.com/t/poorly-telegraphed-high-damage-abilities/15075?page=8),
[quá nhiều vòng](https://forum.lastepoch.com/t/you-have-gone-overboard-with-the-telegraphing/26464)): vòng phải tương phản
với nền, không dày đặc. **Học:** báo trước rõ, nổ trúng cả quái (người chơi dụ quái vào vòng). **Tránh:** vòng cùng màu
nền, vòng chồng nhau, quá nhiều vòng một lúc. **Quyết định:**
- Mỗi vùng một lần (`stages.json` events kind `meteor`: Đồng cỏ 180 s, Rừng 170 s, Đầm 150 s); không có ở thử thách.
- 10 s; cứ 0,6 s một vòng đỏ (bán kính 36) trong 150 px quanh người chơi, rơi sau 1,2 s; tối đa 4 vòng, **không chồng
  nhau**. Trúng người chơi 12 (trừ giáp, khiên chặn được), trúng quái 80. Số liệu `run_config.json` events.meteor.
- Vẽ: vòng đỏ dẹt, đĩa trong lớn dần khi sắp rơi; viên đá có đuôi lửa rơi chéo từ trên phải xuống đúng vòng; nổ cam
  lõi trắng 0,4 s. Câu báo "Mưa thiên thạch! Tránh các vòng đỏ". Cờ chụp `--meteor-at=<giây>`.
- Test: `tests/unit/run/meteor_shower_test.gd`.

## Còn lại

Rương vàng hiếm.
