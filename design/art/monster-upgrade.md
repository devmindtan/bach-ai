# Nâng cấp ngoại hình quái (đợt 6A+)

Người dùng 2026-11-18: sói, ma trơi, nấm phun... cần "trông mạnh mẽ và dữ dằn hơn", cả ngoại hình lẫn hiệu
ứng. **Thạch nhầy (`slime`) giữ nguyên.** Làm từng con một (vẽ trong Sprite Lab → xem ảnh → promote → chụp
trong trận → commit), con này duyệt xong mới sang con sau.

## Tham khảo

| Nguồn | Điều lấy |
|---|---|
| [Bugnet: how to design a readable enemy](https://bugnet.io/blog/how-to-design-a-readable-enemy-design), [readable game art](https://bugnet.io/blog/readable-game-art-why-clarity-beats-detail) | Ngoại hình phải **nói lên mức nguy hiểm**; mỗi loài phân biệt được chỉ bằng bóng đen. |
| [Alain Galvan: pixel art design for game dev](https://alaingalvan.medium.com/pixel-art-design-for-game-dev-32d22c83a296) | **Phóng đại đặc điểm chính** tới mức không thể nhầm (nanh, gai, sừng). |
| [Free Game Sprites: silhouette test](https://freegamesprites.com/es/news/sprite-silhouette-test-character-readability) | Kiểm tra bóng đen: tô đen sprite mà vẫn nhận ra. |
| [SLYNYRD Pixelblog 36](https://www.slynyrd.com/blog/2022/1/25/pixelblog-36-8-bit-adventure) | Viền đậm quanh điểm nhấn, ít màu nhưng tương phản mạnh. |

**Học:** dữ dằn = **bóng có góc nhọn** (gai, nanh, móng, sừng), **mắt phát sáng màu nóng** (đỏ/vàng) trên mặt tối,
**miệng/nanh lộ**, tư thế **chồm tới trước**, màu tối hơn với một điểm nhấn rực. **Tránh:** dáng tròn hiền
(chỉ thạch nhầy được tròn), mắt chấm trắng ngây thơ, màu nhạt đều. **Quyết định:** mỗi con có một "điểm dữ"
riêng (bảng dưới) và một hiệu ứng mạnh hơn cho đòn của nó; khung có thể lớn hơn (≤ 40 px) để đủ chi tiết.

## Từng con

| Quái | Hiện tại | Nâng cấp ngoại hình | Hiệu ứng |
|---|---|---|---|
| Sói Rừng `wolf` | sói xám gầy, hiền | lông dựng gai dọc sống lưng, nanh trắng lộ, miệng đỏ, **mắt đỏ phát sáng**, sẹo, móng; chồm thấp đầu ra trước; khung 40×28 | gồng: mắt lóe + vệt sáng mắt kéo theo khi lao |
| Ma Trơi `wisp` | đốm lửa xanh mắt chấm | lửa ma dữ: hốc mắt đen hình chữ V, miệng ngoác răng lửa, lưỡi lửa nhọn như sừng, đuôi lửa xé | để lại vệt lửa ma khi lượn |
| Nấm Phun `spore` | nấm tròn | mũ nấm có gai và đốm độc, mặt hung (mắt vàng, miệng có răng) dưới mũ, rễ như móng bám đất | đạn bào tử có vệt độc; lúc nạp mũ nấm phồng sáng |
| Bọ Lửa `ember-beetle` | bọ đen bụng cam | vỏ giáp gai, sừng kẹp trước đầu, bụng dung nham nứt, chân nhọn | vòng báo nổ có tia lửa; nổ to hơn |
| Dơi `bat` | dơi tím | cánh rách có móng ở khớp, tai nhọn dài, nanh, mắt đỏ | — |
| Yêu tinh `goblin` | yêu tinh cầm dao | mặt nhe răng, tai rách, giáp vụn, dao răng cưa, mắt vàng | gồng: dao lóe |
| Hồn Đầm `bog-spirit` | bóng ma rêu | mặt nạ xương dưới mũ trùm, mắt lục rực, móng dài cầm đèn, áo rách tua | vòng hồi máu có sóng xoáy |
| Vua Thạch Nhầy `king-slime` | (đã làm trước) | để sau cùng, thêm animation nhảy `crouch`/`jump` (luật mới) | |

Thứ tự làm: sói → ma trơi → nấm phun → bọ lửa → dơi → yêu tinh → hồn đầm → vua thạch nhầy.
