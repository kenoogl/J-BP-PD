#!/usr/bin/env julia
# =========================================================
# I・C を説明変数とした係数回帰モデル
# =========================================================
# fit_coefficients_summary.csv から得られた回帰係数をもとに
# 任意の (I, C) に対するガウスモデル係数を算出する

"""
    ensure_range(I, C)

入力パラメータが実測範囲内かチェックし、範囲外の場合は警告を表示
"""
function ensure_range(I, C)
  I_min, I_max = 0.01, 0.30
  C_min, C_max = 10.0, 25.0

  if I < I_min || I > I_max
    @warn "I=$I is outside the measured range [$I_min, $I_max]. Extrapolation may be inaccurate."
  end
  if C < C_min || C > C_max
    @warn "C=$C is outside the measured range [$C_min, $C_max]. Extrapolation may be inaccurate."
  end
end

"""
    coefficients_from_IC(I, C)

乱流強度 I とポーラスディスク抵抗係数 C から、ガウスモデルの係数を算出

# 引数
- `I::Float64`: 乱流強度（0.01〜0.30）
- `C::Float64`: ポーラスディスク抵抗係数（10〜22）

# 戻り値
NamedTuple: (C0, c, n, a2, a1, a0)
- C(x) = C0 * (1 + c*x)^(-n)
- σ(x) = a2*x² + a1*x + a0

# 回帰モデル
- C0, c, a2, a1, a0: [1, I, C, I·C] の線形結合
- n: [1, I, C, I·C, 1/I, 1/I²] の拡張線形モデル
"""
function coefficients_from_IC(I, C)
  ensure_range(I, C)

  # 線形回帰係数（[1, I, C, I·C] 基底）
  # fit_regression.jl で計算された係数（31ケースから算出）
  # R² 値: C0=0.988, c=0.975, a2=0.950, a1=0.936, a0=0.878, n=0.900

  # C0(I, C) = β0 + β1*I + β2*C + β3*I*C
  β_C0 = [0.0692805337931798, -0.04670611392249189, 0.018432888822356688, -0.01745180556346785]
  C0 = β_C0[1] + β_C0[2]*I + β_C0[3]*C + β_C0[4]*I*C

  # c(I, C) = β0 + β1*I + β2*C + β3*I*C
  β_c = [0.002994460868404853, 1.7544000228057217, -0.0023188120244761056, -0.00827601826792624]
  c = β_c[1] + β_c[2]*I + β_c[3]*C + β_c[4]*I*C

  # a2(I, C) = β0 + β1*I + β2*C + β3*I*C
  β_a2 = [-0.00011847919857459274, -0.003865649215268823, 8.261704634615255e-6, -3.3236256166517975e-5]
  a2 = β_a2[1] + β_a2[2]*I + β_a2[3]*C + β_a2[4]*I*C

  # a1(I, C) = β0 + β1*I + β2*C + β3*I*C
  β_a1 = [0.008558927053734917, 0.15432505478209332, -0.00015632738191434373, 0.0006245155160473183]
  a1 = β_a1[1] + β_a1[2]*I + β_a1[3]*C + β_a1[4]*I*C

  # a0(I, C) = β0 + β1*I + β2*C + β3*I*C
  β_a0 = [0.21445340315333275, 0.24962790509266874, 0.0024430651090351914, -0.005123994882695352]
  a0 = β_a0[1] + β_a0[2]*I + β_a0[3]*C + β_a0[4]*I*C

  # n(I, C) = (β0 + β1*I + β2*C + β3*I*C) + (β4 + β5*C)/I + (β6 + β7*C)/I²
  # 拡張線形モデル: [1, I, C, I·C, 1/I, C/I, 1/I², C/I²]
  β_n = [125.04299825318274, -313.19525805268916, -32.31150581911439, 89.22565337442346, -11.017462368531342, 2.3496854048008524, 0.1249321526728345, -0.019750959331083482]
  n = (β_n[1] + β_n[2]*I + β_n[3]*C + β_n[4]*I*C +
       (β_n[5] + β_n[6]*C)/I +
       (β_n[7] + β_n[8]*C)/(I^2))

  return (C0=C0, c=c, n=n, a2=a2, a1=a1, a0=a0)
end

# =========================================================
# テスト用のコード（このファイルを直接実行した場合）
# =========================================================
if abspath(PROGRAM_FILE) == @__FILE__
  println("Testing coefficient model...")
  println("\nTest case: I=0.05, C=16")
  coeffs = coefficients_from_IC(0.05, 16.0)
  println("  C0  = ", coeffs.C0)
  println("  c   = ", coeffs.c)
  println("  n   = ", coeffs.n)
  println("  a2  = ", coeffs.a2)
  println("  a1  = ", coeffs.a1)
  println("  a0  = ", coeffs.a0)

  println("\nTest case: I=0.01, C=10 (boundary)")
  coeffs = coefficients_from_IC(0.01, 10.0)
  println("  C0  = ", coeffs.C0)
  println("  c   = ", coeffs.c)
  println("  n   = ", coeffs.n)

  println("\nTest case: I=0.35, C=25 (out of range)")
  coeffs = coefficients_from_IC(0.35, 25.0)
  println("  C0  = ", coeffs.C0)
  println("  c   = ", coeffs.c)
  println("  n   = ", coeffs.n)
end
