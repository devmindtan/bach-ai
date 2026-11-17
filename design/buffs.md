# Buff tạm thời (vật phẩm nhặt trong ải)

Trạng thái: **đợt A đã có trong game + tái thiết kế 2026-11-17**. Dữ liệu: `assets/data/items.json` → `buffs`,
`assets/data/run_config.json` → `buffs`. Code: `src/run/buffs.gd` (test: `tests/unit/run/buffs_test.gd`).

## Tham khảo trước khi thiết kế

- **Wikipedia — Vampire Survivors** (genres roguelike, survivors-like, bản quyền Wikipedia/CC-BY-SA): dùng làm
  khung tham khảo chất lượng mà không sao chép pixel. Game dùng hệ thống relic (buff lâu dài) và floor chicken
  (rơi giữa trận, hồi máu) + treasure chest (rơi lớn khi quái mạnh chết) — phân biệt rõ **con đường kinh tế ngắn
  hạn** (rơi nhặt ngay) vs **con đường tích luỹ dài hạn** (giữa trận → quay/lên cấp → active). Không có wiki
  công khai dễ tiếp cận ở môi trường sandbox (403/401), nên bám vào thông tin công khai + Wikipedia.
- **Kenney CC0**: hiệu ứng và item theo công-phá-cỡ — tham quan loại particle, nhịp burst→fade (không chép hình).
- **Thực tế rào cản access**: chỉ có Wikipedia, Kenney, Lospec trả lời được qua webfetch; official wiki/forum/game wikis đều trả 403/401. Các con số dưới là quyết định cân bằng nội bộ, không sao chép số lượng.

## Nguyên lý thiết kế (sau tham khảo)

1. **Phân biệt vũ trụ và quà nâng**: ticket A small (đuổi nhặt lên người) vs ticket B large (mở rương/brain break).
   Buff nhỏ = giá trị tức thì, tần suất khoảng 25–40 s.
2. **Thang rarity**: `common < rare < epic` — màu + độ mạnh. Buff buff (skill dùng trong trận) ảnh hưởng trực tiếp
   đến sức mạnh: common < hiếm < epic (skills như ngọc power/epic nên được dành cho boss mốc).
3. **Nếu buff mới xuất hiện mà không có thu hút rõ ràng, nó vô dụng**: mọi buff phải trả lời "tại sao tôi lại nhặt
   buff này?" trong ba giây đầu nhìn. Buff yếu thường là buff hồi máu khi người chơi đang đầy máu — design mới:
   heal_bloom giờ hồi 7 (thường mạnh hơn Hoa hồi phục vì là early-game farm tool).
4. **Hiệu ứng làm đủ mỗi loại**: haste (tốc độ+cooldown), power (sát thương), heal (hồi máu), shield (bảo vệ+magnet).
   Không có buff DPS/attack khác hay debuff mới vì mở rộng cần enemy để áp — để phase sau.

## Bốn buff hiện có (đều đã rarity rõ)

| Buff | Rarity | Tác dụng | Thời gian | Vầng sáng |
|---|---|---|---|---|
| Rune tốc độ | rare | tốc độ chạy +30%, hồi chiêu −25% | 8 s | vòng rune vàng dưới chân |
| Ngọc sức mạnh | common | sát thương mọi đòn +35% | 8 s | ấn tím quanh thân |
| Hoa hồi phục | common | hồi 7 máu/giây | 6 s | hoa xanh dưới chân |
| Khiên từ | **epic** | miễn mọi sát thương, tầm hút ×2,5 | 5 s | bong bóng lục giác quanh thân |

Dù cùng loại, mật độ và lâu dài khác nhau, để người chơi đánh giá rủi ro: Khiên từ (epic) là buff rarity cao
nên hiếm và thời lượng ngắn đi — báo hiệu cho người chơi "khoảng thời gian hiếm này quý giá".

- Huy hiệu là một họ chung (`sprite-lab/lib/buffitem.py`): lục giác 18 px, khác xu (tròn) và ngọc (nhỏ).
- Buff tác động như thẻ cấp 1 (`Buffs.as_upgrades`), nên chỉ số, hồi chiêu, HUD và bảng Nhân vật đều
  thấy nó mà không cần công thức riêng. Nhặt lại buff đang chạy thì **làm mới thời gian, không cộng dồn**.
- Vầng sáng vẽ **sau** nhân vật (vẽ đè lên thì che mất người). HUD: huy hiệu nhỏ + thanh thời gian + số
  giây dưới thanh máu.

## Đợt A: xuất hiện ngẫu nhiên (đang dùng)

Lần đầu sau 15 s, rồi mỗi 25–40 s một buff ngẫu nhiên hiện trên vòng 160–300 px quanh người chơi; nằm
20 s (nhấp nháy 4 s cuối), tối đa 2 cái cùng lúc. Mọi con số ở `run_config.json` → `buffs`.

**Câu hỏi khi chơi thử:** người chơi có thấy buff và đổi hướng đi để nhặt không? Có buff nào mạnh quá
(Khiên từ nay epic 5 s, tầm hút ×2,5) hoặc vô vị (Hoa hồi phục hồi đủ 7 máu/giây)?

## Kế hoạch tiếp theo

| Đợt | Nội dung | Ghi chú |
|---|---|---|
| B | Rơi từ quái tinh anh và rương (đợt 2 roadmap) thay cho một phần xuất hiện ngẫu nhiên | tỉ lệ theo loại quái trong `monsters.json` |
| B | Trọng số theo tình huống: máu thấp thì Hoa hồi phục dễ ra hơn | giữ RNG có seed để test được |
| C | Thẻ nâng cấp tác động lên buff: "buff kéo dài +X%", "tầm nhặt buff" | thêm khóa `buff_duration` vào PlayerStats |
| C | Debuff do quái gây ra (chậm, độc, chảy máu): dùng cùng hệ thống `active` + vầng sáng | tab Hiệu ứng trên dashboard đã sẵn |
| D | Buff hiếm (viền bạc/vàng), buff riêng theo class | sau khi có Pháp sư |
