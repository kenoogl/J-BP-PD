#!/usr/bin/env julia
# =========================================================
# 計算結果の包括的分析スクリプト
# =========================================================
# fit_coefficients_summary.csv と回帰モデルの結果を詳細に分析

using CSV, DataFrames, Statistics, Plots, LinearAlgebra, Printf, Dates

# coeff_model.jl を読み込み
include("coeff_model.jl")

# =========================================================
# 1. データ読み込みと前処理
# =========================================================
println("="^60)
println("FitGauss-PD 計算結果の包括的分析")
println("="^60)

# データ読み込み
if !isfile("fit_coefficients_summary.csv")
  @error "fit_coefficients_summary.csv not found. Please run fit_gaussian_wake.jl first."
  exit(1)
end

df = CSV.read("fit_coefficients_summary.csv", DataFrame)
println("\nLoaded $(nrow(df)) cases from fit_coefficients_summary.csv")

# =========================================================
# 2. 回帰モデルの予測値を計算
# =========================================================
println("\n" * "="^60)
println("Computing regression model predictions...")
println("="^60)

# 各係数の予測値を計算
df.C0_pred = [coefficients_from_IC(row.I, row.C).C0 for row in eachrow(df)]
df.c_pred = [coefficients_from_IC(row.I, row.C).c for row in eachrow(df)]
df.n_pred = [coefficients_from_IC(row.I, row.C).n for row in eachrow(df)]
df.a2_pred = [coefficients_from_IC(row.I, row.C).a2 for row in eachrow(df)]
df.a1_pred = [coefficients_from_IC(row.I, row.C).a1 for row in eachrow(df)]
df.a0_pred = [coefficients_from_IC(row.I, row.C).a0 for row in eachrow(df)]

# 残差を計算
df.C0_residual = df.C0 .- df.C0_pred
df.c_residual = df.c .- df.c_pred
df.n_residual = df.n .- df.n_pred
df.a2_residual = df.a2 .- df.a2_pred
df.a1_residual = df.a1 .- df.a1_pred
df.a0_residual = df.a0 .- df.a0_pred

# =========================================================
# 3. 決定係数（R²）の計算
# =========================================================
println("\n" * "="^60)
println("Model Performance (R² values)")
println("="^60)

function compute_R2(y_true, y_pred)
  SS_res = sum((y_true .- y_pred).^2)
  SS_tot = sum((y_true .- mean(y_true)).^2)
  return 1 - SS_res / SS_tot
end

coefficients = [:C0, :c, :n, :a2, :a1, :a0]
R2_values = Dict{Symbol, Float64}()

for coef in coefficients
  y_true = df[!, coef]
  y_pred = df[!, Symbol(string(coef) * "_pred")]
  R2 = compute_R2(y_true, y_pred)
  R2_values[coef] = R2
  println(@sprintf("  %s:  R² = %.4f", coef, R2))
end

# =========================================================
# 4. 残差統計
# =========================================================
println("\n" * "="^60)
println("Residual Statistics")
println("="^60)

for coef in coefficients
  residual = df[!, Symbol(string(coef) * "_residual")]
  println("\n$coef:")
  println(@sprintf("  Mean:   %+.6e", mean(residual)))
  println(@sprintf("  Std:     %.6e", std(residual)))
  println(@sprintf("  Max:    %+.6e", maximum(abs.(residual))))
  println(@sprintf("  RMSE:    %.6e", sqrt(mean(residual.^2))))

  # 最大残差のケースを特定
  max_idx = argmax(abs.(residual))
  println(@sprintf("  Max residual case: I=%.2f, C=%.1f (residual=%+.6e)",
                   df[max_idx, :I], df[max_idx, :C], residual[max_idx]))
end

# =========================================================
# 5. 係数間の相関行列
# =========================================================
println("\n" * "="^60)
println("Correlation Matrix (Measured Coefficients)")
println("="^60)

coef_matrix = Matrix(df[:, coefficients])
cor_matrix = cor(coef_matrix)

println("\n        C0      c       n       a2      a1      a0")
for (i, coef) in enumerate(coefficients)
  print(@sprintf("%-4s ", coef))
  for j in 1:length(coefficients)
    print(@sprintf(" %6.3f", cor_matrix[i, j]))
  end
  println()
end

# =========================================================
# 6. 可視化の準備
# =========================================================
println("\n" * "="^60)
println("Generating visualizations...")
println("="^60)

# figures/analysis ディレクトリを作成
if !isdir("figures/analysis")
  mkpath("figures/analysis")
end

gr()

# =========================================================
# 図1: 予測 vs 実測（6パネル）
# =========================================================
println("\n1. Predicted vs Measured plots...")

p = plot(layout=(2,3), size=(1800, 1200), dpi=300)

for (i, coef) in enumerate(coefficients)
  y_true = df[!, coef]
  y_pred = df[!, Symbol(string(coef) * "_pred")]
  R2 = R2_values[coef]

  # 対角線の範囲
  min_val = min(minimum(y_true), minimum(y_pred))
  max_val = max(maximum(y_true), maximum(y_pred))

  scatter!(p[i], y_true, y_pred,
           label="Data (n=$(nrow(df)))",
           xlabel="Measured $coef",
           ylabel="Predicted $coef",
           title="$coef (R²=$(round(R2, digits=4)))",
           markersize=4,
           markercolor=:blue,
           markeralpha=0.6,
           legend=:topleft)

  # 対角線（perfect prediction）
  plot!(p[i], [min_val, max_val], [min_val, max_val],
        label="Perfect fit",
        linecolor=:red,
        linestyle=:dash,
        linewidth=2)
end

savefig(p, "figures/analysis/predicted_vs_measured.png")
println("✅ Saved: figures/analysis/predicted_vs_measured.png")

# =========================================================
# 図2: 残差のI・C依存性（6パネル）
# =========================================================
println("\n2. Residual plots (I and C dependence)...")

# I依存性
p_I = plot(layout=(2,3), size=(1800, 1200), dpi=300)

for (i, coef) in enumerate(coefficients)
  residual = df[!, Symbol(string(coef) * "_residual")]

  scatter!(p_I[i], df.I, residual,
           xlabel="Turbulence Intensity I",
           ylabel="Residual (Measured - Predicted)",
           title="$coef Residual vs I",
           markersize=4,
           markercolor=:blue,
           markeralpha=0.6,
           legend=false)

  hline!(p_I[i], [0], linecolor=:red, linestyle=:dash, linewidth=1)
end

savefig(p_I, "figures/analysis/residual_vs_I.png")
println("✅ Saved: figures/analysis/residual_vs_I.png")

# C依存性
p_C = plot(layout=(2,3), size=(1800, 1200), dpi=300)

for (i, coef) in enumerate(coefficients)
  residual = df[!, Symbol(string(coef) * "_residual")]

  scatter!(p_C[i], df.C, residual,
           xlabel="Porous Disk Resistance Coefficient C",
           ylabel="Residual (Measured - Predicted)",
           title="$coef Residual vs C",
           markersize=4,
           markercolor=:blue,
           markeralpha=0.6,
           legend=false)

  hline!(p_C[i], [0], linecolor=:red, linestyle=:dash, linewidth=1)
end

savefig(p_C, "figures/analysis/residual_vs_C.png")
println("✅ Saved: figures/analysis/residual_vs_C.png")

# =========================================================
# 図3: 係数のI・C依存性（各係数について2プロット）
# =========================================================
println("\n3. Coefficient trends (I and C dependence)...")

for coef in coefficients
  p_trend = plot(layout=(1,2), size=(1600, 600), dpi=300)

  # I依存性（C固定）
  C_fixed = 16.0
  I_range = range(0.01, 0.30, length=100)
  y_model = [coefficients_from_IC(I, C_fixed)[coef] for I in I_range]

  # 実測データ（C≈16）
  df_C16 = df[abs.(df.C .- C_fixed) .< 2.0, :]

  plot!(p_trend[1], I_range, y_model,
        label="Regression model (C=$C_fixed)",
        linecolor=:blue,
        linewidth=2,
        xlabel="Turbulence Intensity I",
        ylabel=string(coef),
        title="$coef vs I (C=$C_fixed fixed)")

  scatter!(p_trend[1], df_C16.I, df_C16[!, coef],
           label="Measured data",
           markersize=5,
           markercolor=:red,
           markeralpha=0.6)

  # C依存性（I固定）
  I_fixed = 0.10
  C_range = range(10.0, 25.0, length=100)
  y_model = [coefficients_from_IC(I_fixed, C)[coef] for C in C_range]

  # 実測データ（I≈0.10）
  df_I10 = df[abs.(df.I .- I_fixed) .< 0.05, :]

  plot!(p_trend[2], C_range, y_model,
        label="Regression model (I=$I_fixed)",
        linecolor=:blue,
        linewidth=2,
        xlabel="Porous Disk Resistance Coefficient C",
        ylabel=string(coef),
        title="$coef vs C (I=$I_fixed fixed)")

  scatter!(p_trend[2], df_I10.C, df_I10[!, coef],
           label="Measured data",
           markersize=5,
           markercolor=:red,
           markeralpha=0.6)

  savefig(p_trend, "figures/analysis/trend_$(coef).png")
  println("✅ Saved: figures/analysis/trend_$(coef).png")
end

# =========================================================
# 図4: 2D等高線図（I-C平面）
# =========================================================
println("\n4. 2D contour plots (I-C plane)...")

I_grid = range(0.01, 0.30, length=50)
C_grid = range(10.0, 25.0, length=50)

for coef in coefficients
  # グリッド上で係数を計算
  Z = [coefficients_from_IC(I, C)[coef] for C in C_grid, I in I_grid]

  contourf(I_grid, C_grid, Z,
           xlabel="Turbulence Intensity I",
           ylabel="Porous Disk Resistance Coefficient C",
           title="$coef (I-C plane)",
           colorbar_title=string(coef),
           levels=20,
           size=(900, 700),
           dpi=300,
           c=:viridis)

  # 実測点をプロット
  scatter!(df.I, df.C,
           label="Measured cases (n=$(nrow(df)))",
           markersize=6,
           markercolor=:white,
           markerstrokecolor=:black,
           markerstrokewidth=2,
           legend=:topright)

  savefig("figures/analysis/contour_$(coef).png")
  println("✅ Saved: figures/analysis/contour_$(coef).png")
end

# =========================================================
# 図5: 速度欠損プロファイルの比較
# =========================================================
println("\n5. Velocity deficit profile comparison...")

# 特定ケースを選択（I=0.05, C=16）
I_test = 0.05
C_test = 16.0

# CSVから実測値を取得
row_idx = findfirst((df.I .== I_test) .& (df.C .== C_test))

if row_idx !== nothing
  # CSV実測値
  C0_csv = df[row_idx, :C0]
  c_csv = df[row_idx, :c]
  n_csv = df[row_idx, :n]
  a2_csv = df[row_idx, :a2]
  a1_csv = df[row_idx, :a1]
  a0_csv = df[row_idx, :a0]

  # 回帰モデル予測値
  coeffs_model = coefficients_from_IC(I_test, C_test)

  # x位置
  x_positions = [2.0, 5.0, 10.0, 15.0]
  r_range = range(-5, 5, length=100)

  p_profile = plot(layout=(2,2), size=(1600, 1200), dpi=300, legend=:bottomright)

  for (i, x_pos) in enumerate(x_positions)
    # CSV値での速度欠損係数
    C_csv = C0_csv * (1 + c_csv * x_pos)^(-n_csv)
    σ_csv = a2_csv * x_pos^2 + a1_csv * x_pos + a0_csv

    # モデル値での速度欠損係数
    C_model = coeffs_model.C0 * (1 + coeffs_model.c * x_pos)^(-coeffs_model.n)
    σ_model = coeffs_model.a2 * x_pos^2 + coeffs_model.a1 * x_pos + coeffs_model.a0

    # 速度欠損プロファイル（正規化: ΔU/U∞）
    ΔU_csv = [C_csv * exp(-r^2 / (2 * σ_csv^2)) for r in r_range]
    ΔU_model = [C_model * exp(-r^2 / (2 * σ_model^2)) for r in r_range]

    plot!(p_profile[i], r_range, ΔU_csv,
          label="CSV (measured fit)",
          linecolor=:blue,
          linewidth=2,
          xlabel="Radial distance r",
          ylabel="Velocity deficit ΔU/U∞",
          title="x = $(x_pos)D (I=$I_test, C=$C_test)")

    plot!(p_profile[i], r_range, ΔU_model,
          label="Regression model",
          linecolor=:red,
          linestyle=:dash,
          linewidth=2)
  end

  savefig(p_profile, "figures/analysis/velocity_deficit_profile_I$(I_test)_C$(C_test).png")
  println("✅ Saved: figures/analysis/velocity_deficit_profile_I$(I_test)_C$(C_test).png")
else
  @warn "Test case I=$I_test, C=$C_test not found in data"
end

# =========================================================
# 7. 分析レポートの出力
# =========================================================
println("\n" * "="^60)
println("Writing analysis report...")
println("="^60)

report_file = "analysis_report.txt"
open(report_file, "w") do io
  println(io, "="^60)
  println(io, "FitGauss-PD Analysis Report")
  println(io, "="^60)
  println(io, "\nGenerated: $(now())")
  println(io, "Number of cases: $(nrow(df))")
  println(io, "I range: $(minimum(df.I)) - $(maximum(df.I))")
  println(io, "C range: $(minimum(df.C)) - $(maximum(df.C))")

  println(io, "\n" * "="^60)
  println(io, "1. Model Performance (R² values)")
  println(io, "="^60)
  for coef in coefficients
    println(io, @sprintf("  %-4s: R² = %.4f", coef, R2_values[coef]))
  end

  println(io, "\n" * "="^60)
  println(io, "2. Residual Statistics")
  println(io, "="^60)
  for coef in coefficients
    residual = df[!, Symbol(string(coef) * "_residual")]
    println(io, "\n$coef:")
    println(io, @sprintf("  Mean:   %+.6e", mean(residual)))
    println(io, @sprintf("  Std:     %.6e", std(residual)))
    println(io, @sprintf("  Max:    %+.6e", maximum(abs.(residual))))
    println(io, @sprintf("  RMSE:    %.6e", sqrt(mean(residual.^2))))
  end

  println(io, "\n" * "="^60)
  println(io, "3. Correlation Matrix (Measured Coefficients)")
  println(io, "="^60)
  println(io, "\n        C0      c       n       a2      a1      a0")
  for (i, coef) in enumerate(coefficients)
    print(io, @sprintf("%-4s ", coef))
    for j in 1:length(coefficients)
      print(io, @sprintf(" %6.3f", cor_matrix[i, j]))
    end
    println(io)
  end

  println(io, "\n" * "="^60)
  println(io, "4. Key Findings")
  println(io, "="^60)

  # 最良・最悪のR²
  best_coef = coefficients[argmax([R2_values[c] for c in coefficients])]
  worst_coef = coefficients[argmin([R2_values[c] for c in coefficients])]

  println(io, "\n- Best prediction accuracy:  $best_coef (R² = $(round(R2_values[best_coef], digits=4)))")
  println(io, "- Worst prediction accuracy: $worst_coef (R² = $(round(R2_values[worst_coef], digits=4)))")

  # 強い相関
  println(io, "\n- Strong correlations (|r| > 0.7):")
  for i in 1:length(coefficients)
    for j in (i+1):length(coefficients)
      if abs(cor_matrix[i, j]) > 0.7
        println(io, @sprintf("  %s - %s: r = %.3f",
                             coefficients[i], coefficients[j], cor_matrix[i, j]))
      end
    end
  end

  println(io, "\n" * "="^60)
  println(io, "5. Generated Figures")
  println(io, "="^60)
  println(io, "\n- figures/analysis/predicted_vs_measured.png")
  println(io, "- figures/analysis/residual_vs_I.png")
  println(io, "- figures/analysis/residual_vs_C.png")
  println(io, "- figures/analysis/trend_*.png (6 files)")
  println(io, "- figures/analysis/contour_*.png (6 files)")
  println(io, "- figures/analysis/velocity_deficit_profile_*.png")
end

println("✅ Saved: $report_file")

println("\n" * "="^60)
println("✅ Analysis completed!")
println("="^60)
println("\nGenerated $(6*2 + 3 + 1) figures in figures/analysis/")
println("Report saved to: $report_file")
