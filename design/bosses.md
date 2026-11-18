# Boss từng vùng

Mỗi vùng có boss riêng ở ải boss (ải 10/20/30), 2–3 đòn **có báo trước**, đổi pha ở 50% máu (kế hoạch 6A,
`production/upgrade-plan.md`).

## Tham khảo

| Nguồn | Điều lấy |
|---|---|
| Path of Exile 2, Rotten Druid ([hướng dẫn boss, GamerGuides](https://gamerguides.com/path-of-exile-2/guide/campaign/act-1/the-mysterious-shade-the-rotten-druid-boss-guide)) | Boss cây gọi rễ: rễ trồi lên **sát chỗ người chơi**, nối tiếp nhau; đòn mới thêm khi máu xuống. |
| Elden Ring, Scadutree Avatar ([Fextralife](https://eldenring.wiki.fextralife.com/Scadutree+Avatar)) | Pha 2 hung hãn hơn; **vòng sáng trên mặt đất báo trước** chỗ cành gai đâm lên. |
| Vua Thạch Nhầy của mình (`design/elite-affixes.md`, đợt 6A) | Pha 2 ở 50%: ửng đỏ + "nổi giận!", đòn dày hơn. |

**Học:** đòn vùng luôn có vòng báo, rễ nhắm vào chỗ người chơi đang đứng nên phải di chuyển. **Tránh:** rễ trồi
không báo, hoặc phủ kín màn (phải còn đường né). **Quyết định:** vòng báo 0,9 s rồi rễ đâm; một rễ nhắm đúng chỗ
đứng, các rễ còn lại rải trong 110 px.

## Mộc Yêu (Rừng Âm U, ải 20) · `tree_boss`, hành vi `boss_tree`

| Đòn | Pha 1 | Pha 2 (≤ 50% máu) |
|---|---|---|
| Rễ trồi: vòng nâu rêu 0,9 s → rễ đâm (30 sát thương, bán kính 30) | 3 rễ mỗi 3,2 s | 6 rễ mỗi 2,0 s |
| Gọi rừng: sói + 2 Ma Trơi quanh boss | mỗi 11 s | như pha 1 |
| Chạm thân | 20 | 20 |

Sprite: `tree-boss` (48×48), rễ `tree-roots` (`root_sprite`). Code: `Enemies._boss_tree`, `_add_blast(root=true)`;
vẽ trong `run.gd` (vòng báo rễ, `roots_done`). Test: `tests/unit/run/boss_tree_test.gd`.
