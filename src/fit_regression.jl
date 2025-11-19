#!/usr/bin/env julia
using CSV, DataFrames, Statistics, LinearAlgebra, Printf

# =========================================================
# fit_coefficients_summary.csv から回帰係数を計算
# =========================================================

"""
    fit_linear_model(X, y)

線形回帰を実行: y = X * β

# 引数
- `X::Matrix`: 設計行列 (n × p)
- `y::Vector`: 目的変数 (n)

# 戻り値
- `β::Vector`: 回帰係数 (p)
- `R²::Float64`: 決定係数
"""
function fit_linear_model(X, y)
  β = X \ y  # 最小二乗解
  y_pred = X * β
  SS_res = sum((y .- y_pred).^2)
  SS_tot = sum((y .- mean(y)).^2)
  R² = 1 - SS_res / SS_tot
  return β, R²
end

"""
    build_design_matrix(I, C, basis_type)

設計行列を構築

# 引数
- `I::Vector`: 乱流強度
- `C::Vector`: ポーラスディスク抵抗係数
- `basis_type::Symbol`: 基底の種類
  - `:linear` → [1, I, C, I·C]
  - `:extended` → [1, I, C, I·C, 1/I, C/I, 1/I², C/I²]

# 戻り値
- `X::Matrix`: 設計行列
"""
function build_design_matrix(I, C, basis_type)
  n = length(I)
  if basis_type == :linear
    X = hcat(ones(n), I, C, I .* C)
  elseif basis_type == :extended
    X = hcat(
      ones(n),
      I,
      C,
      I .* C,
      1 ./ I,
      C ./ I,
      1 ./ (I.^2),
      C ./ (I.^2)
    )
  else
    error("Unknown basis_type: $basis_type")
  end
  return X
end

# =========================================================
# メイン処理
# =========================================================
function main()
  # データ読み込み
  if !isfile("fit_coefficients_summary.csv")
    @error "fit_coefficients_summary.csv not found. Please run fit_gaussian_wake.jl first."
    return
  end

  df = CSV.read("fit_coefficients_summary.csv", DataFrame)
  println("Loaded $(nrow(df)) cases from fit_coefficients_summary.csv")

  # データ抽出
  I = df.I
  C = df.C

  # 各係数に対して回帰を実行
  println("\n" * "="^60)
  println("Linear regression: [1, I, C, I·C]")
  println("="^60)

  X_linear = build_design_matrix(I, C, :linear)

  # C0
  β_C0, R²_C0 = fit_linear_model(X_linear, df.C0)
  println("\nC0(I, C) = $(β_C0[1]) + $(β_C0[2])*I + $(β_C0[3])*C + $(β_C0[4])*I*C")
  println("  R² = $(round(R²_C0, digits=4))")

  # c
  β_c, R²_c = fit_linear_model(X_linear, df.c)
  println("\nc(I, C) = $(β_c[1]) + $(β_c[2])*I + $(β_c[3])*C + $(β_c[4])*I*C")
  println("  R² = $(round(R²_c, digits=4))")

  # a2
  β_a2, R²_a2 = fit_linear_model(X_linear, df.a2)
  println("\na2(I, C) = $(β_a2[1]) + $(β_a2[2])*I + $(β_a2[3])*C + $(β_a2[4])*I*C")
  println("  R² = $(round(R²_a2, digits=4))")

  # a1
  β_a1, R²_a1 = fit_linear_model(X_linear, df.a1)
  println("\na1(I, C) = $(β_a1[1]) + $(β_a1[2])*I + $(β_a1[3])*C + $(β_a1[4])*I*C")
  println("  R² = $(round(R²_a1, digits=4))")

  # a0
  β_a0, R²_a0 = fit_linear_model(X_linear, df.a0)
  println("\na0(I, C) = $(β_a0[1]) + $(β_a0[2])*I + $(β_a0[3])*C + $(β_a0[4])*I*C")
  println("  R² = $(round(R²_a0, digits=4))")

  # n（拡張基底）
  println("\n" * "="^60)
  println("Extended regression for n: [1, I, C, I·C, 1/I, C/I, 1/I², C/I²]")
  println("="^60)

  X_extended = build_design_matrix(I, C, :extended)
  β_n, R²_n = fit_linear_model(X_extended, df.n)
  println("\nn(I, C) = ($(β_n[1]) + $(β_n[2])*I + $(β_n[3])*C + $(β_n[4])*I*C)")
  println("          + ($(β_n[5]) + $(β_n[6])*C)/I")
  println("          + ($(β_n[7]) + $(β_n[8])*C)/I²")
  println("  R² = $(round(R²_n, digits=4))")

  # coeff_model.jl用のコードを出力
  println("\n" * "="^60)
  println("Code for coeff_model.jl:")
  println("="^60)

  println("\n# C0(I, C) = β0 + β1*I + β2*C + β3*I*C")
  println("β_C0 = [$(β_C0[1]), $(β_C0[2]), $(β_C0[3]), $(β_C0[4])]")
  println("C0 = β_C0[1] + β_C0[2]*I + β_C0[3]*C + β_C0[4]*I*C")

  println("\n# c(I, C) = β0 + β1*I + β2*C + β3*I*C")
  println("β_c = [$(β_c[1]), $(β_c[2]), $(β_c[3]), $(β_c[4])]")
  println("c = β_c[1] + β_c[2]*I + β_c[3]*C + β_c[4]*I*C")

  println("\n# a2(I, C) = β0 + β1*I + β2*C + β3*I*C")
  println("β_a2 = [$(β_a2[1]), $(β_a2[2]), $(β_a2[3]), $(β_a2[4])]")
  println("a2 = β_a2[1] + β_a2[2]*I + β_a2[3]*C + β_a2[4]*I*C")

  println("\n# a1(I, C) = β0 + β1*I + β2*C + β3*I*C")
  println("β_a1 = [$(β_a1[1]), $(β_a1[2]), $(β_a1[3]), $(β_a1[4])]")
  println("a1 = β_a1[1] + β_a1[2]*I + β_a1[3]*C + β_a1[4]*I*C")

  println("\n# a0(I, C) = β0 + β1*I + β2*C + β3*I*C")
  println("β_a0 = [$(β_a0[1]), $(β_a0[2]), $(β_a0[3]), $(β_a0[4])]")
  println("a0 = β_a0[1] + β_a0[2]*I + β_a0[3]*C + β_a0[4]*I*C")

  println("\n# n(I, C) = (β0 + β1*I + β2*C + β3*I*C) + (β4 + β5*C)/I + (β6 + β7*C)/I²")
  println("β_n = [$(β_n[1]), $(β_n[2]), $(β_n[3]), $(β_n[4]), $(β_n[5]), $(β_n[6]), $(β_n[7]), $(β_n[8])]")
  println("n = (β_n[1] + β_n[2]*I + β_n[3]*C + β_n[4]*I*C +")
  println("     (β_n[5] + β_n[6]*C)/I +")
  println("     (β_n[7] + β_n[8]*C)/(I^2))")

  # サマリーをファイルに保存
  summary_file = "regression_summary.txt"
  open(summary_file, "w") do io
    println(io, "Regression Summary")
    println(io, "="^60)
    println(io, "Number of cases: $(nrow(df))")
    println(io, "\nCoefficient R² values:")
    println(io, "  C0: $(round(R²_C0, digits=4))")
    println(io, "  c:  $(round(R²_c, digits=4))")
    println(io, "  a2: $(round(R²_a2, digits=4))")
    println(io, "  a1: $(round(R²_a1, digits=4))")
    println(io, "  a0: $(round(R²_a0, digits=4))")
    println(io, "  n:  $(round(R²_n, digits=4))")
  end
  println("\nSaved regression summary to: $summary_file")
end

# 実行
main()
