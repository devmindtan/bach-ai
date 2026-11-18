# Tiền tố quái tinh anh (đợt 6A, 2026-11-18)

Dữ liệu `assets/data/run_config.json` → `elite.affixes`; code `src/run/enemies.gd` (`affix`, `_affix_def`,
`affix_label`); vẽ trong `src/run/run.gd` (viền màu + tên trên đầu, tên vẽ sau cùng). Test
`tests/unit/run/elite_affix_test.gd`.

## Tham khảo

| Nguồn | Điều lấy |
|---|---|
| [Maxroll: Diablo 4 elite affixes](https://maxroll.gg/d4/resources/elites-affixes), [Diablo 3](https://maxroll.gg/d3/resources/elite-affixes) | Tinh anh mang tiền tố; số tiền tố tăng theo độ khó; hiệu ứng khi chết (nổ, để lại vùng). |
| [Path of Exile: monster modifiers](https://pathofexile.fandom.com/wiki/Monster_modifiers) | Quái thường 1 tiền tố, hiếm 3; tiền tố kích hoạt khi chết. |
| [Risk of Rain 2: EliteReworks](https://thunderstore.io/package/Moffein/EliteReworks/0.1.7/) | Loại tinh anh phải nhìn là nhận ra (bản mod sửa đúng lỗi khó phân biệt). |

**Học / tránh / quyết định:** học cách tiền tố tạo biến thể mà không cần vẽ quái mới; tránh tiền tố khó đọc;
quyết định mỗi tinh anh 1 tiền tố (sau có thể tăng theo vùng), màu viền + tên tiếng Việt trên đầu.

| Tiền tố | Màu | Hiệu ứng |
|---|---|---|
| Nhanh | xanh lam | tốc độ ×1,6 |
| Giáp | bạc | nhận 55% sát thương |
| Phân thân | xanh lá | chết thì tách 3 con thường cùng loài |
| Bùng nổ | cam | chết thì vòng cảnh báo 0,8 s rồi nổ (bán kính 72, ×1,5 sát thương chạm) |
