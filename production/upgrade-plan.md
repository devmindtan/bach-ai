# Kế hoạch nâng cấp (đợt 6) · 2026-11-18

Người dùng 2026-11-18: **khoá đợt 7 và 8** (hoàn thiện/Steam, mobile); xong đợt 6 cũng chưa sang 7–8 cho tới khi
người dùng ưng ý và tự mở. Đợt 6 là nơi nâng cấp giao diện, gameplay, quái vật.

## Hiện trạng (soát 2026-11-18)

| Mảng | Đang có | Điểm yếu |
|---|---|---|
| Quái | 3 loài (thạch nhầy đuổi, dơi bầy, yêu tinh lao) + tinh anh + 1 boss (Vua Thạch Nhầy) | 30 ải dùng chung một bộ quái; không có quái bắn xa, quái giữ khoảng cách, quái nổ, quái hỗ trợ; boss một kiểu |
| Bản đồ | nền ô vuông, 3 vùng khác màu | không vật cản, không sự kiện, không mục tiêu phụ; vùng chỉ khác màu |
| Gameplay | 2 class × 7 chiêu + thẻ chỉ số, mốc 10/20/30, buff nhặt, rương tinh anh | chưa có tiến hoá chiêu, chí mạng, bỏ / đổi thẻ; nhịp sóng đều, ít cao trào |
| Giao diện | màn đầu, nhân vật, sảnh, chọn ải, trang bị, cây kỹ năng, gacha, nhiệm vụ, HUD | thiếu mũi tên boss ngoài màn, thanh máu boss lớn, hiệu ứng mở thẻ / quay gacha, màn kết quả còn đơn giản |
| Meta | slot, trang bị 48 món, cường hoá, cây kỹ năng, thử thách, gacha, nhiệm vụ ngày | chưa chơi thử để cân số |

## Tham khảo

| Nguồn | Điều lấy |
|---|---|
| [LUMINARK dev journal: combat fun](https://rfa-devjournal.pages.dev/en/post/devlog-combat-fun) (về Halls of Torment) | Quái đi zig-zag, quái **giữ khoảng cách** với người chơi thay vì lao vào: đội hình có hình dạng, buộc di chuyển. |
| [Bottomfeeder: survivors-likes](https://bottomfeeder.substack.com/p/the-fast-life-and-fiery-death-of) | Lời chê phổ biến: quái thường của thể loại kém đa dạng (Robotron 1982 còn nhiều kiểu quái hơn). |
| [Insider Gaming: games like Vampire Survivors](https://insider-gaming.com/7-best-games-like-vampire-survivors/) | Soulstone Survivors được khen vì **boss đa dạng**; nhân vật khác nhau tạo chiến thuật khác nhau. |
| [nodal.gg: Halls of Torment](https://nodal.gg/game/halls-of-torment-2218750) | Mục tiêu trên bản đồ đi cùng bầy quái. |

## Đề xuất (theo thứ tự ưu tiên)

### 6A · Quái vật và nhịp trận (quan trọng nhất)
**Tiến độ (2026-11-18):** Đồng cỏ có Nấm Phun (bắn xa) và Bọ Lửa (nổ khi chết); tinh anh có 4 tiền tố
(`design/elite-affixes.md`); boss Đồng cỏ Vua Thạch Nhầy chỉ nhảy dậm, pha phẫn nộ ở 50% máu (thân đỏ + dấu tức giận, dậm dày hơn,
sóng xung kích mỗi cú dậm). Nhịp sóng có báo trước (`announce`). Rừng Âm U: Ma Trơi bay zig-zag (`zigzag`), Sói Rừng lao có dải báo (`telegraph`), boss Mộc Yêu (`design/bosses.md`; bản nhiều rễ cong gai góc 2026-11-18 **chờ người dùng duyệt**). Đầm Lầy Độc: Cóc Độc nhảy để lại vũng độc (`hop`, `pool`), Hồn Đầm hồi máu quái quanh nó (`support`), boss Cóc Chúa. **6A xong ba vùng.**
1. **Mỗi vùng 4–5 loài**, mỗi loài một hành vi rõ: bắn xa giữ khoảng cách (đạn chậm, né được), lao có báo trước,
   zig-zag, nổ khi chết (vòng báo), khiên / trâu chặn đường, phân thân, hỗ trợ (hồi máu / tăng tốc quái quanh).
2. **Tinh anh có tiền tố**: Nhanh, Giáp, Phân thân, Bùng nổ (hiện tên + màu viền).
3. **Boss riêng mỗi vùng** (3 vùng hiện có): 2–3 đòn có báo trước, đổi pha ở 50% máu.
4. **Nhịp sóng**: lặng → dồn → đợt lớn có báo ("Bầy dơi kéo tới!"), thay vì mật độ tăng đều.
   Vẽ quái mới trong Sprite Lab (pixel-sprite), mỗi loài đủ di chuyển / đòn / trúng đòn / chết.

### 6B · Bản đồ
**Tiến độ (2026-11-19):** sự kiện Yêu Tinh Vàng, Vòng thử thách, Mưa thiên thạch, Rương vàng (`design/events.md`). Còn: vật cản, nền theo vùng.
1. Vật cản và trang trí theo vùng (đá, cây, mộ, vũng độc) để có đường né và góc kẹt.
2. Sự kiện: quái vàng bỏ chạy (rơi nhiều vàng), vòng thử thách (đứng trong vòng N giây nhận rương), mưa
   thiên thạch có báo, rương vàng hiếm.
3. Nền theo vùng: ô đất khác nhau, không chỉ đổi màu.

### 6C · Gameplay
1. **Tiến hoá chiêu**: chiêu cấp tối đa + thẻ chỉ số phù hợp → bản tiến hoá (hình mới, cơ chế mới), mở trong rương.
2. **Chí mạng** + khựng hình nhẹ / rung màn (đợt 2 còn nợ).
3. **Đổi / bỏ / bỏ qua thẻ** khi lên cấp (số lượt giới hạn) để build có chủ đích.
4. **Hồi máu nhặt được** (thịt / bình) rơi từ vật cản phá được.
5. Mở rộng 100 ải (5 vùng × 20) sau khi 6A–6B ổn ở 3 vùng đầu; mô phỏng cân bằng headless.

### 6D · Giao diện và cảm giác
1. Trong trận: mũi tên chỉ boss / tinh anh ngoài màn, thanh máu boss lớn trên đỉnh màn, báo đợt quái.
2. Hiệu ứng: lật thẻ khi lên cấp, quay gacha theo độ hiếm, số sát thương chí mạng.
3. Màn kết quả: sát thương từng chiêu (biểu đồ), thời gian sống, quái hạ, phần thưởng.
4. Icon chiêu / thẻ 24 px như icon trang bị (đồng bộ, không méo).

### 6E · Class mới (sau 6A–6D)
Cung thủ, Sát thủ (roadmap đợt 6; giáp và chiêu đã có trong Sprite Lab, cần vẽ nhân vật theo lớp + đồ).

## Cần người dùng chốt
- Thứ tự: đề xuất 6A → 6B → 6D → 6C → 6E.
- Số vùng làm trước: đề xuất hoàn thiện 3 vùng hiện có (ải 1–30) trước khi mở rộng lên 100 ải.
