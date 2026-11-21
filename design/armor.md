# Giáp (2026-11-21)

Người dùng 2026-11-21: "Cần thêm cơ chế giáp". Trước đó giáp chỉ **trừ phẳng** (mỗi đòn trừ N, tối thiểu 1); từ khi
thẻ chỉ số không giới hạn cấp, xếp giáp phẳng sẽ đưa mọi đòn về 1 sát thương.

## Tham khảo

| Nguồn | Điều lấy |
|---|---|
| [Brotato Wiki: Armor](https://brotato.wiki.spellsandguns.com/Armor) | Sát thương nhận = 1 / (1 + giáp/15): 15 giáp giảm 50%, 30 giáp ~67%; giáp âm làm nhận thêm ((15 − 2a)/(15 − a)). Không bao giờ miễn hẳn. |
| [Vampire Survivors: Armor (altema)](https://altema.jp/vampiresurvivors/armor) | Giáp phẳng: −1 sát thương mỗi đòn mỗi điểm — cách cũ của Bách Ải; hợp khi giáp bị giới hạn chặt. |
| [Risk of Rain Wiki: Armor](https://riskofrain.fandom.com/wiki/Armor) | Cùng dạng hyperbol (100/(100+giáp)) — dạng % giảm dần là chuẩn chung của thể loại có chỉ số không trần. |

**Học:** giáp % giảm dần thì xếp chồng không bao giờ thành bất tử, và một con số (K) chỉnh được độ mạnh.
**Tránh:** giáp phẳng với chỉ số không trần (VS chặn bằng trần cấp; Bách Ải đã bỏ trần thẻ chỉ số).
**Quyết định:** giáp theo % kiểu Brotato.

## Luật

- Sát thương nhận = `max(1, đòn × armor_mul(giáp) × damage_taken_mul)`, `armor_mul(a) = 1 / (1 + a/K)`
  (a ≥ 0), `(K − 2a)/(K − a)` (a < 0). `K = run_config.json player.armor_k` = 15.
- Áp cho mọi đòn đi qua `_take_hit` (quái chạm, đòn boss, Lốc cỏ, Cây đổ). **Không** áp cho vũng độc và Nước độc
  dâng (luật của đầm: độc xuyên giáp).
- Nguồn giáp: thẻ Da thép / Áo phép +3 mỗi cấp (~−17% ở cấp 1), trang bị, cây kỹ năng, giáp ảo Thần hộ +12 (~−44%).
- Bảng Nhân vật hiện "Giáp 6 (−29%)".

## Để sau

Xuyên giáp của quái/boss; giáp làm chỉ số scale cho chiêu (roadmap "Hệ thống scale theo chỉ số").

Test: `tests/unit/run/armor_test.gd`.
