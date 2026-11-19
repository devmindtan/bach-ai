# Vật cản theo vùng (6B.1)

## Tham khảo

| Nguồn | Điều lấy |
|---|---|
| Brotato, cây và vật cản ([Brotato Wiki: Trees](https://brotato.wiki.spellsandguns.com/Trees), [Ludo: environmental hazards](https://www.ludo.guide/guide/brotato/walkthrough/environmental-hazards-benefits)) | Đá, cây nằm trên bản đồ làm chỗ che và chỗ kẹt; cây phá được để lấy đồ (để dành cho 6C.4). |
| Vampire Survivors, Inlaid Library ([games.gg: stage guide](https://games.gg/hi/vampire-crawlers-the-turbo-wildcard-from-vampire-survivors/guides/vampire-survivors-inlaid-library-complete-stage-guide/), [Destructoid: stages](https://www.destructoid.com/all-stages-and-how-to-unlock-them-in-vampire-survivors/)) | Tường và hành lang đổi cách đứng và cách kéo quái so với bãi trống. |

**Học:** vật cản thưa, rải đều, tạo đường né và góc kẹt mà không chặn hẳn. **Tránh:** vật cản ngay chỗ xuất phát;
cây che mất nhân vật; quái kẹt cứng sau vật cản. **Quyết định:**
- Mỗi vùng một kiểu vật cản cứng (`stages.json` regions[].obstacles): Đồng cỏ 45 tảng đá, Rừng Âm U 60 cây cổ thụ,
  Đầm Lầy Độc 40 cây chết. Chỉ **gốc** chặn (bán kính 9–13 px); chừa trống 220 px quanh chỗ xuất phát; cách nhau
  ≥ 100–110 px. Vị trí sinh theo seed của ải (`Obstacles`, seed = ải × 7919 + 13), nên ải nào cũng giống nhau mỗi lần chơi.
- Người chơi (bán kính chân 8) và quái bị đẩy ra khỏi gốc mỗi bước, nên trượt vòng qua thay vì kẹt cứng.
- **Vũng độc** (Đầm): 16 vũng bán kính 40, không chặn; đứng trong mất 4 máu/giây (không tính giáp, không giật lùi).
- Vẽ: vũng trên nền đất; vật cản trước nhân vật; khi nhân vật đứng sau một vật cản thì vẽ lại vật cản đó bán trong
  suốt đè lên nhân vật. Không có ở chế độ thử thách và bản đo hiệu năng (`--bench`).
- Sprite (Sprite Lab): `obstacle-rock`, `obstacle-tree`, `obstacle-deadtree`.
- Test: `tests/unit/run/obstacles_test.gd`.
