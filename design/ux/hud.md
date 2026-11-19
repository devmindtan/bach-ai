# HUD trong trận

Code: `src/run/run_hud.gd` (vẽ từ trạng thái trận, không giữ trạng thái gameplay). Kế hoạch: 6D.1.

## Tham khảo

| Nguồn | Điều lấy |
|---|---|
| Mũi tên mép màn ([Tuts+: indicators for off-screen targets](https://code.tutsplus.com/positioning-on-screen-indicators-to-point-to-off-screen-targets--gamedev-6644t), [Construct: offscreen enemy indicators](https://www.construct.net/en/tutorials/offscreen-enemy-indicators-208/page-3), [Starship Survivors: edge-arrow HUD](https://starship-survivors-wiki.pages.dev/gameplay/concepts/edge-arrow-hud), [Warframe forum](https://forums.warframe.com/topic/330565-archwing-suggestion-off-screen-target-indicator)) | Đặt mũi tên nơi hướng từ người chơi tới mục tiêu cắt mép màn; chừa mép và **không đè HUD**; mục tiêu càng gần càng đậm/to. |
| Thanh máu boss có vệt sát thương trễ ([Calamity Mod: Boss Health Bar](https://calamitymod.wiki.gg/wiki/Boss_Health_Bar), [Abratabia: health bars](https://www.abratabia.com/game-ui-design/health-bars-indicators.php), [Darkstalkers 3 HUD](https://srk.shib.live/w/Darkstalkers_3/HUD)) | Thanh chính tụt ngay; vệt sáng giữ phần vừa mất ~0,5 s rồi co lại theo; thanh chia đoạn cho các pha. |

**Học:** mục tiêu ngoài màn phải chỉ được; sát thương vừa gây phải thấy. **Tránh:** mũi tên đè thanh máu / thanh chiêu;
mũi tên tam giác đều (ở 1x không biết chỉ hướng nào: lỗi ở lần chụp đầu); tên boss chìm vào đám quái.

## Bố cục

- Trên: thanh kinh nghiệm; cấp, máu, nội tại; đồng hồ; số quái hạ, vàng, nút cài đặt.
- **Thanh máu boss** dưới đồng hồ khi có boss: nền tối sau tên + thanh; thanh 520 px, vạch chia 25/50/75%, **vệt hồng
  nhạt** giữ phần máu vừa mất 0,5 s rồi co lại; **vạch vàng** ở ngưỡng nổi giận (`rage_at`); số % bên phải; chữ
  **NỔI GIẬN** đỏ bên trái khi boss nổi giận.
- **Mũi tên mép màn**: boss ngoài màn: mũi tên đỏ to + đầu lâu; tinh anh ngoài màn: mũi tên vàng (6 con gần nhất).
  Mũi tên dài, có khấc đuôi và viền tối; nằm trong vùng chừa 26 px mép, dưới dải trên 96 px và trên dải dưới 84 px.
  Gần (vừa ra khỏi màn): đậm và to; xa: mờ hơn.
- Dưới: thanh chiêu. Giữa trên: câu báo sự kiện / đợt quái.
- Test: `tests/unit/run/hud_pointers_test.gd` (điểm trên mép, vệt máu).
