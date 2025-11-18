#!/usr/bin/env julia
"""
x_shift 回帰精度改善案の比較検証

案1: 非線形基底（拡張基底: [1, I, C, I·C, 1/I, C/I]）
案2: 区分モデル（I<0.1 とそれ以外で別回帰）

使用法:
  julia --project=. src/compare_xshift_models.jl
"""

using CSV, DataFrames, Statistics, LinearAlgebra, Printf

const CSV_PATH = "fit_coefficients_summary.csv"
const I_SPLIT = 0.1  # 区分モデルの閾値

# =============================================================================
# 回帰関数
# =============================================================================

function linear_regression(X::Matrix{Float64}, y::Vector{Float64})
  """最小二乗法による線形回帰"""
  coeffs = X \ y
  y_pred = X * coeffs
  residuals = y .- y_pred

  # 評価指標
  ss_res = sum(residuals.^2)
  ss_tot = sum((y .- mean(y)).^2)
  r2 = 1 - ss_res / ss_tot
  rmse = sqrt(mean(residuals.^2))

  return coeffs, y_pred, r2, rmse
end

# =============================================================================
# 案1: 非線形基底（拡張基底）
# =============================================================================

function build_extended_matrix(I::Vector{Float64}, C::Vector{Float64})
  """拡張基底: [1, I, C, I·C, 1/I, C/I]"""
  n = length(I)
  return hcat(ones(n), I, C, I .* C, 1.0 ./ I, C ./ I)
end

function fit_extended_model(I, C, y)
  """案1: 拡張基底による回帰"""
  X = build_extended_matrix(I, C)
  coeffs, y_pred, r2, rmse = linear_regression(X, y)
  return coeffs, y_pred, r2, rmse
end

function predict_extended(I_val, C_val, coeffs)
  """拡張基底による予測"""
  return coeffs[1] + coeffs[2]*I_val + coeffs[3]*C_val +
         coeffs[4]*I_val*C_val + coeffs[5]/I_val + coeffs[6]*C_val/I_val
end

# =============================================================================
# 案2: 区分モデル（I<0.1で分割）
# =============================================================================

function build_basic_matrix(I::Vector{Float64}, C::Vector{Float64})
  """基本基底: [1, I, C, I·C]"""
  n = length(I)
  return hcat(ones(n), I, C, I .* C)
end

function fit_piecewise_model(I, C, y; split=I_SPLIT)
  """案2: 区分モデルによる回帰"""
  # 低乱流域（I < split）
  low_mask = I .< split
  I_low = I[low_mask]
  C_low = C[low_mask]
  y_low = y[low_mask]

  X_low = build_basic_matrix(I_low, C_low)
  coeffs_low, _, r2_low, rmse_low = linear_regression(X_low, y_low)

  # 高乱流域（I >= split）
  high_mask = .!low_mask
  I_high = I[high_mask]
  C_high = C[high_mask]
  y_high = y[high_mask]

  X_high = build_basic_matrix(I_high, C_high)
  coeffs_high, _, r2_high, rmse_high = linear_regression(X_high, y_high)

  # 全体の予測値と評価指標
  y_pred = zeros(length(I))
  for i in eachindex(I)
    y_pred[i] = predict_piecewise(I[i], C[i], coeffs_low, coeffs_high, split)
  end

  residuals = y .- y_pred
  ss_res = sum(residuals.^2)
  ss_tot = sum((y .- mean(y)).^2)
  r2 = 1 - ss_res / ss_tot
  rmse = sqrt(mean(residuals.^2))

  return (coeffs_low, coeffs_high), y_pred, r2, rmse, (r2_low, r2_high, rmse_low, rmse_high)
end

function predict_piecewise(I_val, C_val, coeffs_low, coeffs_high, split)
  """区分モデルによる予測"""
  coeffs = I_val < split ? coeffs_low : coeffs_high
  return coeffs[1] + coeffs[2]*I_val + coeffs[3]*C_val + coeffs[4]*I_val*C_val
end

# =============================================================================
# 比較・評価
# =============================================================================

function print_comparison(name, r2, rmse, coeffs, basis_name)
  """結果の表示"""
  println("\n" * "="^70)
  println("$name")
  println("="^70)
  println(@sprintf("R² = %.4f, RMSE = %.4f", r2, rmse))
  println("\n係数 ($basis_name):")

  if basis_name == "拡張基底 [1, I, C, I·C, 1/I, C/I]"
    labels = ["const", "I", "C", "I·C", "1/I", "C/I"]
    for (label, coeff) in zip(labels, coeffs)
      println(@sprintf("  %-8s: %+.8e", label, coeff))
    end
  elseif startswith(basis_name, "基本基底")
    labels = ["const", "I", "C", "I·C"]
    for (label, coeff) in zip(labels, coeffs)
      println(@sprintf("  %-8s: %+.8e", label, coeff))
    end
  end
end

function analyze_residuals(y_true, y_pred, I, name)
  """残差分析"""
  residuals = y_true .- y_pred

  println("\n残差分析 ($name):")
  println(@sprintf("  平均残差: %+.4f", mean(residuals)))
  println(@sprintf("  最大残差: %+.4f", maximum(abs.(residuals))))
  println(@sprintf("  標準偏差: %.4f", std(residuals)))

  # I範囲別の精度
  low_mask = I .< I_SPLIT
  if sum(low_mask) > 0
    rmse_low = sqrt(mean(residuals[low_mask].^2))
    println(@sprintf("  RMSE (I<%.2f): %.4f", I_SPLIT, rmse_low))
  end
  if sum(.!low_mask) > 0
    rmse_high = sqrt(mean(residuals[.!low_mask].^2))
    println(@sprintf("  RMSE (I≥%.2f): %.4f", I_SPLIT, rmse_high))
  end
end

# =============================================================================
# メイン処理
# =============================================================================

function main()
  # データ読み込み
  df = CSV.read(CSV_PATH, DataFrame)
  println("="^70)
  println("x_shift 回帰精度改善案の比較")
  println("="^70)
  println("データ: $CSV_PATH ($(nrow(df)) cases)")
  println("区分モデル閾値: I = $I_SPLIT")

  I = Float64.(df.I)
  C = Float64.(df.Ct)
  y = Float64.(df.x_shift)

  # 現状（基本基底）の性能
  println("\n" * "="^70)
  println("【参考】現在のモデル（基本基底）")
  println("="^70)
  X_basic = build_basic_matrix(I, C)
  coeffs_basic, y_pred_basic, r2_basic, rmse_basic = linear_regression(X_basic, y)
  println(@sprintf("R² = %.4f, RMSE = %.4f", r2_basic, rmse_basic))

  # 案1: 非線形基底
  coeffs_ext, y_pred_ext, r2_ext, rmse_ext = fit_extended_model(I, C, y)
  print_comparison("【案1】非線形基底（拡張基底）", r2_ext, rmse_ext, coeffs_ext, "拡張基底 [1, I, C, I·C, 1/I, C/I]")
  analyze_residuals(y, y_pred_ext, I, "案1")

  # 案2: 区分モデル
  (coeffs_low, coeffs_high), y_pred_pw, r2_pw, rmse_pw, (r2_low, r2_high, rmse_low, rmse_high) = fit_piecewise_model(I, C, y)

  println("\n" * "="^70)
  println("【案2】区分モデル（I < $I_SPLIT で分割）")
  println("="^70)
  println(@sprintf("全体: R² = %.4f, RMSE = %.4f", r2_pw, rmse_pw))
  println(@sprintf("\n低乱流域（I<%.2f）: R² = %.4f, RMSE = %.4f", I_SPLIT, r2_low, rmse_low))
  println("係数 (基本基底 [1, I, C, I·C]):")
  labels = ["const", "I", "C", "I·C"]
  for (label, coeff) in zip(labels, coeffs_low)
    println(@sprintf("  %-8s: %+.8e", label, coeff))
  end

  println(@sprintf("\n高乱流域（I≥%.2f）: R² = %.4f, RMSE = %.4f", I_SPLIT, r2_high, rmse_high))
  println("係数 (基本基底 [1, I, C, I·C]):")
  for (label, coeff) in zip(labels, coeffs_high)
    println(@sprintf("  %-8s: %+.8e", label, coeff))
  end

  analyze_residuals(y, y_pred_pw, I, "案2")

  # 比較サマリー
  println("\n\n" * "="^70)
  println("📊 改善案比較サマリー")
  println("="^70)
  println(@sprintf("%-20s  %10s  %12s  %12s", "モデル", "R²", "RMSE", "改善率(RMSE)"))
  println("-"^70)
  println(@sprintf("%-20s  %10.4f  %12.4f  %12s", "現在（基本基底）", r2_basic, rmse_basic, "—"))

  improvement_ext = (rmse_basic - rmse_ext) / rmse_basic * 100
  println(@sprintf("%-20s  %10.4f  %12.4f  %11.1f%%", "案1: 非線形基底", r2_ext, rmse_ext, improvement_ext))

  improvement_pw = (rmse_basic - rmse_pw) / rmse_basic * 100
  println(@sprintf("%-20s  %10.4f  %12.4f  %11.1f%%", "案2: 区分モデル", r2_pw, rmse_pw, improvement_pw))

  # 推奨
  println("\n" * "="^70)
  println("🎯 推奨案")
  println("="^70)

  if r2_ext >= r2_pw && rmse_ext <= rmse_pw
    println("【案1: 非線形基底】を推奨")
    println("理由:")
    println("  - 最高精度（R² = $(round(r2_ext, digits=4)), RMSE = $(round(rmse_ext, digits=4))）")
    println("  - 実装がシンプル（単一モデル）")
    println("  - 既存の extended_combo 関数を利用可能")
  elseif r2_pw > r2_ext || (r2_pw >= 0.96 && rmse_pw < rmse_basic * 0.3)
    println("【案2: 区分モデル】を推奨")
    println("理由:")
    println("  - 高精度（R² = $(round(r2_pw, digits=4)), RMSE = $(round(rmse_pw, digits=4))）")
    println("  - 物理的解釈が明確（低乱流/高乱流を分離）")
    println("  - 各区間で係数の意味が直感的")
  else
    println("【案1: 非線形基底】を推奨")
    println("理由:")
    println("  - わずかに高精度")
    println("  - 実装の複雑さが低い")
  end

  # Julia コード生成
  println("\n\n" * "="^70)
  println("📝 coeff_model.jl に追加するコード")
  println("="^70)

  println("\n# --- 案1: 非線形基底 ---")
  println("# x_shift: 拡張基底 [1, I, C, I·C, 1/I, C/I] (R²=$(round(r2_ext, digits=4)))")
  println("const X_SHIFT_COEFFS = (")
  for coeff in coeffs_ext
    println(@sprintf("  %+.8e,", coeff))
  end
  println(")")
  println("\n# coefficients_two_region 関数内で:")
  println("x_shift = extended_combo(X_SHIFT_COEFFS, I_val, Ct_val)")

  println("\n\n# --- 案2: 区分モデル ---")
  println("# x_shift: 区分モデル (I<$I_SPLIT) (全体R²=$(round(r2_pw, digits=4)))")
  println("const I_SPLIT_XSHIFT = $I_SPLIT")
  println("const X_SHIFT_COEFFS_LOW = (")
  for coeff in coeffs_low
    println(@sprintf("  %+.8e,", coeff))
  end
  println(")")
  println("const X_SHIFT_COEFFS_HIGH = (")
  for coeff in coeffs_high
    println(@sprintf("  %+.8e,", coeff))
  end
  println(")")
  println("\n# 新しい関数を追加:")
  println("function piecewise_combo(coeffs_low, coeffs_high, I, Ct, split)")
  println("  coeffs = I < split ? coeffs_low : coeffs_high")
  println("  return coeffs[1] + coeffs[2]*I + coeffs[3]*Ct + coeffs[4]*I*Ct")
  println("end")
  println("\n# coefficients_two_region 関数内で:")
  println("x_shift = piecewise_combo(X_SHIFT_COEFFS_LOW, X_SHIFT_COEFFS_HIGH, I_val, Ct_val, I_SPLIT_XSHIFT)")
end

main()
