# Vùng đất: bản đồ và nhạc riêng

Người dùng 2026-11-18: "thiết kế bản đồ và âm nhạc các chế độ chơi còn tương đồng, chưa có sự khác biệt".
Trước đây ba vùng chỉ khác bảng màu cỏ, và mọi trận dùng chung một bài nhạc `run`.

## Tham khảo

| Nguồn | Điều lấy |
|---|---|
| Vampire Survivors ([danh sách màn, GameLeap](https://www.gameleap.com/articles/vampire-survivors-all-maps-and-how-to-unlock-them), [BlueStacks stages guide](https://www.bluestacks.com/blog/game-guides/vampire-survivors/vps-stages-guide-en.html)) | Mỗi màn (Mad Forest, Inlaid Library, Dairy Plant) có nền, vật trang trí và bài nhạc riêng, nhận ra ngay từ giây đầu; nền vẫn tối và ít chi tiết để quái và đạn nổi lên. |
| Deep Rock Galactic: Survivor ([biomes](https://bloxodes.com/wiki/deep-rock-galactic-survivor/biomes)) | Mỗi biome có màu đất, vật cản nhỏ và không khí riêng; khác biệt nằm ở **vật rải trên nền**, không chỉ đổi màu. |
| Head Hunter devlog ([music & biome progression](https://matt-burton.itch.io/head-hunter/devlog/875487/music-composition-and-biome-progression-devlog-9)) | Nhạc đổi theo biome: nhịp, âm giai và nhạc cụ nói lên không khí vùng. |

**Học:** mỗi vùng = bảng màu + bộ vật trang trí riêng + bài nhạc riêng; chế độ thử thách có nhạc riêng.
**Tránh:** vật trang trí sáng, to hoặc dày làm lẫn với quái/ngọc (nền phải tối, độ tương phản thấp).
**Quyết định:** vật trang trí vẽ bằng code (`RunGround`, theo `stages.json` `ground.props`), không chặn đường
đi; mỗi vùng và chế độ thử thách khai báo `music` (id trong `audio.json`).

## Các vùng

| Vùng | Nền | Vật trang trí | Nhạc |
|---|---|---|---|
| Đồng cỏ | cỏ xanh sáng | bụi cỏ, hoa vàng, đá nhỏ | `run`: 132 bpm, ngũ cung La thứ, vui, nhanh |
| Rừng Âm U | cỏ xanh tối | lá rụng, nấm tím, gốc cây, bóng tán cây | `run_forest`: 104 bpm, trầm, thưa, bass kéo dài |
| Đầm Lầy Độc | bùn xanh ô liu | vũng nước độc có gợn, lau sậy, bong bóng | `run_marsh`: 116 bpm, lạc điệu (nửa cung), tiếng sóng tam giác lơ lửng |
| Thử thách | nền của ải gốc | như vùng của ải gốc | `challenge`: 150 bpm, trống dồn |

Boss mọi vùng dùng chung `boss`.

## Kiểm thử

`tests/integration/data/regions_test.gd`: mỗi vùng có `music` khác nhau và có trong `audio.json` (có file `.wav`),
`ground.props` khác nhau; thử thách có `music`.
