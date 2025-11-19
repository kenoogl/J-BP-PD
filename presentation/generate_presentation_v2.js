#!/usr/bin/env node

const pptxgen = require("pptxgenjs");
const path = require("path");

async function main() {
  console.log("Creating PowerPoint presentation...");

  // Create new presentation
  const pres = new pptxgen();
  pres.layout = "LAYOUT_16x9";
  pres.author = "FitGauss-PD Analysis";
  pres.title = "CとIを用いたガウス型速度欠損モデル";

  // === Slide 1: Title ===
  let slide = pres.addSlide();
  slide.background = { color: "1e3c72" };
  slide.addText("CとIを用いた\nガウス型速度欠損モデル", {
    x: 0.5, y: 1.2, w: 9, h: 1.5,
    fontSize: 42, color: "FFFFFF", bold: true, align: "center"
  });
  slide.addText("風力タービン後流の予測手法", {
    x: 0.5, y: 2.9, w: 9, h: 0.6,
    fontSize: 24, color: "FFFFFF", align: "center"
  });
  slide.addText("RANS-PDシミュレーションデータに基づく回帰モデルの構築", {
    x: 0.5, y: 3.8, w: 9, h: 0.4,
    fontSize: 18, color: "FFFFFF", align: "center"
  });

  // === Slide 2: Objective ===
  slide = pres.addSlide();
  slide.addText("研究目的", {
    x: 0, y: 0, w: 10, h: 0.6,
    fontSize: 32, color: "FFFFFF", bold: true, fill: "1e3c72"
  });
  slide.addText("背景", {
    x: 0.4, y: 1.0, w: 9, h: 0.4,
    fontSize: 24, color: "1e3c72", bold: true
  });
  slide.addText([
    { text: "風力タービン後流は下流タービンの発電効率に大きく影響", options: { bullet: true } },
    { text: "高精度な後流予測モデルが風力発電所の最適配置に必要", options: { bullet: true } }
  ], {
    x: 0.5, y: 1.5, w: 9, h: 0.6,
    fontSize: 18
  });
  slide.addText("目的", {
    x: 0.4, y: 2.3, w: 9, h: 0.4,
    fontSize: 24, color: "1e3c72", bold: true
  });
  slide.addText([
    { text: "乱流強度 I とポーラスディスク抵抗係数 C から後流を予測", options: { bullet: true } },
    { text: "RANS-PDシミュレーションデータに基づくガウス型モデルの構築", options: { bullet: true } },
    { text: "任意の (I, C) に対する速度欠損プロファイルの高精度予測", options: { bullet: true } }
  ], {
    x: 0.5, y: 2.8, w: 9, h: 1.0,
    fontSize: 18
  });

  // === Slide 3: Model ===
  slide = pres.addSlide();
  slide.addText("ガウス型速度欠損モデル", {
    x: 0, y: 0, w: 10, h: 0.6,
    fontSize: 32, color: "FFFFFF", bold: true, fill: "1e3c72"
  });
  slide.addText("速度場の表現", {
    x: 0.4, y: 0.9, w: 9, h: 0.3,
    fontSize: 20, color: "1e3c72", bold: true
  });
  slide.addText("u(x, r) = U∞ × [1 - C(x) × exp(-r² / (2σ(x)²))]", {
    x: 0.5, y: 1.3, w: 9, h: 0.4,
    fontSize: 20, fontFace: "Times New Roman", italic: true, align: "center", fill: "f0f4f8"
  });
  slide.addText("係数の定義", {
    x: 0.4, y: 1.9, w: 9, h: 0.3,
    fontSize: 20, color: "1e3c72", bold: true
  });
  slide.addText("C(x): 中心線速度欠損 (Power-law decay)", {
    x: 0.5, y: 2.25, w: 9, h: 0.3,
    fontSize: 18
  });
  slide.addText("C(x) = C₀ × (1 + c·x)^(-n)", {
    x: 0.5, y: 2.5, w: 9, h: 0.3,
    fontSize: 20, fontFace: "Times New Roman", italic: true, align: "center", fill: "f0f4f8"
  });
  slide.addText("σ(x): 後流幅 (Polynomial expansion)", {
    x: 0.5, y: 2.9, w: 9, h: 0.3,
    fontSize: 18
  });
  slide.addText("σ(x) = a₂·x² + a₁·x + a₀", {
    x: 0.5, y: 3.15, w: 9, h: 0.3,
    fontSize: 20, fontFace: "Times New Roman", italic: true, align: "center", fill: "f0f4f8"
  });
  slide.addText("パラメータ", {
    x: 0.4, y: 3.6, w: 9, h: 0.3,
    fontSize: 20, color: "1e3c72", bold: true
  });
  slide.addText([
    { text: "I: 乱流強度 (0.01 ~ 0.30)", options: { bullet: true } },
    { text: "C: ポーラスディスク抵抗係数 (10 ~ 25)", options: { bullet: true } }
  ], {
    x: 0.5, y: 3.95, w: 9, h: 0.6,
    fontSize: 16
  });

  // === Slide 4: Method - Data ===
  slide = pres.addSlide();
  slide.addText("方法 1: データ取得", {
    x: 0, y: 0, w: 10, h: 0.6,
    fontSize: 32, color: "FFFFFF", bold: true, fill: "1e3c72"
  });
  slide.addText("RANS-PDシミュレーション", {
    x: 0.4, y: 0.9, w: 9, h: 0.35,
    fontSize: 22, color: "1e3c72", bold: true
  });
  slide.addText([
    { text: "Reynolds-Averaged Navier-Stokes方程式に基づく数値シミュレーション", options: { bullet: true } },
    { text: "ポーラスディスクモデルで風力タービンをモデル化", options: { bullet: true } },
    { text: "抵抗係数 C により後流強度を制御", options: { bullet: true } }
  ], {
    x: 0.5, y: 1.35, w: 9, h: 0.8,
    fontSize: 17
  });
  slide.addText("パラメータ空間の探索", {
    x: 0.4, y: 2.3, w: 9, h: 0.35,
    fontSize: 22, color: "1e3c72", bold: true
  });
  slide.addText([
    { text: "31ケースのシミュレーション実施", options: { bullet: true, color: "1e3c72" } },
    { text: "乱流強度 I: 0.01 ~ 0.30 (6水準)", options: { bullet: true } },
    { text: "抵抗係数 C: 10 ~ 25 (6水準)", options: { bullet: true } },
    { text: "各ケースで速度場 u(x, r) を取得", options: { bullet: true } }
  ], {
    x: 0.5, y: 2.75, w: 9, h: 1.0,
    fontSize: 17
  });
  slide.addText("データ構造", {
    x: 0.4, y: 3.9, w: 9, h: 0.3,
    fontSize: 22, color: "1e3c72", bold: true
  });
  slide.addText("各断面における半径方向速度プロファイル → ガウス関数へのフィッティング", {
    x: 0.5, y: 4.25, w: 9, h: 0.3,
    fontSize: 18
  });

  // === Slide 5: Method - Fitting ===
  slide = pres.addSlide();
  slide.addText("方法 2: ガウスフィッティング", {
    x: 0, y: 0, w: 10, h: 0.6,
    fontSize: 32, color: "FFFFFF", bold: true, fill: "1e3c72"
  });
  slide.addText("フィッティング手順", {
    x: 0.4, y: 0.9, w: 9, h: 0.35,
    fontSize: 22, color: "1e3c72", bold: true
  });
  slide.addText([
    { text: "各断面 x における半径方向速度 u(x, r) を取得", options: { bullet: { type: "number" } } },
    { text: "ガウス関数にフィッティングして係数 C(x), σ(x) を抽出", options: { bullet: { type: "number" } } },
    { text: "C(x) を Power-law モデルにフィッティング → C₀, c, n", options: { bullet: { type: "number" } } },
    { text: "σ(x) を2次多項式にフィッティング → a₂, a₁, a₀", options: { bullet: { type: "number" } } }
  ], {
    x: 0.5, y: 1.35, w: 9, h: 1.1,
    fontSize: 17
  });
  slide.addText("最適化手法", {
    x: 0.4, y: 2.6, w: 9, h: 0.35,
    fontSize: 22, color: "1e3c72", bold: true
  });
  slide.addText("Levenberg-Marquardt法による非線形最小二乗法", {
    x: 0.5, y: 3.0, w: 9, h: 0.3,
    fontSize: 17
  });
  slide.addText("minimize Σ [u_data(x, r) - u_model(x, r)]²", {
    x: 0.5, y: 3.3, w: 9, h: 0.3,
    fontSize: 18, fontFace: "Times New Roman", italic: true, align: "center", fill: "f0f4f8"
  });
  slide.addText("出力", {
    x: 0.4, y: 3.75, w: 9, h: 0.3,
    fontSize: 22, color: "1e3c72", bold: true
  });
  slide.addText("各ケースの6係数: (C₀, c, n, a₂, a₁, a₀)", {
    x: 0.5, y: 4.1, w: 9, h: 0.3,
    fontSize: 17
  });

  // === Slide 6: Method - Regression ===
  slide = pres.addSlide();
  slide.addText("方法 3: 回帰モデル", {
    x: 0, y: 0, w: 10, h: 0.6,
    fontSize: 32, color: "FFFFFF", bold: true, fill: "1e3c72"
  });
  slide.addText("線形回帰モデル (C₀, c, a₂, a₁, a₀)", {
    x: 0.4, y: 0.9, w: 9, h: 0.35,
    fontSize: 22, color: "1e3c72", bold: true
  });
  slide.addText("coeff = β₀ + β₁·I + β₂·C + β₃·I·C", {
    x: 0.5, y: 1.3, w: 9, h: 0.3,
    fontSize: 17, fontFace: "Times New Roman", italic: true, align: "center", fill: "f0f4f8"
  });
  slide.addText("基底関数: [1, I, C, I·C]", {
    x: 0.5, y: 1.65, w: 9, h: 0.3,
    fontSize: 17
  });
  slide.addText("拡張線形回帰モデル (n)", {
    x: 0.4, y: 2.15, w: 9, h: 0.35,
    fontSize: 22, color: "1e3c72", bold: true
  });
  slide.addText("n = β₀ + β₁·I + β₂·C + β₃·I·C + (β₄ + β₅·C)/I + (β₆ + β₇·C)/I²", {
    x: 0.5, y: 2.55, w: 9, h: 0.3,
    fontSize: 17, fontFace: "Times New Roman", italic: true, align: "center", fill: "f0f4f8"
  });
  slide.addText("基底関数: [1, I, C, I·C, 1/I, C/I, 1/I², C/I²]", {
    x: 0.5, y: 2.9, w: 9, h: 0.3,
    fontSize: 17
  });
  slide.addText("予測機能", {
    x: 0.4, y: 3.4, w: 9, h: 0.35,
    fontSize: 22, color: "1e3c72", bold: true
  });
  slide.addText([
    { text: "任意の (I, C) に対して6係数を予測", options: { bullet: true } },
    { text: "予測された係数から速度欠損プロファイルを再構成", options: { bullet: true } },
    { text: "実測範囲: I ∈ [0.01, 0.30], C ∈ [10, 25]", options: { bullet: true } }
  ], {
    x: 0.5, y: 3.8, w: 9, h: 0.8,
    fontSize: 17
  });

  // === Slide 7: Results - Dataset ===
  slide = pres.addSlide();
  slide.addText("結果 1: データセット概要", {
    x: 0, y: 0, w: 10, h: 0.6,
    fontSize: 32, color: "FFFFFF", bold: true, fill: "2a5298"
  });
  slide.addText("シミュレーションケース", {
    x: 0.4, y: 0.9, w: 4, h: 0.35,
    fontSize: 22, color: "2a5298", bold: true
  });
  slide.addText("31ケース", {
    x: 0.4, y: 1.3, w: 4, h: 0.5,
    fontSize: 28, color: "2a5298", bold: true, align: "center"
  });
  slide.addText("パラメータ範囲", {
    x: 0.4, y: 1.95, w: 4, h: 0.3,
    fontSize: 22, color: "2a5298", bold: true
  });
  slide.addText([
    { text: "乱流強度 I: 0.01 ~ 0.30", options: { bullet: true } },
    { text: "抵抗係数 C: 10 ~ 25", options: { bullet: true } }
  ], {
    x: 0.5, y: 2.3, w: 3.5, h: 0.6,
    fontSize: 16
  });
  slide.addText("各ケースから抽出", {
    x: 0.4, y: 3.0, w: 4, h: 0.3,
    fontSize: 22, color: "2a5298", bold: true
  });
  slide.addText([
    { text: "6つのガウス係数", options: { bullet: true } },
    { text: "複数断面の速度場データ", options: { bullet: true } },
    { text: "上流速度 U∞", options: { bullet: true } }
  ], {
    x: 0.5, y: 3.35, w: 3.5, h: 0.8,
    fontSize: 16
  });
  slide.addImage({
    path: path.join(__dirname, "images", "velocity_deficit_profile_I0.05_C16.0.png"),
    x: 5.2, y: 1.0, w: 4.2, h: 3.2
  });

  // === Slide 8: Results - Performance ===
  slide = pres.addSlide();
  slide.addText("結果 2: 回帰モデルの性能", {
    x: 0, y: 0, w: 10, h: 0.6,
    fontSize: 32, color: "FFFFFF", bold: true, fill: "2a5298"
  });
  slide.addText("決定係数 R²", {
    x: 0.4, y: 0.9, w: 4, h: 0.35,
    fontSize: 22, color: "2a5298", bold: true
  });
  slide.addText("C₀: R² = 0.9879 (最高精度)\nc:  R² = 0.9749\nn:  R² = 0.9000\na₂: R² = 0.9495\na₁: R² = 0.9362\na₀: R² = 0.8783 (最低精度)", {
    x: 0.5, y: 1.3, w: 3.5, h: 1.4,
    fontSize: 16, fontFace: "Courier New"
  });
  slide.addText("性能評価", {
    x: 0.4, y: 2.85, w: 4, h: 0.3,
    fontSize: 22, color: "2a5298", bold: true
  });
  slide.addText("全ての係数でR² > 0.87を達成\n特にC₀とcは高精度な予測が可能", {
    x: 0.5, y: 3.2, w: 3.5, h: 0.7,
    fontSize: 16
  });
  slide.addImage({
    path: path.join(__dirname, "images", "predicted_vs_measured.png"),
    x: 5.2, y: 0.9, w: 4.2, h: 3.4
  });

  // === Slide 9: Analysis - Residuals ===
  slide = pres.addSlide();
  slide.addText("分析 1: 残差統計", {
    x: 0, y: 0, w: 10, h: 0.6,
    fontSize: 32, color: "FFFFFF", bold: true, fill: "27ae60"
  });
  slide.addText("RMSE (二乗平均平方根誤差)", {
    x: 0.4, y: 0.9, w: 4, h: 0.35,
    fontSize: 22, color: "27ae60", bold: true
  });
  slide.addText("C₀: 9.15 × 10⁻³\nc:  2.68 × 10⁻²\nn:  55.9 (最大)\na₂: 1.04 × 10⁻⁴\na₁: 4.40 × 10⁻³\na₀: 7.04 × 10⁻³", {
    x: 0.5, y: 1.3, w: 3.5, h: 1.2,
    fontSize: 15, fontFace: "Courier New"
  });
  slide.addText("残差の特徴", {
    x: 0.4, y: 2.65, w: 4, h: 0.3,
    fontSize: 22, color: "27ae60", bold: true
  });
  slide.addText("平均値: ほぼゼロ（バイアスなし）\nC₀, c, a₂, a₁, a₀: 非常に小さい残差\nn: 相対的に大きな残差 → 非線形性が強い", {
    x: 0.5, y: 3.0, w: 3.5, h: 1.0,
    fontSize: 13
  });
  slide.addImage({
    path: path.join(__dirname, "images", "residual_vs_I.png"),
    x: 5.2, y: 0.9, w: 4.2, h: 3.4
  });

  // === Slide 10: Analysis - Correlation ===
  slide = pres.addSlide();
  slide.addText("分析 2: 係数間の相関", {
    x: 0, y: 0, w: 10, h: 0.6,
    fontSize: 32, color: "FFFFFF", bold: true, fill: "27ae60"
  });
  slide.addText("強い相関関係 (|r| > 0.7)", {
    x: 0.4, y: 0.9, w: 9, h: 0.35,
    fontSize: 22, color: "27ae60", bold: true
  });
  slide.addText([
    { text: "c ↔ a₂: r = -0.987 (非常に強い負の相関)", options: { bullet: true } },
    { text: "a₂ ↔ a₁: r = -0.995 (非常に強い負の相関)", options: { bullet: true } },
    { text: "c ↔ a₁: r = 0.973 (非常に強い正の相関)", options: { bullet: true } },
    { text: "c ↔ a₀: r = 0.789", options: { bullet: true } },
    { text: "n ↔ a₂: r = 0.721", options: { bullet: true } },
    { text: "n ↔ a₁: r = -0.759", options: { bullet: true } },
    { text: "a₂ ↔ a₀: r = -0.742", options: { bullet: true } },
    { text: "a₁ ↔ a₀: r = 0.721", options: { bullet: true } }
  ], {
    x: 0.5, y: 1.35, w: 9, h: 2.0,
    fontSize: 16
  });
  slide.addText("考察", {
    x: 0.4, y: 3.5, w: 9, h: 0.3,
    fontSize: 22, color: "27ae60", bold: true
  });
  slide.addText("速度欠損の減衰 (c, n) と後流幅の拡大 (a₂, a₁, a₀) は密接に関連\nこれらの相関関係は物理的な後流発達過程を反映", {
    x: 0.5, y: 3.85, w: 9, h: 0.6,
    fontSize: 17
  });

  // === Slide 11: Findings ===
  slide = pres.addSlide();
  slide.addText("主な発見", {
    x: 0, y: 0, w: 10, h: 0.6,
    fontSize: 32, color: "FFFFFF", bold: true, fill: "e67e22"
  });
  slide.addText("モデル性能", {
    x: 0.4, y: 0.9, w: 9, h: 0.35,
    fontSize: 22, color: "e67e22", bold: true
  });
  slide.addText([
    { text: "全係数でR² > 0.87を達成し、高精度な予測が可能", options: { bullet: true } },
    { text: "C₀（中心線速度欠損の初期値）が最も高精度（R² = 0.988）", options: { bullet: true } },
    { text: "n（減衰指数）は非線形性が強く、拡張基底が有効", options: { bullet: true } }
  ], {
    x: 0.5, y: 1.3, w: 9, h: 0.9,
    fontSize: 17
  });
  slide.addText("係数の物理的関係", {
    x: 0.4, y: 2.35, w: 9, h: 0.35,
    fontSize: 22, color: "e67e22", bold: true
  });
  slide.addText([
    { text: "速度欠損の減衰パラメータ（c, n）と後流幅の拡大（a₂, a₁, a₀）は強く相関", options: { bullet: true } },
    { text: "乱流強度 I が増加すると後流回復が促進される傾向", options: { bullet: true } },
    { text: "抵抗係数 C が増加すると初期速度欠損が増大", options: { bullet: true } }
  ], {
    x: 0.5, y: 2.75, w: 9, h: 0.9,
    fontSize: 17
  });
  slide.addText("実用性", {
    x: 0.4, y: 3.8, w: 9, h: 0.3,
    fontSize: 22, color: "e67e22", bold: true
  });
  slide.addText([
    { text: "任意の (I, C) に対して即座に後流予測が可能", options: { bullet: true } },
    { text: "高コストなCFDシミュレーションの代替手段として有効", options: { bullet: true } }
  ], {
    x: 0.5, y: 4.15, w: 9, h: 0.6,
    fontSize: 17
  });

  // === Slide 12: Conclusion ===
  slide = pres.addSlide();
  slide.addText("結論と今後の展開", {
    x: 0, y: 0, w: 10, h: 0.6,
    fontSize: 32, color: "FFFFFF", bold: true, fill: "e67e22"
  });
  slide.addText("結論", {
    x: 0.4, y: 0.9, w: 9, h: 0.35,
    fontSize: 22, color: "e67e22", bold: true
  });
  slide.addText([
    { text: "I・C を説明変数とした回帰モデルにより、ガウス型速度欠損モデルの6係数を高精度に予測可能", options: { bullet: true } },
    { text: "31ケースのRANS-PDデータから構築したモデルは全係数でR² > 0.87を達成", options: { bullet: true } },
    { text: "計算コストを大幅に削減しながら実用的な精度で後流予測が可能", options: { bullet: true } }
  ], {
    x: 0.5, y: 1.3, w: 9, h: 1.0,
    fontSize: 18
  });
  slide.addText("応用", {
    x: 0.4, y: 2.45, w: 9, h: 0.35,
    fontSize: 22, color: "e67e22", bold: true
  });
  slide.addText([
    { text: "風力発電所のレイアウト最適化", options: { bullet: true } },
    { text: "年間発電量の高速評価（AEP計算）", options: { bullet: true } },
    { text: "異なる気象条件下での後流干渉評価", options: { bullet: true } }
  ], {
    x: 0.5, y: 2.85, w: 9, h: 0.8,
    fontSize: 17
  });
  slide.addText("今後の課題", {
    x: 0.4, y: 3.8, w: 9, h: 0.3,
    fontSize: 22, color: "e67e22", bold: true
  });
  slide.addText([
    { text: "より広範なパラメータ範囲への拡張", options: { bullet: true } },
    { text: "実測データとの比較検証", options: { bullet: true } }
  ], {
    x: 0.5, y: 4.15, w: 9, h: 0.6,
    fontSize: 17
  });

  // Save presentation
  const outputPath = path.join(__dirname, "..", "gaussian-wake-model.pptx");
  await pres.writeFile({ fileName: outputPath });
  console.log(`\nPresentation saved to: ${outputPath}`);
  console.log("Done!");
}

main().catch(console.error);
