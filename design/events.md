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

## Còn lại

Vòng thử thách (đứng trong vòng N giây nhận rương), mưa thiên thạch có báo, rương vàng hiếm.
