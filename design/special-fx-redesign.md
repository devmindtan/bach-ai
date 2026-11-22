# Kế hoạch: vẽ lại hiệu ứng của thẻ đặc biệt (chuyển từ vật phẩm)

Trạng thái: **kế hoạch** (2026-11-22). Người dùng: hiệu ứng của các kỹ năng chuyển từ vật phẩm "chưa được thiết
kế lại", trừ khiên (Thần hộ: giáp ảo, Bàn thạch: vỏ đá giữ nguyên).

## 1. Hiện trạng (đã xem preview của 10 sprite)

Cả 10 cùng một lỗi: **vòng chấm 1 px** mảnh và thưa, mật độ thường (không `px_scale` 0,5), không pha mở đầu /
bùng / đọng / tan. `retaliate-shock` còn là đám chấm lốm đốm (dither), cùng lỗi với hiệu ứng cháy cũ (LESSONS
2026-11-20). Trên nền cỏ, gần như không thấy.

| Thẻ | Kiểu | Sprite | Vấn đề cụ thể |
|---|---|---|---|
| Phản chấn | retaliate | `retaliate-shock` | đám chấm lốm đốm, không thấy cú chấn |
| Huyết quyền | kill_proc (hồi máu) | `ward-heal` | dấu cộng xanh phẳng, không ra "hút máu" |
| Phong hành | hit_buff (tốc độ) | `ward-wind` | xoáy chấm mờ |
| Thánh kiếm | pulse (vòng kiếm) | `ward-pulse` | vòng chấm vàng, không thấy kiếm |
| Lôi ấn | chain_shock | `ward-shock` | đường chấm, không ra tia sét |
| Tim bất diệt | revive | `ward-revive` | tim viền chấm |
| Hoả y | burn_aura | `ward-burn` | vạch lửa rời rạc |
| Băng ấn | freeze_nova | `ward-freeze` | vòng chấm có gai |
| Lưu tinh | kill_proc (tốc độ) | `ward-haste` | vệt chấm xoáy |
| Vĩnh cửu | reset_cd | `ward-reset` | mặt đồng hồ chấm |

## 2. Chuẩn chung (theo `fx_craft` và skill `pixel-sprite`)

- Mật độ gấp đôi (`px_scale` 0,5), dùng `sprite-lab/lib/fxkit.py`: khối có mặt sáng/tối và viền tối, chớp sáng +
  tia khi bùng, hạt có vệt, lấp lánh 4 cánh.
- Có pha: mở đầu → bùng → đọng → tan (≥ 12 frame với hiệu ứng một lần; vòng lặp cho hào quang liên tục).
- **Không lớp phủ vùng, không dither** (quy tắc 2026-11-21).
- Mỗi hiệu ứng một màu chủ đạo riêng, đọc được trên ba nền vùng (cỏ, rừng, đầm).
- Tham khảo trước khi vẽ (`art-reference`): hiệu ứng proc của Vampire Survivors, Halls of Torment; ghi 3 dòng
  học / tránh / quyết định vào mục 4.

## 3. Thiết kế từng hiệu ứng

| Thẻ | Thiết kế mới |
|---|---|
| Phản chấn | Vòng chấn đá-vàng dày bật ra từ chân (2 dải sáng/tối), mảnh đá văng, chớp trắng lúc chạm |
| Huyết quyền | Giọt máu đỏ bay từ quái về người, gom thành nắm đấm đỏ sáng rồi toả dấu cộng |
| Phong hành | 3 dải gió xanh ngọc cuộn quanh chân, lá/vệt gió bay ra sau |
| Thánh kiếm | 6 thanh kiếm sáng (hình kiếm thật, 45°) xoay một vòng quanh người rồi tan thành tia |
| Lôi ấn | Ấn sét trên đầu chớp, tia sét gấp khúc (`boltfx.thin_bolt`) bắn tới quái |
| Tim bất diệt | Tim lửa hồng đặc vỡ ra, cột sáng hồi sinh ngắn, lông vũ trắng rơi |
| Hoả y | Vòng lửa thấp (ngọn lửa đặc 2–3 tầng màu) liếm quanh chân, lặp |
| Băng ấn | Pha lê băng mọc lên quanh người (`fk.crystal`) rồi vỡ thành mảnh |
| Lưu tinh | Sao băng nhỏ bay xoáy quanh người, vệt đuôi vàng |
| Vĩnh cửu | Đồng hồ cát sáng xoay, cát vàng chảy rồi nổ thành vòng sáng |

## 4. Tham khảo

(Điền khi làm H1: nguồn, học, tránh, quyết định.)

## 5. Các bước (mỗi bước = một hiệu ứng, một commit ở mỗi repo)

H1 Phản chấn → H2 Thánh kiếm → H3 Lôi ấn → H4 Hoả y → H5 Băng ấn → H6 Huyết quyền → H7 Phong hành → H8 Lưu tinh →
H9 Tim bất diệt → H10 Vĩnh cửu. Mỗi bước:
1. Vẽ trong Sprite Lab (2–3 phương án nếu là hình mới hẳn, theo quy tắc chọn phương án).
2. `art run` → xem preview; `art shot sheet`; `art test`.
3. Promote.
4. Kiểm trong game: `gamekit test`, rồi shot có thẻ đó (`--cards`/`--skills` + kích hoạt) và xem ảnh ×2.
