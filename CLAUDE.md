# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

風車後流（wake）をガウス型速度欠損モデルでフィッティングするJuliaプロジェクト。RANS-PDシミュレーションで生成したCSVデータに対してガウスフィットを行い、速度場を再構成する。

### パラメータ説明

- **I** (乱流強度, Turbulence Intensity): 0.01〜0.30
- **C** (ポーラスディスク抵抗係数, Porous Disk Resistance Coefficient): 10〜25
  - RANS-PDシミュレーションで使用されるポーラスディスクモデルの抵抗係数
  - 推力係数（Ct）とは異なるパラメータ
  - データファイル名: `result_I{I値}_C{C値}.csv`

## 開発コマンド

### Julia環境
```bash
# Julia環境の起動
julia --project=.

# パッケージのインストール（初回のみ）
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

### データ準備
```bash
# RANS-PDの出力データへシンボリックリンクを作成
cd data
for f in /Users/Daily/Development/WindTurbineWake/RANS-PD/output/*.csv; do ln -s "$f" .; done
```

### スクリプト実行

#### 1. 全ケースのガウスフィット
```bash
# data/ 内の全CSVファイルを処理し、係数サマリーを生成
julia --project=. src/fit_gaussian_wake.jl
# 出力: fit_coefficients_summary.csv、figures/wake_fit_*.png
```

#### 2. 回帰係数の計算
```bash
# fit_coefficients_summary.csv から I・C の回帰モデルを計算
julia --project=. src/fit_regression.jl
# 出力: regression_summary.txt、coeff_model.jl用の係数コード
```

#### 3. コンター図の描画
```bash
# 特定ケースのCFDデータからコンター図を描画
julia --project=. src/plot_contour.jl <I> <C>

# 全ケースのコンター図を一括生成
julia --project=. src/plot_contour.jl --all

# 例:
julia --project=. src/plot_contour.jl 0.05 16
julia --project=. src/plot_contour.jl --all
```

#### 4. 計算結果の分析
```bash
# 回帰モデルの精度評価と可視化
julia --project=. src/analyze_results.jl
# 出力: analysis_report.txt、figures/analysis/*.png (16ファイル)
```

#### 5. 速度場の再構成
```bash
# 単一ケース: 回帰モデルから速度場を再構成（デフォルト）
julia --project=. src/plot_reconstructed_wake.jl <I> <C>

# 単一ケース: fit_coefficients_summary.csv から直接係数を読み込み
julia --project=. src/plot_reconstructed_wake.jl <I> <C> --summary

# 全ケース: 回帰モデルで一括再構成
julia --project=. src/plot_reconstructed_wake.jl --all

# 全ケース: CSVから直接読み込んで一括再構成
julia --project=. src/plot_reconstructed_wake.jl --all --summary

# 例:
julia --project=. src/plot_reconstructed_wake.jl 0.05 16
julia --project=. src/plot_reconstructed_wake.jl 0.05 16 --summary
julia --project=. src/plot_reconstructed_wake.jl --all
julia --project=. src/plot_reconstructed_wake.jl --all --summary
```

#### 6. プレゼンテーション生成
```bash
# PowerPointプレゼンテーションを生成（方法、結果、分析を含む）
cd presentation
npm run build

# 出力: gaussian-wake-model.pptx（プロジェクトルートに生成）
```

## コードベース構成

### ディレクトリ構造
```
FitGauss-PD/
├── src/
│   ├── fit_gaussian_wake.jl        # 全ケースのガウスフィット
│   ├── fit_regression.jl           # I・C回帰係数の計算
│   ├── coeff_model.jl              # I・C→係数変換モデル
│   ├── analyze_results.jl          # 計算結果の包括的分析
│   ├── plot_contour.jl             # CFDデータのコンター図描画
│   └── plot_reconstructed_wake.jl  # 速度場再構成（モデルまたはCSVから）
├── data/                           # CSVデータ（シンボリックリンク）
├── figures/                        # 生成図の保存先
│   └── analysis/                   # 分析結果の図（16ファイル）
├── presentation/                   # PowerPoint生成スクリプト
│   ├── slides/                     # HTMLスライド（12ファイル）
│   ├── images/                     # プレゼンテーション用図
│   ├── generate_presentation_v2.js # プレゼンテーション生成スクリプト
│   └── package.json                # Node.js依存パッケージ
├── fit_coefficients_summary.csv   # 全ケースの係数サマリー
├── regression_summary.txt         # 回帰結果のサマリー
├── analysis_report.txt            # 分析レポート
├── gaussian-wake-model.pptx       # 生成されたプレゼンテーション
└── Project.toml                    # Julia依存パッケージ
```

### データファイル命名規則
- フォーマット: `result_I{XXXX}_C{YYYY}.csv`
- 例: `result_I0p0100_C10p0000.csv`
  - I0p0100: 乱流強度 I = 0.01
  - C10p0000: ポーラスディスク抵抗係数 C = 10.0
- データ範囲: I (0.01〜0.30), C (10〜25)

### CSVデータ構造
10列: `x, y, z, u, v, p, k, omega, nut, divu`
- (x, y, z): 座標
- u: 主流方向速度
- その他: 乱流パラメータ

## アーキテクチャ

### 1. fit_gaussian_wake.jl
**目的**: data/ 内の全CSVファイルに対してガウス型速度欠損モデルをフィット

**処理フロー**:
1. data/ 内の全CSVファイルを自動列挙
2. ファイル名から I・C を抽出（例: result_I0p0100_C16p0000.csv → I=0.01, C=16.0）
3. 各ケースごとに以下を実行:
   - 上流境界（x < -4.8）から一様流速度 U∞ を算出
   - 各x断面で半径方向プロファイルにガウス型をフィット
     - モデル: `u/U∞ = 1 - C*exp(-r²/(2σ²))`
     - パラメータ: [C, σ]
   - C(x), σ(x) のx依存性をモデル化
     - `σ(x) = a₂x² + a₁x + a₀` (2次多項式)
     - `C(x) = C₀(1 + cx)^(-n)` (べき乗則)
   - フィット結果を `figures/wake_fit_{case}.png` に保存
4. 全ケースの係数を `fit_coefficients_summary.csv` に保存

**重要な実装詳細**:
- x > 1.0 のみ処理（1D後方以降）
- 各断面の抽出条件: `|x - xval| < 0.01`
- 最小データ点数: 10点以上
- 31ケースを自動処理（I: 0.01〜0.30, C: 10〜25）

### 2. fit_regression.jl
**目的**: fit_coefficients_summary.csv から I・C の回帰モデルを計算

**処理フロー**:
1. fit_coefficients_summary.csv を読み込み
2. 各係数に対して線形回帰を実行:
   - C0, c, a2, a1, a0: `[1, I, C, I·C]` の線形結合
   - n: `[1, I, C, I·C, 1/I, C/I, 1/I², C/I²]` の拡張線形モデル
3. 決定係数 R² を計算
4. coeff_model.jl 用の係数コードを出力
5. regression_summary.txt にサマリーを保存

**回帰精度**（31ケースから算出）:
- C0: R²=0.988
- c: R²=0.975
- a2: R²=0.950
- a1: R²=0.936
- a0: R²=0.878
- n: R²=0.900

### 3. analyze_results.jl
**目的**: fit_coefficients_summary.csv と回帰モデルの結果を包括的に分析

**処理フロー**:
1. CSVデータと回帰モデルを読み込み
2. 各係数の予測値を計算
3. 残差分析（予測値 - 実測値）
4. 決定係数（R²）の計算
5. 係数間の相関行列を計算
6. 16種類の可視化を生成:
   - 予測 vs 実測（6パネル）
   - 残差のI・C依存性（各6パネル、計12）
   - 係数のI・C依存性（各係数2プロット、計12）
   - I-C平面の等高線図（6パネル）
   - 速度欠損プロファイル比較（1図）
7. analysis_report.txt に統計サマリーを出力

**重要な知見**（31ケースから）:
- 最良の予測精度: C0 (R²=0.988)
- 最悪の予測精度: a0 (R²=0.878)
- 強い相関（|r|>0.7）:
  - c ⟷ a2 (r=-0.987)
  - c ⟷ a1 (r=+0.973)
  - a2 ⟷ a1 (r=-0.995)
- べき乗指数 n の残差が最大（RMSE=55.9）

**生成される図**:
- `figures/analysis/predicted_vs_measured.png`: 6係数の予測精度
- `figures/analysis/residual_vs_I.png`: I依存性の残差
- `figures/analysis/residual_vs_C.png`: C依存性の残差
- `figures/analysis/trend_*.png`: 各係数のI・C依存性（12図）
- `figures/analysis/contour_*.png`: I-C平面の等高線（6図）
- `figures/analysis/velocity_deficit_profile_*.png`: プロファイル比較

### 4. coeff_model.jl
**目的**: I・C から係数を算出する関数を提供

**主要関数**:
- `coefficients_from_IC(I, C)`: 任意の I, C に対する係数 (C0, c, n, a2, a1, a0) を返す
- `ensure_range(I, C)`: 入力パラメータが実測範囲内かチェック

**使用方法**:
```julia
include("coeff_model.jl")
coeffs = coefficients_from_IC(0.05, 16.0)
# coeffs.C0, coeffs.c, coeffs.n, coeffs.a2, coeffs.a1, coeffs.a0
```

### 5. plot_contour.jl
**目的**: 指定したI・CのCFDデータからコンター図を描画

**処理フロー**:
1. コマンドライン引数から I・C を取得（または --all で全ケース）
2. 単一ケースモード:
   - ファイル名を構築（4桁ゼロ埋め形式）
   - CFDデータを読み込み
   - コンター図を生成
3. 全ケースモード (--all):
   - data/ 内の全CSVファイルを列挙
   - 各ケースを順次処理
4. x, y座標をソートして一意な値を抽出
5. uを2次元配列に整形
6. コンター図を生成して `figures/u_contour_{case}.png` に保存

**可視化設定**:
- カラーマップ: `:thermal`
- アスペクト比: 1
- レベル数: 50
- 解像度: 1200x800, dpi=300

**オプション**:
- `--all`, `-a`, `all`: data/内の全ケースを処理

### 6. plot_reconstructed_wake.jl
**目的**: 回帰モデルまたはCSVから係数を取得し速度場を再構成

**処理フロー**:
1. コマンドライン引数から I・C を取得（または --all で全ケース）
2. 係数を取得（2つのモード）:
   - デフォルト: coeff_model.jl の回帰モデルから算出
   - --summary: fit_coefficients_summary.csv から直接読み込み
3. 単一ケースモード:
   - 指定されたI・Cで速度場を再構成
4. 全ケースモード (--all):
   - 回帰モデル使用時: data/内の全CSVから列挙
   - CSV使用時 (--summary): fit_coefficients_summary.csvから全ケースを取得
5. ガウスモデルで速度場を再計算
   - `u(x,r) = U∞ * (1 - C(x)*exp(-r²/(2σ(x)²)))`
6. 3種類の図を生成:
   - 速度場コンター図: `reconstructed_wake_{case}_{mode}.png`
   - 速度欠損コンター図: `velocity_deficit_{case}_{mode}.png`
   - 半径方向プロファイル: `radial_profiles_{case}_{mode}.png`

**計算グリッド**:
- x: 0〜20, 300点
- r: -5〜5, 200点

**オプション**:
- `--summary`: fit_coefficients_summary.csvから直接係数を読み込み
- `--all`, `-a`, `all`: 全ケースを処理
- `--all --summary`: 全ケースをCSVから読み込んで処理

**係数取得モードの詳細**:

| モード | 係数の取得方法 | 用途 | 利点 | 制約 |
|--------|--------------|------|------|------|
| デフォルト | coeff_model.jlの回帰モデルで計算 | 任意のI・Cの予測・外挿 | - 測定範囲外でも予測可能<br>- 滑らかな係数変化（R²: 0.88〜0.99） | 回帰による近似誤差あり |
| --summary | fit_coefficients_summary.csvから直接読み込み | 既存ケースの正確な再現 | - フィット時の正確な値<br>- 回帰誤差なし | CSVに記録されたケースのみ |

**係数値の比較例**（I=0.05, C=16の場合）:
```
              CSV(実測)  モデル(計算)
C0            0.3444     0.3479
c             0.0106     0.0470
n             4.2830     118.8965
a2           -0.000149  -0.000206
a1            0.0145     0.0143
a0            0.2568     0.2619
```

回帰モデルは31ケース全体から学習した一般式のため、個別ケースとは若干異なります。
特にn（べき乗指数）で大きな差が見られる場合がありますが、これは回帰モデルが
全ケースの平均的な傾向を捉えているためです。

**使い分けの目安**:
- 既存の測定ケースを正確に再現したい → `--summary`
- 測定していないI・Cを予測したい → デフォルト（モデル）
- 範囲外の条件（I<0.01, I>0.30, C<10, C>25）を外挿したい → デフォルト（警告付き）
- 両方を生成して比較する → 両方実行（ファイル名に`_model`/`_summary`が付く）

## コーディング規約

### インデント
- **2スペースインデント**を厳守

### ファイル名の形式
- データファイル: `result_I{XXXX}_C{YYYY}.csv` （4桁ゼロ埋め）
- 例: I=0.01, C=16.0 → `result_I0p0100_C16p0000.csv`
- コマンドライン引数は通常の浮動小数点数形式（0.01, 16.0）
- スクリプト内で自動的に4桁ゼロ埋め形式に変換

### 回帰モデルの更新
新しいデータでフィットした後は、以下の手順で回帰係数を更新:
1. `julia --project=. src/fit_gaussian_wake.jl` を実行
2. `julia --project=. src/fit_regression.jl` を実行
3. 出力されたコードを `src/coeff_model.jl` にコピー

### 物理パラメータ
- U∞: 上流境界（x < -4.8）での平均速度
- r: 半径方向距離 `r = |y|`
- ガウスモデル: `u/U∞ = 1 - C*exp(-r²/(2σ²))`

## 図の出力

図は `figures/` ディレクトリに保存されます：

### fit_gaussian_wake.jl の出力
- `figures/wake_fit_I{XXXX}_C{YYYY}.png`: 各ケースのC(x)とσ(x)のフィット結果

### plot_contour.jl の出力
- `figures/u_contour_I{XXXX}_C{YYYY}.png`: CFD生データのコンター図

### plot_reconstructed_wake.jl の出力
- `figures/reconstructed_wake_I{XXXX}_C{YYYY}_{mode}.png`: 再構成速度場
- `figures/velocity_deficit_I{XXXX}_C{YYYY}_{mode}.png`: 速度欠損場
- `figures/radial_profiles_I{XXXX}_C{YYYY}_{mode}.png`: 半径方向プロファイル

{mode} は `_model`（回帰モデル）または `_summary`（CSVから直接読み込み）

注意: `.gitignore`で`*.png`が除外されているため、図はバージョン管理されません。

## データフロー

```
1. RANS-PD → data/*.csv (CFDシミュレーション結果)
                ↓
2. fit_gaussian_wake.jl → fit_coefficients_summary.csv + figures/wake_fit_*.png
                ↓
3. fit_regression.jl → regression_summary.txt + coeff_model.jl用の係数コード
                ↓
4. analyze_results.jl → analysis_report.txt + figures/analysis/*.png (16ファイル)
                ↓
5. coeff_model.jl: coefficients_from_IC(I, C) で任意のケースの係数を算出
                ↓
6. plot_reconstructed_wake.jl → 速度場再構成図（3種類）
```

または

```
1. RANS-PD → data/*.csv
                ↓
2. plot_contour.jl → CFD生データのコンター図
```

## 実装済み機能

- ✅ 複数ケースの一括処理（31ケース）
- ✅ I・Cパラメータの回帰モデル化（R²: 0.88〜0.99）
- ✅ 係数サマリーCSVの自動生成
- ✅ コマンドライン引数による柔軟なスクリプト実行
- ✅ 回帰モデルとCSV直接読み込みの両方をサポート
- ✅ --allオプションで全ケースを一括処理
  - plot_contour.jl: 全ケースのコンター図を生成
  - plot_reconstructed_wake.jl: 全ケースの速度場再構成（モデルまたはCSV）
- ✅ 包括的な結果分析ツール
  - analyze_results.jl: R²評価、残差分析、相関行列、16種類の可視化
- ✅ PowerPointプレゼンテーション自動生成
  - 12スライド（タイトル、目的、方法×3、結果×2、分析×2、発見、結論）
  - 分析図を含む包括的なプレゼンテーション（1.8MB）
  - PptxGenJSを使用したプログラマティック生成

## 参考

過去のコミット履歴には、Jensen + Bastankhah 二領域モデルの実装が含まれています（Phase 2-3として削除済み）。必要に応じてコミット履歴を参照してください。
