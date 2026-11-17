# Trạng thái lên quái (debuff)

Trạng thái: **có trong game** (2026-11-17). Dữ liệu: `assets/data/statuses.json` (tên, sprite, vị trí vẽ, màu
phủ) và `skills.<id>.on_hit` trong `upgrades_<class>.json` (trạng thái nào, từ cấp mấy, con số). Code:
`Enemies.apply_status` (test: `tests/unit/run/enemy_status_test.gd`).

| Trạng thái | Tác dụng | Vẽ |
|---|---|---|
| Làm chậm | tốc độ × `mul` trong `time` s | vệt xanh dưới chân + phủ xanh |
| Choáng | đứng yên, không gây sát thương khi chạm | sao quay trên đầu |
| Đóng băng | như choáng | tinh thể băng trên thân + phủ băng |
| Chảy máu | mỗi 0,5 s mất `dps_mul` × sát thương đòn gây ra, tính cho chiêu đó | giọt máu |
| Bỏng | như chảy máu (cộng riêng) | lửa nhỏ + phủ cam |
| Giật điện | lan ngay sang `chain` quái gần nhất trong `radius`, mỗi con `mul` × sát thương | tia điện + tia lửa |

Áp lại thì giữ thời gian dài hơn và tác dụng mạnh hơn, không cộng dồn.

## Kiếm sĩ

| Chiêu | Gây ra |
|---|---|
| Chém kiếm | cấp 4: chảy máu 2 s (15%/s) |
| Lốc xoáy | cấp 3: làm chậm ×0,6 trong 1 s |
| Đất nứt | làm chậm ×0,5 trong 1,5 s; cấp 4: choáng 0,5 s |
| Dậm đất | cấp 3: choáng 0,6 s |
| Sóng kiếm | chảy máu 3 s (20%/s) |
| Cột thánh quang | cấp 2: bỏng 2 s (25%/s) |
| Lướt | cấp 3: choáng 0,4 s |

Cấp thêm trạng thái là một **mốc** trên thẻ lên cấp ("Thêm: Choáng"). Bảng Nhân vật hiện trạng thái của mỗi
chiêu; dashboard có nhóm "Debuff lên quái" ở tab Hiệu ứng và cột trạng thái theo cấp ở tab Kỹ năng.

## Tiếp theo

- Pháp sư: đóng băng (Frost Nova), giật điện (chiêu sét), bỏng (cầu lửa).
- Quái kháng trạng thái (boss miễn choáng, quái lửa miễn bỏng): trường `resist` trong `monsters.json`.
- Thẻ tác động lên trạng thái: "+thời gian trạng thái", "chảy máu cộng dồn".
- Icon trạng thái riêng trong `ui-icons` (icon hiện tại lấy từ frame đầu sprite, hơi nhỏ).
