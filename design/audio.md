# Âm thanh

Người dùng 2026-11-18: game cần âm thanh để "hình thành được game"; chưa cần đẹp, cần đủ.
Nguồn: **tự tổng hợp bằng code** (`gamekit audio`, `tools/gamekit/pipeline/soundkit.py`), không dùng file tải về,
nên không có vấn đề giấy phép và luôn tạo lại được. Người chỉnh âm thanh sửa JSON rồi chạy lại lệnh.

- Nguồn âm: `assets/source/audio/sfx.json` (hiệu ứng kiểu sfxr), `assets/source/audio/music.json` (nhạc nền dạng
  tracker: nốt theo bước).
- File sinh ra: `assets/audio/sfx/*.wav`, `assets/audio/music/*.wav`; ảnh dạng sóng để soát:
  `production/audio/review.png` + `review.txt` (độ dài, đỉnh, rms).
- Sự kiện nào phát tiếng gì: `assets/data/audio.json`. Code: `src/audio/sound.gd` (autoload `Sound`).
- Nghe thử một tiếng: `gamekit audio bach-ai --only <id> --play <id>`.
- Kiểm trong trận: cờ `--sound-log=<file>` ghi số lần mỗi tiếng đã phát khi thoát (bằng chứng:
  `production/qa/evidence/audio/`). Khi chụp ảnh / chạy test (chế độ cố định) bus Master bị tắt tiếng.

## Tham khảo

| Nguồn | Điều lấy |
|---|---|
| [sfxr.me / jsfxr](https://sfxr.me), [pyfxr: generating sounds](https://pyfxr.readthedocs.io/en/stable/generating.html) | Bộ tham số kiểu sfxr (dạng sóng, trượt cao độ, bao âm attack/sustain/decay/punch, arpeggio, lọc) và các mẫu quen thuộc: nhặt xu, bắn, nổ, lên cấp, trúng đòn, chọn menu. Sound của mình theo đúng các họ này. |
| [itch.io: giới hạn số tiếng cùng lúc](https://itch.io/post/9991212) | Game nhiều đối tượng: mỗi tiếng có số "giọng" tối đa, hết giọng thì bỏ qua, không chồng thêm. |
| [itch.io: tiếng trúng đòn phát hàng chục lần/giây](https://itch.io/post/6856787) | Tiếng trúng đòn/giết quái phải nhẹ, ngắn, không "đấm" tai; tiếng quan trọng (lên cấp, boss, thắng) mới nổi bật. |
| Vampire Survivors (chơi thể loại) | Nhạc nền chạy suốt trận, lên cấp / mở rương có tiếng riêng dễ nhận; nhặt ngọc là tiếng nhỏ, cao. |

**Học / tránh / quyết định:** học bộ tham số sfxr và giới hạn giọng; tránh để tiếng trúng đòn chồng lên nhau thành
tiếng ồn (đã có người chơi chê "quá ồn" ở game cùng thể loại); quyết định: mỗi sự kiện có `voices` (số giọng) và
`gap` (khoảng cách tối thiểu giữa hai lần phát), cao độ lệch ngẫu nhiên nhỏ để tiếng lặp không đơn điệu, nhặt ngọc
liên tiếp tăng dần cao độ.

## Âm lượng

Hai bus: **Nhạc** và **Hiệu ứng**, chỉnh trong Cài đặt (0–100%, bước 20%; mặc định nhạc 60%, hiệu ứng 80%).

## Danh sách

| Nhóm | Sự kiện → tiếng |
|---|---|
| Giao diện | bấm nút → `ui_click`; bắt đầu trận → `ui_start` |
| Trận | trúng quái → `hit`; quái chết → `kill`; nhặt ngọc → `gem` (cao dần khi nhặt liên tiếp); vàng → `coin`; Tinh hoa → `essence`; rương → `chest`; bị đánh → `hurt`; lướt → `dash`; lên cấp → `level_up`; chọn thẻ → `card_pick`; mốc 10/20/30 → `milestone`; boss xuất hiện → `boss_spawn`; boss dậm → `boss_slam`; thắng → `win`; thua → `lose` |
| Chiêu | Chém kiếm, Chém ngược → `slash`; Lốc xoáy → `whirl`; Đất nứt, Dậm đất, Địa chấn, Búa thần → `quake`; Sóng kiếm → `wave`; Cột thánh quang, Thái dương xạ → `holy`; Tia phép, Cầu hư không → `bolt`; Cầu lửa, Mưa thiên thạch → `fire`; Băng nổ, Bão tuyết → `frost`; Sét đánh, Giáo sấm, Bão sét → `zap`; Lướt → `dash` |
| Ngoài trận | quay gacha → `gacha_pull`; ra sử thi → `gacha_epic`; ra huyền thoại → `gacha_legend`; cường hoá → `enhance`; mua node / mặc đồ → `buy` |
| Nhạc | màn đầu, sảnh, các màn ngoài trận → `menu`; trong trận → `run`; khi boss có mặt → `boss` |

## Kiểm thử

- `gamekit audio test`: bộ tổng hợp tất định, chuẩn hoá đỉnh, từ chối tiếng vỡ (clipping), tiếng gần như câm,
  hiệu ứng dài quá 2,5 giây.
- `tests/unit/audio/sound_test.gd`: mọi id trong `audio.json` có file `.wav`; giới hạn giọng và `gap`; âm lượng
  0% tắt bus; tiếng không có thì bỏ qua (không lỗi).
- Nghe bằng tai là việc của người: agent chỉ xem được dạng sóng và số đo.
