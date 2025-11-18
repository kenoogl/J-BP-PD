## Fit Gauss-PD

### 背景と目的
- `/Users/Daily/Development/RANS-PD/scripts/run_sweep.jl` で乱流強度 `I` と風車係数 `C` を掃引し、各ケースごとに `k = 1.5 (uI)^2`、`ω = β^(3/4) k^(3/2) / (Lm β k)`（β=0.09, Lm=0.2）を算出して `src/run.jl` を実行。
- 生成された流れ場（`output/result_I..._C....csv`）を用いて、ガウス型速度欠損モデル  
  \[
  u(x,r) = U_\infty \left[1 - C(x)\exp\!\left(-\frac{r^2}{2\sigma^2(x)}\right)\right]
  \]
  に I, C 依存性を織り込む。

### データ準備
1. RANS-PD 側で計算済み CSV を `output/result_Ixxxx_Cyyyy.csv` 形式で用意（例：`result_I0p0100_C10p0000.csv`）。
2. 本リポジトリ `FitGauss-PD` 直下に `data/` を作成し、上記ファイルへシンボリックリンクまたはコピーを行う。多数ある場合は `ln -s /Users/Daily/Development/RANS-PD/output data` としてディレクトリ単位でリンクするのが簡便。  

   - ##### データにシンボリックリンクを張る

     ~~~
     cd /Users/Daily/Development/WindTurbineWake/FitGauss-PD
     mkdir data
     cd data
     for f in /Users/Daily/Development/WindTurbineWake/RANS-PD/output/*.csv; do ln -s "$f" .; done
     ~~~

3. `data` 内のファイル名は `I` と `C` を `p` 記法（例 `0p0100`）で表す前提。

### スクリプト概要
| ファイル | 役割 | 使い方の例 |
| --- | --- | --- |
| `src/fit_gaussian_wake.jl` | `data/` 内の全 CSV を自動列挙し、各ケースで断面ごとにガウスフィット→ `C(x)` と `σ(x)` の最終式を推定。係数を `fit_coefficients_summary.csv` に書き出し、`figures/wake_fit_Ixxxx_Cyyyy.png` を保存。 | `julia --project=. src/fit_gaussian_wake.jl` |
| `src/plot_contour.jl` | 指定ケースの生データを x-y 平面コンター表示。引数に `(I, C)` または CSV パスを指定可能。`--all` を付けると全ファイルを連続処理。 | `julia --project=. src/plot_contour.jl 0.03 16` / `julia --project=. src/plot_contour.jl --all` |
| `src/plot_reconstructed_wake.jl` | `coeff_model.jl` の回帰式を既定で用いて任意の I,C に対応する係数を生成し、速度場・速度欠損・半径方向プロファイルを図化。`--summary` を付ければ `fit_coefficients_summary.csv` 由来の係数を使用。`--all`で全ケースをまとめて作図。 | `julia --project=. src/plot_reconstructed_wake.jl 0.05 22` / `julia --project=. src/plot_reconstructed_wake.jl --all --summary` |

### I・C を組み込んだ係数モデル化
1. `fit_coefficients_summary.csv` に含まれる 30 ケース（I: 0.01–0.30、Ct: 10–22）から `C0`, `c`, `a2`, `a1`, `a0` を説明変数 `[1, I, C_t, I C_t]` で回帰。決定係数は 0.88〜0.99。

   \[
   \begin{aligned}
   C_0(I,C_t) &\approx 0.0611 - 0.0173 I + 0.0190 C_t - 0.0196 I C_t \\
   c(I,C_t)   &\approx -5.80\times10^{-3} + 1.786 I - 1.69\times10^{-3} C_t - 0.0105 I C_t \\
   a_2(I,C_t) &\approx -9.71\times10^{-5} - 3.94\times10^{-3} I + 6.73\times10^{-6} C_t - 2.78\times10^{-5} I C_t \\
   a_1(I,C_t) &\approx 8.38\times10^{-3} + 0.155 I - 1.43\times10^{-4} C_t + 5.78\times10^{-4} I C_t \\
   a_0(I,C_t) &\approx 0.213 + 0.254 I + 0.00253 C_t - 0.00543 I C_t
   \end{aligned}
   \]

   - C0, c, a2, a1, a0 は [1, I, Ct, I·Ct] の線形結合で高い再現性を得られ（R²: 0.88–0.99）、式をそのまま σ(x) の多項式へ差すだけでケース固有の値が不要になります。

2. `n` は I に対して非線形に減少するため、$(1/I)$ と $(1/I^2)$ の項を追加した拡張線形モデルでフィットした（決定係数 0.90）。
   \[
   \begin{aligned}
   n(I,C_t) \approx &\,(100.4 - 220.6 I - 30.6 C_t + 82.6 I C_t) \\
                    &+ \frac{-10.68 + 2.33 C_t}{I} + \frac{0.124 - 0.0197 C_t}{I^2}
   \end{aligned}
   \]

   ※ $I \to 0$ の外挿では発散するため、実測範囲 (I ≧ 0.01) 内での利用を推奨。

3. 上記を `C(x) = C_0(I,C_t) \bigl(1 + c(I,C_t)\,x \bigr)^{-n(I,C_t)}` および $\sigma(x; I,C_t) = a_2 x^2 + a_1 x + a_0$ に代入すれば、任意の `(I,C_t)` に対するガウス速度欠損モデルが得られる。`Ct=25` のケースはフィット結果が未収録のため、必要なら追加で `fit_gaussian_wake.jl` を再実行する。
   これらの式は `src/coeff_model.jl` に実装済みで、他スクリプトから `coefficients_from_IC(I,C_t)` を呼び出すだけで利用できる。

   

### 出力物
- `figures/` に各ケースのフィット結果、コンター、再構成図を保存。
- `fit_coefficients_summary.csv` には各ケースの係数に加えて Jensen/Bastankhah 二領域用の列を整備している（全23カラム）。`file`, `I`, `Ct`, `U∞`, `C0`, `c`, `n`, `a2`, `a1`, `a0`, `sections` に続き、`kw`, `Ct_eff`, `sigmaJ0`, `sigmaG0`, `km`, `x_shift`, `rmse_kw`, `rmse_km`, `fit_residual_kw`, `fit_residual_km`, `kw_outlier`, `km_outlier` を追記した。
  - `kw`: Jensen勾配係数。中心線欠損データから推定。
  - `Ct_eff`: 有効推力係数（0〜1範囲）。CFDデータから経験的に推定され、ポーラスディスク抵抗パラメータCと正の相関を持つ。
  - `sigmaJ0`: 近接域 σ 線形フィットの切片。
  - `km`/`sigmaG0`: 遠方 σ 勾配と接続点での σ。
  - `x_shift`: Jensen 欠損とガウス欠損が一致する距離。
  - `fit_residual_kw`/`fit_residual_km`: 各領域の回帰 RMSE。
  - `kw_outlier`/`km_outlier`: しきい値（kw: 0.04, km: 0.02）超過フラグ。
- Jensen 領域の欠損値は `src/fit_gaussian_wake.jl` 内で中心線上 (|y|<0.05) の CFD サンプルから抽出しており、データ不足時は最も中心寄りの点を代用する。`kw` と `Ct_eff` のフィットには LsqFit の **2パラメータ最小二乗**（`[kw, Ct_eff]`）を用い、Jensen形式 `ΔU/U∞ = 1 - √{1 - Ct_eff/(1 + 2*kw*x)^2}` にデータ駆動でフィットする。この修正により全31ケースで残差が0.04以内に収まり、外れ値が完全に解消された（修正前は平均残差0.73、修正後は0.003）。
- `src/plot_contour.jl:1-118` を再構成し、`--all/-a/all` を指定すると data/ 内の全 CSV を列挙して順次コンター図を生成できるようにしました。個別ケース指定時のロジックは維持しつつ、ケースごとの処理を plot_case に分離し、タイトルと保存先 (`figures/u_contour_<case>.png`) もケース名入りに変更しています。
- これで `julia --project=. src/plot_contour.jl --all` を実行すれば全データ分の図がまとめて生成されます。従来通り単一ケースを描画したい場合は、`julia src/plot_contour.jl 0.05 22 や julia src/plot_contour.jl result_I0p0500_C22p0000.csv` のように指定してください。
- **C25のケースがおかしいのでデータを削除**



~~~
julia --project=. src/fit_gaussian_wake.jl

==============================
Processing case: I0p0100_C10p0000 from data/result_I0p0100_C10p0000.csv
Loaded data: (147136, 10)
Freestream velocity U∞ = 1.0000
Fitted 362 sections successfully.
σ(x) = -0.0000 * x^2 + 0.0035 * x + 0.2484
C(x) = 0.2513 * (1 + 0.0000 * x)^(-329.0709)
Final analytical model for I0p0100_C10p0000:
u(x,r) = U∞ * [1 - 0.2513 * (1 + 0.0*x)^(-329.071) * exp(-r^2 / (2*(-0.0*x^2 + 0.0035*x + 0.2484)^2))]
Saved figure: figures/wake_fit_I0p0100_C10p0000.png
.
.
.
==============================
Processing case: I0p3000_C25p0000 from data/result_I0p3000_C25p0000.csv
Loaded data: (147136, 10)
Freestream velocity U∞ = 1.0000
Fitted 362 sections successfully.
σ(x) = -0.0012 * x^2 + 0.0508 * x + 0.3187
C(x) = 0.3847 * (1 + 0.3964 * x)^(-0.6843)
Final analytical model for I0p3000_C25p0000:
u(x,r) = U∞ * [1 - 0.3847 * (1 + 0.3964*x)^(-0.684) * exp(-r^2 / (2*(-0.0012*x^2 + 0.0508*x + 0.3187)^2))]
Saved figure: figures/wake_fit_I0p3000_C25p0000.png

Saved summary table: fit_coefficients_summary.csv
~~~





### 今後のタスク案

1. `fit_coefficients_summary.csv` をもとに I, C の関数形をさらに簡略化し、汎用モデルへ展開。

   - ~~~
     `fit_coefficients_summary.csv` をもとに I, C の関数形をさらに簡略化し、汎用モデルへ展開します。I,Cを導入する場合のモデルの形について適切な案とその理由を説明
     
     • - 既存モデルでは各ケースごとに C(x) = C0 (1 + c x)^(-n)、σ(x) = a2 x² + a1 x + a0 を推定しており、C0, c, n, a2, a1, a0 が I・C（ここでは入口乱流強度と風車係数）ごとに別値になっています。汎用化するには、これら係数に I・C を直接組み込む関数形を決める必要があります。
       - 抑えるべき点：
           1. 乱流強度 I が大きいほど初期混合が早まり、σ(x) の増加が速くなる傾向がある（＝σの多項式係数に I が効く）。
           2. 風車係数 C（運動量吸収）を高めると初期欠損 C0 が大きくなるが、下流での回復勾配も変わる（＝C(x) の指数 n や c に依存）。
           3. CSV 命名では I, C が離散的に並ぶため、関数形は単純な線形/冪乗のほうがフィットしやすい。
       - 推奨案：
           1. 係数分離モデル
               - C0(I,C) = α0 + αI I + αC C + αIC I C
               - c(I,C) = β0 + βI I + βC C（負になる場合を避けるなら c = exp(...) のように指数化）
               - n(I,C) = γ0 + γI I + γC C
               - σ(x; I,C) = [a20 + a2I I + a2C C] x² + [a10 + a1I I + a1C C] x + [a00 + a0I I + a0C C]
                 理由: 係数を I,C の一次式＋交差項にすると、少ないサンプルでもフィット可能で、物理的意味（I↑→σ増、C↑→C0増）を直観的に反映できる。
           2. スケーリングモデル
               - C(x; I,C) = Cref (C/Cref_C)^p (1 + c0 x)^(-n0 (I/Iref)^q)
               - σ(x; I,C) = (σ0 + sI I + sC C) * (1 + k x)
                 理由: I や C が 0 に近い場合でも滑らかに外挿でき、指数/冪で正値を保持。(C/Cref_C)^p は初期欠損が風車係数の冪に比例するという通説に合わせられる。n0
                 (I/Iref)^q で乱流強度に応じた減衰勾配の変化を表現。
           3. テーブル補間 + 正則化
               - C0(I,C) 等を 2 次元サーフェスとして扱い、I と C に沿って 2D 多項式（例：双二次）やラジアル基底関数で補間。
                 理由: データが格子状（I×C）で揃っているため、滑らかな面を張るだけで十分。物理的制約を追加したい場合は正則化項（例：∇²）を加える。
       - まず案1（一次多項式）を適用し、fit_coefficients_summary.csv の係数に対して線形回帰を行うのが平易で、ケース数が増えても扱いやすいです。フィット後に残差が大きい係数に対して案2（冪・指数）で再調整すれば、非線形性を持つ依存も吸収できます。
     
     ~~~
   - `src/coeff_model.jl:1-64` を新規追加し、回帰で得た一般係数モデルを `coefficients_from_IC(I,Ct)` で即利用できるようにしました。``C0,c,a2,a1,a0` は一次結合、`n` は

   ` (1/I)・(1/I^2) `を含む拡張基底で評価し、範囲外入力時は警告を出します。

   - `src/plot_reconstructed_wake.jl:1-156` では `coeff_model.jl` を読み込み、係数取得モードを `--analytic`（既定）と `--summary` で切り替えられるように変更しました。`--all` の併用も可能で、どのモードで係数を組んだか出力ログで分かります。

    \- `FigGaussPD.md:26-58` に上記仕様を反映し、再構成スクリプトがデフォルトで解析的モデルを使うこと、``coeff_model.jl` で式を共通化したことを追記しました。

    実行確認は行っていないため、`julia --project=. src/plot_reconstructed_wake.jl 0.03 16` や `--all --summary` で動作をチェックしてください。

2. 再構成結果と CFD データの誤差評価（L2 など）を自動化。
3. Fit解析対象を他の乱れ条件（例：風向変化）へ拡張し、同じフローで係数抽出できるか検証。



------

**行った作業はI,Cの係数をカーブフィッティングに採り入れたことです。物理的な意味を考慮して、ガウス型速度欠損モデルを修正することを考えてください。**

• - src/fit_gaussian_wake.jl:33-58 で使っている現行モデルは、(1) 断面ごとに u/U∞ = 1 - C(x) exp(-r²/(2σ²(x))) をフィットし、(2) σ(x) = a₂x² + a₁x + a₀、C(x) =  C₀(1 + c x)^(-n) の形に再フィット、(3) src/coeff_model.jl:5-43 で I・Ct を説明変数にした線形／拡張線形回帰で a₂,a₁,a₀,C₀,c,n を与える、という完全に統計的な作りです。このため係数は滑らかに外挿できるものの、運動量保存や乱流散逸といった物理的制約を満たす保証がありません。

 \- 物理意味を組み込んで式を修正するなら、以下の流れでモデル自体を差し替えるのが筋が良いです。

1. 軸運動量保存で C(x) を決定: Bastankhah & Porté-Agel (2014) 系のガウスモデルでは、軸対称・薄流れ近似を前提に ΔU/U∞ = 1 - √{1 - Ct / (8(σ/D)²)} を得ます。C(x) を別途フィットする代わりに、σ(x) が決まれば C(x) は自動的に決まる形に変更します。コード的には fit_gaussian_wake.jl の model_C を削除し、σ のフィット後に C(x) を上式から算出してログ表示・CSV出力するように変え、coeff_model.jl では C0,c,n ではなく σ パラメータ（後述の k, ε など）を I・Ct から返すように作り替えます。

2. 乱流拡散長さに基づく σ(x): 乱流混合を dσ/dx ≈ k_m I（k_m: 混合係数）で扱うと、σ(x) = √{σ₀² + 2k_m I (x - x₀) + (k_m I)² (x - x₀)²} のように平方根形になります。σ₀ は近接域の見かけコア径（例: 0.5D√{(1+√{1-Ct})/2}）で決まるため、自由パラメータは主に k_m(I,Ct) のみです。これを k_m = α₀ + α_I I + α_C Ct+ α_{IC} I·Ct の一次式、あるいは (I/I_ref)^q まで含んだ拡張式にして coefficients_from_IC で返せば、σ は必ず単調増加し負値にもなりません。

3. 近接域と遠方域の接続: 実測データでは x/D ≲ 2 でガウス仮定が崩れるため、x < x_shift(I,Ct) では Jensen 型（1 - ΔU/U∞ = (1 - √{1 - Ct})/(1 + 2k_w x/D)^2）を使い、x ≥ x_shift からガウスに切り替える piecewise モデルにします。x_shift と k_w を I, Ct の関数としてフィットすれば、近傍域での過度な復元や振動を抑えられます。plot_reconstructed_wake.jl 側では coeff_model.jl から (σ₀, k_m, x_shift) を受け取り、piecewise で速度場を描くように更新します。

4. サポートするパラメータを絞る: 以上を適用すれば、フィットすべき物理パラメータは σ₀(I,Ct), k_m(I,Ct), x_shift(I,Ct) の 3 つ（＋必要に応じて横方向・鉛直方向を分けた 4 つ）程度に減ります。fit_gaussian_wake.jl の CSV 出力列もこれらに置き換え、既存の C0,c,n,a2,a1,a0 は過去互換のため別列に残すか、必要ならplot_reconstructed_wake.jl --summary モードでのみ参照するよう整理できます。

 \- 実装手順の目安:

1. fit_gaussian_wake.jl で σ のフィット結果から σ₀ と遠方勾配 dσ/dx を推定し、新しい列 (sigma0, km, x_shift) を fit_coefficients_summary.csv に書き出す。
2. coeff_model.jl を「I・Ct→(σ₀, k_m, x_shift)」へ差し替え、必要に応じて線形＋冪的項で回帰。coefficients_from_IC は (; sigma0, km, x_shift) を返し、plot_reconstructed_wake.jl 側で σ(x) と C(x) を計算する。

3. plot_reconstructed_wake.jl の再構成ロジックを Bastankhah 形式（軸運動量保存＋ガウス）に修正し、piecewise 近傍補正や I 依存 k_m を反映する。
4. 全ケースで --summary／--analytic を比較し、L2 誤差などで改善を確認。必要なら FigGaussPD.md に物理的な根拠と式を追記。

 \- 次に進めるとすれば、上の ③の中から優先度が高いものを選んで詳細仕様（具体的な式、回帰に使う基底、検証手順）を詰めます。どの案から取り掛かるか指示いただければ、実装計画やコード変更案を具体化します。



› 近接域と遠方域の接続については、既に論文がありますか





• 既存文献の中で「近接域は Jensen・遠方域はガウス」という形で明示的に接続しているものは多くありません。ただし以下のように、近接域／遠方域を異なる扱いで結び付ける議論は複数あります。



 \- Jensen (PARK) + Bastankhah 接続

   \- Bastankhah & Porté-Agel (2014) はガウスモデルを導きつつ、近接域（x/D ≲ 2）ではガウス仮定が成り立たず運動量仮定も破綻しやすいと述べています。実務の空力解析では Jensen/PARK（トップハット）を入口側に使い、一定距離以降でガウスモデルに切り替える手法が散見されます（例: Niayifar & Porté-Agel 2016 の風車列解析）。論文中に明確な式としては示されていないものの、実装上は “matching distance” を設けて速度欠損の連続性だけ合わせています。

 \- Frandsen 2007 / Ishihara & Qian 2018 など

   \- 風車近傍と遠方で異なる拡散係数やコアサイズを設定し、x によって係数を変える piecewise なパラメータ化を採用しています。ガウス型そのものを切り替えるというより、近接域では乱流強度増加を強制して σ を急激に広げたり、C(x) に補正項を入れることで遠方式へ滑らかにつなげる構成です。

 \- 商用設計ツール（例: DNV’s WindFarmer, OpenFast の wake module など）

   \- 多くの場合、入口に Jensen/Frandsen 系を使い、一定距離で Bastankhah 系に切り替える実装が既にあります。これらはマニュアルやユーザーガイドで “combined Jensen-Gaussian wake model” と記されることが多いですが、査読論文として詳述された事例は限られます。



 したがって「論文で既製の式がある」というよりは、近接域の特性（翼列近い領域のコア、Shepherding vortex など）と遠方のガウス拡散を別モデルで扱い、程よいマッチング距離で ΔU/U∞ と d(ΔU)/dx を連続させるという考え方が既に一般化していると考えてください。必要なら参考として Bastankhah & Porté-Agel (J. Fluid Mech., 2014) やNiayifar & Porté-Agel (Renewable Energy, 2016) を参照するのが良いです。



› 今回のパラメータスイープのデータでは、乱流強度とポーラスディスクの抵抗パラメータCをモデルに採り入れる点に新規性があります。このアイデアをJensen (PARK) +Bastankhah 接続と組み合わせるのはどうか



• 乱流強度 I と抵抗パラメータ C を係数に織り込んだ点を、Jensen + Bastankhah の二領域モデルに重ねるのは相性が良いです。Jensen 側は ΔU/U∞ = 1 - √{1 - C} とσ_J(x) = r₀ + k_w(I,C) x のように簡単な形なので、k_w や r₀ に I・C を与えて「近接域の拡散が I に比例して早まる」「C が大きいと初期欠損が増える」といった物理直感を直接入れられます。

 \- ガウス側（Bastankhah）は、軸運動量保存から C(x) = 1 - √{1 - C/(8(σ/D)²)} が決まるため、ここでも σ(x) を σ_G(x; I,C) で描ければ、自動的に I・C の影響が速度欠損に反映されます。今回のパラメータスイープで σ のフィットから導いた (a₂,a₁,a₀) や新しい k_m を I, C の関数で表せるので、遠方域にも一貫した I・C 依存性を与えられます。

 \- 接続方法のアイデア:

1. x_shift(I,C) を決め、そこまで Jensen 形式で減衰させる（k_w(I,C) は線形＋交差項で回帰）。
2. x ≥ x_shift でガウス式に切り替え。σ の初期値は Jensen 側の σ を受け継ぎ、遠方での勾配 k_m(I,C) を使って Bastankhah の σ 発達式に乗せる。
3. 接続点で ΔU/U∞ と d(ΔU)/dx を一致させれば連続で滑らか。係数は既存データから直接回帰でき、新規性（I・C パラメータをフルに使う）も維持できます。

 \- 実装面では fit_gaussian_wake.jl を拡張して k_w(I,C) や x_shift(I,C) を抽出する処理を追加し、coeff_model.jl を新しいパラメータ（k_w, k_m, x_shift など）を返すように差し替える形が自然です。それに伴って plot_reconstructed_wake.jl も二領域計算に対応させれば、物理制約と I・C 依存を両立できます。



 次に進めたいステップ（例: fit_gaussian_wake.jl でパラメータ抽出を増やす、coeff_model.jl を新モデルに置き換える等）があれば指示ください。



＞乱流強度とポーラスディスクの抵抗パラメータCをモデルに採り入れ、Jensen + Bastankhah の二領域モデルに重ねるモデルを作成し、検証するシナリオを提案してください。

• - まずデータ面を整備します。src/fit_gaussian_wake.jl:33-147 に近接域（Jensen 型）と遠方域（Bastankhah 型）で必要になる指標を追加で推定する処理を組み込みます。具体的には各ケースについて (1) 近接域のトップハット欠損を線形化して k_w(I,C) を抽出、(2) ガウスフィットから得た σ(x) から初期コア径 σ₀(I,C) と遠方勾配k_m(I,C) を推定、(3) Jensen→Bastankhah の接続距離 x_shift(I,C) を定義し、これらを fit_coefficients_summary.csv に新列として書き込みます。

 \- 次に係数回帰を更新します。src/coeff_model.jl:1-43 の既存 (C0,c,n,a2,a1,a0) を廃し、coefficients_from_IC が (; kw, km, sigma0, x_shift) を返すように変更します。kw や km は [1, I, C, I·C, 1/I] などの基底で線形回帰し、必要に応じて I→0 の発散を避ける制約を入れます。これで I・C のパラメータ依存を Jensen 領域とガウス領域の双方へ統一的に入れられます。

 \- 二領域モデルを構築します。src/plot_reconstructed_wake.jl:1-197 を拡張し、x < x_shift では Jensen 形式 ΔU/U∞ = 1 - √{1 - C} / (1 + 2 kw x/D)^2 を、x ≥  x_shift では Bastankhah 形式 ΔU/U∞ = 1 - √{1 - C / (8(σ/D)^2)} を用いて速度欠損を計算します。σ(x) は σ₀ + km (x - x_shift) をベースに連続化し、接続点で速度と勾配が一致するよう補正します。可視化時に両領域の境界を表示し、接続の滑らかさをチェックできるようにします。

 \- 検証シナリオは 3 段階で進めます。

1. 係数再現性チェック: julia --project=. src/fit_gaussian_wake.jl を再実行し、新しい fit_coefficients_summary.csv と旧版の C0,c,n,a2,a1,a0 を比較。kw/km/ x_shift が I・C に対して滑らかに変化するかをプロットで確認。

2. 再構成精度評価: julia --project=. src/plot_reconstructed_wake.jl --all --analytic で全ケースの二領域モデルを描き、既存 --summary（生フィット値）と L2誤差、最大誤差、平均相対誤差を算出。近接域（x/D<2）と遠方域（x/D>5）それぞれで誤差統計を出し、二領域化の改善量を明示します。

3. 外挿テスト: 測定範囲外の I・C（例: I=0.35, C=18）を与え plot_reconstructed_wake.jl で再構成し、近接域での Jensen 形・遠方域での Bastankhah 形が物理的に妥当（欠損が負にならない、σ が単調増加する）かを確認します。ensure_range を活かしつつ警告と共に外挿挙動をチェックします。

 \- 最後に FigGaussPD.md を更新し、(1) I・C 依存を備えた Jensen+Bastankhah 二領域モデルの式、(2) 係数抽出と検証手順、(3) 得られた誤差評価を記録しておくと、今後のシミュレーションや報告に転用しやすくなります。
