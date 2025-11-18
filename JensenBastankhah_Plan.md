## Jensen + Bastankhah 二領域モデル 開発計画

本ドキュメントは、乱流強度 `I` とポーラスディスク抵抗 `C` を係数として組み込む Jensen（PARK）+ Bastankhah 二領域モデルを FitGauss-PD 上で実装・検証するための詳細計画である。

### 目的とゴール
- 既存のガウスフィット結果を活用しつつ、近接域では Jensen 型、遠方域では Bastankhah 型を用いた二領域モデルに移行する。
- `I` と `C` に基づく係数回帰を Jensen 勾配/ガウス拡散へ同時に反映し、外挿時も物理的制約（欠損正値、σ 単調増加）を保つ。
- コード・データ・検証フローをドキュメント化して、将来のパラメータスイープへ再利用できる状態にする。

### フェーズ1: データ整備とパラメータ抽出
1. `src/fit_gaussian_wake.jl` の各ケース処理に、以下の推定を追加する。
   - **Jensen 領域**: トップハット近似で `ΔU/U∞` を抽出し、線形化式から Jensen 勾配 `k_w(I,C)` と初期半径 `σ_J0(I,C)` を算出。`x/D < 2` を主対象とし、データ不足時は最小二乗の信頼度を記録。
   - **接続距離**: Jensen 欠損とガウス欠損の交差点を `x_shift(I,C)` と定義。欠損値および勾配の一致条件を解いて算出する。
   - **ガウス領域**: 既存の `σ(x)` フィットから `σ_G0(I,C)`（接続点での σ）と遠方拡散勾配 `k_m(I,C)` を抽出。必要に応じて 2 次項も保持し、線形近似との誤差を記録。
2. 新しい列（`kw`, `sigmaJ0`, `sigmaG0`, `km`, `x_shift`, `fit_residual_kw`, `fit_residual_km` など）を `fit_coefficients_summary.csv` に追記し、CSV フォーマットを README に明記。
3. 外れ値検知: 各フィットの残差や標準誤差を監視し、閾値超過時はログと CSV にフラグを立てる。

### フェーズ2: 係数回帰モデル更新 (`src/coeff_model.jl`)
1. 返却値を `(; kw, sigmaJ0, sigmaG0, km, x_shift)` に変更。旧 `(C0, c, n, a2, a1, a0)` は後方互換モードで参照できるよう別関数に隔離。
2. 回帰基底は `[1, I, C, I·C, 1/I, C/I]` を基本とし、`kw` や `km` では `I` に対する冪的依存（例: `(I/Iref)^q`）も検証。フィット指標（R², RMSE, k-fold CV）をドキュメント化。
3. `I` が最小値未満の場合は `clamp(I, I_RANGE[1], I_RANGE[2])` を適用しつつ警告を出す。`x_shift` は正値制約を満たすようクリップする。

### フェーズ3: 二領域速度再構成 (`src/plot_reconstructed_wake.jl`)
1. CLI オプション `--two-region`（既定有効）と `--single-gauss`（従来比較用）を導入。
2. 近接域 (`x < x_shift`): Jensen 形式 `ΔU/U∞ = 1 - √{1 - C}/(1 + 2 k_w x/D)^2` を採用し、`σ(x)` は `σ_J0 + 2 k_w x` を用いて図示。
3. 遠方域 (`x ≥ x_shift`): Bastankhah 形式 `ΔU/U∞ = 1 - √{1 - C/(8(σ/D)^2)}` を用い、`σ(x) = σ_G0 + k_m (x - x_shift)` を基本に接続点で連続化補正係数を導入。
4. 可視化には接続位置と両領域の `σ(x)`、`ΔU(x,0)` ラインを重ね、ログ出力で使用パラメータを明示する。

### フェーズ4: 検証シナリオ
1. **全ケース検証**: `julia --project=. src/plot_reconstructed_wake.jl --all --two-region` 実行時に、
   - 近接域（x/D < 2）・遷移域（2≤x/D≤5）・遠方域（x/D > 5）ごとの L2 誤差、最大誤差、平均相対誤差を算出し `figures/recon_metrics.csv` に保存。
   - `--single-gauss` 実行時の指標と比較し、改善率 [%] を同 CSV に追記。
2. **外挿テスト**: I, C の範囲外パターンを3ケース選び、再構成結果を `figures/extrapolation/` に保存。警告ログと併せて挙動を確認。
3. **ケーススタディ**: 代表的な 3 ケース（低I+低C、中I+中C、高I+高C）で、近接域・遠方域の速度プロファイルと σ の推移を図化し、`FigGaussPD.md` に抜粋を掲載。

### フェーズ5: ドキュメントと運用
1. 本ファイルおよび `FigGaussPD.md` に実装状況・コミット ID・残課題を逐次追記。
2. `CHANGELOG.md`（未存在の場合は新規作成）にフェーズ完了ごとの要約を記録。
3. パラメータスイープ再実行時に必要な手順（データリンク、フィット、回帰、検証）をシェルスクリプト化し、CI あるいは手動手順として共有する。

### マイルストーンと目安
| フェーズ | 目標 | 目安工数 |
| --- | --- | --- |
| 1 | 追加パラメータ抽出と CSV 拡張、外れ値検出 | 1〜2 日 |
| 2 | 回帰モデル差し替えと指標整理 | 0.5〜1 日 |
| 3 | 二領域再構成ロジックと可視化改修 | 1〜2 日 |
| 4 | 自動検証・外挿テスト | 0.5〜1 日 |
| 5 | ドキュメント更新・運用整備 | 0.5 日 |

進捗に応じて本計画を更新し、課題やリスク（例: 外れ値への対処、I→0 での安定性）を追記すること。



------

~~~
julia --project=. src/fit_gaussian_wake.jl
...
==============================
Processing case: I0p3000_C22p0000 from data/result_I0p3000_C22p0000.csv
Loaded data: (147136, 10)
Freestream velocity U∞ = 1.0000
Fitted 362 sections successfully.
σ(x) = -0.0012 * x^2 + 0.0508 * x + 0.3154
C(x) = 0.3509 * (1 + 0.4066 * x)^(-0.6738)
Final analytical model for I0p3000_C22p0000:
u(x,r) = U∞ * [1 - 0.3509 * (1 + 0.4066*x)^(-0.674) * exp(-r^2 / (2*(-0.0012*x^2 + 0.0508*x + 0.3154)^2))]
Near-field σ fit: σ ≈ 0.2564 + 0.0734·x (RMSE 0.0007)
Far-field σ fit: σ ≈ 0.4761 + 0.0213·x (RMSE 0.0110)
Derived transition: sigmaJ0=0.2564, kw=0.0734, x_shift=4.2225, sigmaG0=0.5085
Saved figure: figures/wake_fit_I0p3000_C22p0000.png

Saved summary table: fit_coefficients_summary.csv
~~~

### 作業メモ

#### 2025-01-18: フェーズ1完了 - Jensen中心線フィット修正

**問題点の特定と解決**
- 初期実装では `Ct = C`（10〜22）を固定し、`kw` のみを1パラメータフィットしていた
- Cはポーラスディスク抵抗パラメータであり、推力係数Ct（0〜1の範囲）とは異なる物理量
- 結果: すべてのケースで残差が閾値の15〜20倍（平均0.732）、kw=0.05（初期値）のまま固定

**実施した修正**
- `src/fit_gaussian_wake.jl:107-128` の `fit_jensen_gradient` 関数を2パラメータフィット `[kw, Ct_eff]` に変更
- Ct_eff（有効推力係数）をCFDデータから経験的に推定するデータ駆動アプローチ
- CSV出力に `Ct_eff` カラムを追加（13列目）

**修正結果（劇的改善）**
```
項目          | 修正前  | 修正後   | 改善率
--------------|---------|----------|--------
平均残差      | 0.732   | 0.00313  | 99.6%
最大残差      | 0.868   | 0.0106   | 98.8%
外れ値率      | 100%    | 0%       | 完全解消
```
- **全31ケースが閾値0.04以内に収まった** ✓
- Ct_eff範囲: 0.308〜0.646（平均0.475±0.092）、物理的に妥当
- CとCt_effに明確な正の相関: C=10→Ct≈0.35、C=22→Ct≈0.56

**パラメータ傾向**
- `kw`: 高I領域（I≥0.2）で0.03〜0.04、低I領域でほぼ0
- `km`: 0.003〜0.022、Iとともに顕著に増加（物理的に妥当）
- `Ct_eff`: Cとほぼ線形関係、I依存性も観測される

**出力データ**
- `fit_coefficients_summary.csv`: 23カラム、31ケース
- 主要パラメータ: `kw`, `Ct_eff`, `sigmaJ0`, `sigmaG0`, `km`, `x_shift`
- 残差指標: `fit_residual_kw`, `fit_residual_km`
- 外れ値フラグ: `kw_outlier`, `km_outlier`（全てfalse）

**コミット推奨**
```bash
git add src/fit_gaussian_wake.jl fit_coefficients_summary.csv JensenBastankhah_Plan.md
git commit -m "Fix Jensen centerline fit: 2-parameter estimation (kw, Ct_eff)

- Modified fit_jensen_gradient to estimate both kw and Ct_eff from CFD data
- Resolved issue where Ct was incorrectly set to C (10-22) instead of thrust coefficient (0-1)
- Residuals reduced from 0.73 to 0.003 (99.6% improvement)
- All 31 cases now within threshold (0.04)
- Added Ct_eff column to CSV output

Phase 1 completed. Ready for Phase 2 (coefficient regression).
"
```

#### 2025-01-18: フェーズ2完了 - 係数回帰モデル更新

**実施内容**
1. **回帰係数の計算**（`src/compute_regression_coeffs.jl`）
   - fit_coefficients_summary.csvから新パラメータ（kw, Ct_eff, sigmaJ0, sigmaG0, km, x_shift）の回帰分析を実行
   - 基本基底: `[1, I, C, I·C]` → Ct_eff, sigmaJ0, sigmaG0, x_shift
   - 拡張基底: `[1, I, C, I·C, 1/I, C/I]` → kw, km

2. **coeff_model.jlの更新**
   - 新関数 `coefficients_two_region(I, Ct)` を追加
   - 旧関数 `coefficients_from_IC(I, Ct)` は後方互換性のために保持
   - 物理的制約を実装（非負値、0-1範囲、正値）

3. **回帰精度**
   ```
   Parameter   | R²     | RMSE      | 評価
   ------------|--------|-----------|----------
   Ct_eff      | 0.945  | 0.0215    | 優秀
   sigmaJ0     | 0.942  | 0.0021    | 優秀
   sigmaG0     | 0.976  | 0.0061    | 優秀
   km          | 0.972  | 0.0010    | 優秀
   kw          | 0.858  | 0.0055    | 良好
   x_shift     | 0.467  | 2.024     | 要改善
   ```

4. **テスト結果**（`src/test_coeff_model.jl`）
   - 全テストケースで物理的制約を満たす ✓
   - 範囲外入力でも妥当な外挿 ✓
   - 平均絶対誤差（サンプル5ケース）:
     - kw: 0.0015, Ct_eff: 0.017, sigmaJ0: 0.0015
     - sigmaG0: 0.0008, km: 0.0008, x_shift: 1.59

**知見**
- x_shiftの回帰精度が低い（R²=0.47）のは、多くのケースで固定値2.0になっているため
- kwはI依存性が強く、拡張基底でも中程度の精度（R²=0.86）
- 他のパラメータ（Ct_eff, sigmaJ0, sigmaG0, km）は高精度で回帰可能

**出力ファイル**
- `src/coeff_model.jl` - 更新済み（新関数追加、旧関数保持）
- `src/compute_regression_coeffs.jl` - 回帰係数計算スクリプト
- `src/test_coeff_model.jl` - テストスクリプト

### 次回 TODO（フェーズ3）
1. `src/plot_reconstructed_wake.jl` の二領域再構成実装
   - Jensen領域（x < x_shift）: `ΔU/U∞ = 1 - √{1 - Ct_eff/(1+2*kw*x)^2}`
   - Bastankhah領域（x ≥ x_shift）: `ΔU/U∞ = 1 - √{1 - Ct_eff/(8(σ/D)²)}`
   - σ(x) の連続化と可視化
2. CLI オプション `--two-region` / `--single-gauss` の実装
3. 全ケース検証と誤差評価（L2, 最大誤差）
