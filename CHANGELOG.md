# Changelog

All notable changes to this project will be documented in this file.

## [2025-01-18] Jensen中心線フィット修正

### 🔧 Fixed
- **Jensen中心線フィットの根本的な問題を修正**
  - 問題: ポーラスディスク抵抗パラメータC（10〜22）を推力係数Ct（0〜1）として誤用
  - 影響: 全31ケースで残差が閾値の15〜20倍、kw推定が失敗
  - 解決策: 2パラメータフィット `[kw, Ct_eff]` によるデータ駆動アプローチ

### ✨ Added
- **新しいCt_effパラメータ**
  - 有効推力係数（Effective Thrust Coefficient）を追加
  - CFDデータから経験的に推定（範囲: 0.308〜0.646）
  - CとCt_effに明確な正の相関を確認

### 📈 Improved
- **フィット精度の劇的改善**
  - 平均残差: 0.732 → 0.003（**99.6%改善**）
  - 最大残差: 0.868 → 0.011（**98.8%改善**）
  - 外れ値: 31/31 → 0/31（**完全解消**）

### 📝 Changed
- `src/fit_gaussian_wake.jl`
  - `fit_jensen_gradient` 関数: 1パラメータ → 2パラメータフィット
  - 返り値に `Ct_eff` を追加
  - ログ出力にCt_eff値を表示

- `fit_coefficients_summary.csv`
  - カラム数: 22 → 23
  - 新カラム: `Ct_eff`（13列目）
  - 全31ケースで `kw_outlier = false` を達成

### 📊 Results
```
パラメータ  | 範囲           | 物理的解釈
------------|----------------|--------------------------------------------------
kw          | 0〜0.04        | 高I領域で増加、低I領域でほぼ0
Ct_eff      | 0.31〜0.65     | Cと正の相関（C=10→0.35、C=22→0.56）
km          | 0.003〜0.022   | Iとともに顕著に増加（乱流拡散）
```

### 🎯 Impact
- **フェーズ1完了**: データ整備とパラメータ抽出が成功
- **フェーズ2準備完了**: 係数回帰モデル更新の準備が整った
- **データ品質向上**: 全ケースで信頼性の高いパラメータを取得

### 🔗 Related Files
- `src/fit_gaussian_wake.jl` - 主要な修正
- `fit_coefficients_summary.csv` - 新しいデータ出力
- `JensenBastankhah_Plan.md` - 作業ログと次ステップ
- `FigGaussPD.md` - 出力仕様の更新

---

## [Previous] 初期実装

### Added
- Jensen + Bastankhah 二領域モデルの基礎実装
- `kw`, `sigmaJ0`, `sigmaG0`, `km`, `x_shift` パラメータの抽出
- 外れ値検出機能（しきい値: kw=0.04, km=0.02）

### Known Issues
- Jensen中心線フィットで全ケースが外れ値
- kwが初期値0.05のまま固定される問題
- → **2025-01-18に解決済み**
