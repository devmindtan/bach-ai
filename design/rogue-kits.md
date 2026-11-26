# Bộ chiêu mới cho Cung thủ và Sát thủ (bản 2)

Người dùng 2026-11-26: bộ chiêu bản 1 "còn đơn điệu và chưa có gì đặc biệt so với 2 class trước": hầu hết chỉ là
mũi tên / con dao bay với hệ khác. Yêu cầu: tự do phát triển, đa dạng (không phải chiêu nào cũng là bắn cung hay
ném dao), mỗi chiêu có **5 bậc hình (I–V)** như Kiếm sĩ và Pháp sư.

## Tham khảo

- Vampire Survivors, Runetracer: đạn nảy giữa các mục tiêu → **Tên nảy**.
- Lost Ark, Sharpshooter: chim đồng hành cùng chiến đấu (https://maxroll.gg/lost-ark/build-guides/sharpshooter-pvp-guide)
  → **Chim ưng đồng hành** thường trực, không phải một hiệu ứng nổ.
- Project R.I.S.E, Archer "Longshot": sát thương tăng theo khoảng cách
  (https://mobalytics.gg/gamebase/guides/project-rise-archer-overview) → **Phát bắn tích lực** (gắn với Mắt ưng).
- Guildrun, sát thủ Yuuna: lách vào hạ con yếu máu (https://mobalytics.gg/gamebase/guides/guildrun-how-to-play-assassin)
  → **Kết liễu**.
- Brotato, Knife: lối chơi chí mạng (đã ghi ở design/assassin.md) → **Chuỗi liên hoàn**.

Tránh: thêm chiêu chỉ khác màu / hệ của cùng một mũi tên (lỗi của bản 1).

## Cung thủ: thợ săn (10 chiêu)

| id | Tên | Cơ chế riêng | Trạng thái |
|---|---|---|---|
| quick_arrow | Tên nhanh | chiêu khởi đầu | có |
| ricochet | Tên nảy | trúng quái thì nảy sang quái kế bên 2–5 lần, mỗi lần +10% sát thương | mới |
| arrow_rain | Mưa tên | rơi xuống chỗ quái đông | có (thêm 5 bậc) |
| thorn_trap | Bẫy gai | đặt bẫy nằm chờ trên đất; quái giẫm vào thì gai bật, trói + chảy máu | đổi |
| hawk | Chim ưng | chim bay theo người suốt trận, tự lao vào quái máu cao nhất | đổi |
| charged_shot | Tên tích lực | đứng yên càng lâu mũi tên kế tiếp càng to, xuyên nhiều | mới |
| hunter_mark | Đánh dấu | dấu lên quái mạnh nhất: mọi đòn vào nó +40%; nó chết thì dấu nhảy sang con khác | mới |
| net_shot | Lưới | bắn lưới bung ra trói cả đám quái | mới |
| fire_arrow | Tên lửa | nổ, bỏng | có (thêm 5 bậc) |
| dash | Lướt | dùng chung | có |

Bỏ: Tên xuyên, Quạt tên, Tên băng, Tên sét (chỉ là mũi tên đổi hệ).

## Sát thủ: bóng tối (10 chiêu)

| id | Tên | Cơ chế riêng | Trạng thái |
|---|---|---|---|
| throw_knife | Phi đao | chiêu khởi đầu, ném dao tầm gần | có |
| boomerang | Dao hồi | dao bay ra rồi quay về tay, trúng cả lượt đi và về | mới |
| smoke_bomb | Bom khói | khói quanh người: chậm, choáng | có (thêm 5 bậc) |
| blade_orbit | Lốc dao | dao xoay quanh người liên tục trong vài giây | đổi (thay Vòng dao) |
| shadow_strike | Ám kích | dịch chuyển ra sau lưng quái gần nhất, chém chéo | đổi |
| execute | Kết liễu | đòn trúng quái thường dưới 15% máu thì giết luôn; hạ kiểu này thì hồi Lướt | mới |
| shadow_clone | Phân thân | bóng ảnh đứng chỗ vừa Lướt, lặp lại chiêu của bạn trong 4 giây | mới |
| combo | Liên hoàn | mỗi đòn trúng trong 2 giây +1 tầng (tối đa 10), mỗi tầng +3% chí mạng | mới |
| poison_cloud | Độc vụ | vũng độc trên đất ăn mòn quái đứng trong đó | mới |
| dash | Lướt | dùng chung | có |

Bỏ: Quạt dao, Dao xuyên, Dao rạch, Dao độc, Dao lửa (đều là dao bay đổi hệ).

## Thứ tự làm (mỗi chiêu một commit: code + test fail trước + 5 bậc hình + ảnh)

1. Tên nảy. 2. Dao hồi. 3. Chim ưng đồng hành. 4. Lốc dao. 5. Kết liễu. 6. Liên hoàn. 7. Bẫy gai nằm chờ.
8. Đánh dấu. 9. Tên tích lực. 10. Phân thân. 11. Lưới, Độc vụ. 12. 5 bậc hình cho các chiêu giữ lại. 13. Gỡ chiêu bỏ.
