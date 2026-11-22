# Chủng loài quái (roadmap E)

Mỗi quái thuộc một **loài**. Loài cho quái một đặc tính hành vi, cùng **hệ kháng** và **hệ yếu**. Mục tiêu (người dùng
2026-11-22): đặc tính đủ mạnh để người chơi **nghĩ khi chọn chiêu cho từng ải** (bảng "Chi tiết ải" cho biết
ải có loài nào), nhưng không chiêu nào vô dụng hẳn.

## Tham khảo

| Nguồn | Điều lấy |
|---|---|
| [Noita: damage types](https://noita.wiki.gg/wiki/Ice_damage) | mỗi quái mạnh/yếu theo hệ sát thương; đổi hệ để đánh nhanh hơn |
| [Soulstone Survivors: skill types](https://soulstone-survivors.fandom.com/wiki/Skill_Types) | chia sát thương vật lý / phép, chỉ số tăng theo từng nhóm |
| [Enshrouded: combat mechanics](https://enshrouded.wiki.gg/wiki/Combat_Mechanics) | kháng là hệ số nhân sát thương theo từng quái và từng hệ |
| [itch.io: devlog game survivor-like](https://itch.io/post/15624494) | quái yếu một số hệ, kháng một số hệ khác |
| `design/elite-affixes.md` (Diablo, PoE, RoR2) | đặc tính phải **nhìn là biết**; tránh hệ số ẩn |

**Học:** hệ số kháng/yếu theo loài khiến việc chọn chiêu có ý nghĩa.
**Tránh:** hệ số ẩn (Enshrouded) và miễn nhiễm hoàn toàn với sát thương (chiêu thành vô dụng).
**Quyết định:**
- yếu ×1,5, kháng ×0,6;
- chỉ miễn **trạng thái** (ví dụ Chảy máu), không miễn **sát thương**;
- số bay màu cam khi trúng hệ yếu, màu xám khi trúng hệ kháng;
- bảng Chi tiết ải và Album ghi loài, hệ yếu và hệ kháng.

## Hệ sát thương của chiêu (thêm `element` vào mỗi chiêu)

| Hệ | Chiêu |
|---|---|
| Vật lý | Chém kiếm, Lốc xoáy, Đất nứt, Dậm đất, Sóng kiếm, Lướt, Địa chấn, Búa thần |
| **Ánh sáng** (hệ đặc biệt) | Cột thánh quang, Thái dương xạ (chưa chốt, xem câu hỏi mở) |
| Lửa | Cầu lửa, Mưa thiên thạch |
| Băng | Băng nổ, Bão tuyết |
| Sét | Sét đánh, Giáo sấm, Bão sét |
| Phép | Tia phép |
| **Bóng tối** (hệ đặc biệt) | Cầu hư không |

Sát thương từ trạng thái tính theo hệ của trạng thái: Bỏng là lửa, Giật điện là sét, Chảy máu là vật lý, Thánh ấn là ánh sáng, Ăn mòn là bóng tối.

## Các loài

| Loài | Quái | Đặc tính | Yếu (×1,5) | Kháng (×0,6) |
|---|---|---|---|---|
| **Nhầy** | Thạch Nhầy, Vua Thạch Nhầy | Không trúng đòn 2 giây thì hồi 3% máu/giây; Bỏng chặn hồi | Lửa | Vật lý; miễn Chảy máu |
| **Thú** | Sói Rừng, Dơi | Còn dưới 30% máu thì nổi điên (+30% tốc độ); Sói cắn gây Chảy máu lên người chơi | Vật lý (Chảy máu ×1,5), Bóng tối | Băng (Làm chậm còn một nửa thời gian) |
| **Linh hồn** | Ma Trơi, Hồn Đầm | Bay xuyên vật cản và xuyên quái khác | Ánh sáng, Phép | Vật lý, Bóng tối; miễn Chảy máu |
| **Côn trùng** | Bọ Lửa | Theo đàn: có ≥ 3 con cùng loài trong 80 px thì +20% tốc độ; vỏ cứng: đòn đầu chỉ nhận 50% | Băng | Lửa |
| **Thực vật** | Nấm Phun, Mộc Yêu | Bám rễ: miễn đẩy lùi và Choáng | Lửa (Bỏng ×2 thời gian) | Sét |
| **Lưỡng cư** | Cóc Độc, Cóc Chúa | Nhảy qua vật cản; da ướt: Bỏng chỉ kéo dài nửa thời gian | Sét | Lửa |
| **Yêu tinh** | Yêu Tinh, Yêu Tinh Vàng | Loài chuẩn, không kháng không yếu (để so) | — | — |

**Boss:** giữ loài nhưng hệ số giảm một nửa (yếu ×1,25, kháng ×0,8), để boss không bị một chiêu áp đảo.

## Ảnh hưởng tới cách chơi (kiểm theo vùng)

- **Đồng cỏ** (Nhầy, Thú, Yêu tinh): kiếm sĩ đánh vật lý, mạnh với Thú nhưng yếu với Nhầy, nên cần Bỏng hoặc phép.
  Pháp sư có Cầu lửa thì dễ.
- **Rừng** (Linh hồn, Thực vật, Côn trùng, Thú): Ánh sáng/Phép diệt Linh hồn, Bóng tối đánh Thú; Lửa diệt Thực vật nhưng Côn trùng kháng
  lửa. Phải phối hai hệ.
- **Đầm** (Lưỡng cư, Linh hồn, Nhầy): Sét mạnh với Cóc; Lửa yếu đi trước Cóc nhưng vẫn mạnh với Nhầy.

## Hai hệ đặc biệt: Ánh sáng và Bóng tối (người dùng 2026-11-22)

Hai hệ này hiếm hơn và có **trạng thái riêng**, mạnh theo kiểu khác bốn hệ nguyên tố. Ánh sáng là hệ khống chế và
bảo vệ; Bóng tối là hệ khuếch đại sát thương và lan.

| | Ánh sáng | Bóng tối |
|---|---|---|
| Trạng thái gây ra | **Thánh ấn** (2,5 giây) | **Ăn mòn** (3 giây, cộng dồn tối đa 3 tầng) |
| Hiệu ứng | quái bị chói: sát thương chạm −30%; kẻ địch Linh hồn còn bị Làm chậm 30%; hết Thánh ấn thì nổ sáng nhỏ (10% đòn gốc, bán kính 40) | mỗi tầng: quái nhận +8% sát thương từ mọi nguồn; quái chết khi có ≥ 2 tầng thì nổ bóng (bán kính 56) lan 1 tầng Ăn mòn sang quái gần |
| Mạnh với | Linh hồn (yếu ×1,5), đám đông đông, khi người chơi máu thấp | boss và tinh anh (máu dày nên tầng có thời gian phát huy), đàn quái dày |
| Yếu với | không có loài kháng, nhưng sát thương gốc thấp hơn hệ nguyên tố | Linh hồn kháng; quái máu mỏng chết trước khi tầng có tác dụng |
| Màu chủ đạo | trắng ngà, vàng nhạt (`f6e7b0`, `fff6d8`) | tím than, đen (`3a1f4f`, `7a3fa8`), viền tím sáng |
| Hiệu ứng nhìn | **Thánh ấn**: dấu thánh 4 cánh nhỏ trên đầu quái, nhấp nháy chậm; nổ sáng: vòng tia sáng tròn đặc, 8 frame | **Ăn mòn**: khói tím bốc lên từ thân, số tầng là 1–3 vệt nứt tối dưới chân; nổ bóng: quả cầu tối co rồi bung thành tua, 10 frame |
| Số bay | màu vàng nhạt | màu tím |

- Các thẻ chỉ số mới (gợi ý, chốt khi làm): "Thánh lực" (+thời gian Thánh ấn), "Vực thẳm" (+1 tầng Ăn mòn tối đa).
- Vẽ trong Sprite Lab, **2–3 phương án** cho mỗi hiệu ứng (dấu Thánh ấn, nổ sáng, khói Ăn mòn, nổ bóng) để người
  dùng chọn; mật độ gấp đôi (`px_scale` 0,5), không dither (chuẩn của `design/special-fx-redesign.md`).
- Dữ liệu: `statuses.json` thêm `holy_mark` và `corrode` (tên, màu, icon); test cộng dồn, hệ số, nổ lan.

## Dữ liệu và code (E2–E4)

- `assets/data/species.json`:
  - mỗi loài có `name`, `weak` (danh sách hệ), `resist`, `immune_status`;
  - đặc tính viết như `regen`, `enrage`, `phase`, `swarm`, `shell`, `rooted`, `hop_over`, `wet`;
  - `mul_weak` 1,5, `mul_resist` 0,6, `boss_scale` 0,5.
- `monsters.json` thêm `species`; `upgrades_*.json` thêm `element` cho mỗi chiêu.
- Test:
  - mọi quái có loài hợp lệ, mọi chiêu có hệ hợp lệ;
  - hệ số yếu/kháng nhân đúng, kể cả với boss;
  - mỗi đặc tính có test riêng.
- E3: mỗi đặc tính một commit, theo thứ tự:
  1. hệ số yếu/kháng và số bay màu;
  2. miễn trạng thái;
  3. Linh hồn bay xuyên;
  4. Nhầy hồi máu;
  5. Thú nổi điên và chảy máu;
  6. Côn trùng theo đàn và vỏ cứng;
  7. Thực vật bám rễ;
  8. Lưỡng cư nhảy qua vật cản và da ướt.
- E4: bảng Chi tiết ải và Album ghi loài, hệ yếu và hệ kháng.
- E5: Ánh sáng: trạng thái Thánh ấn, phương án hiệu ứng, áp vào Cột thánh quang.
- E6: Bóng tối: trạng thái Ăn mòn, phương án hiệu ứng, áp vào Cầu hư không.

## Câu hỏi mở

- Thái dương xạ thuộc Ánh sáng hay Lửa?
