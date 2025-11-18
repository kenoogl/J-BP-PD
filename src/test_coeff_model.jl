#!/usr/bin/env julia
"""
coeff_model.jlの新しい二領域モデル関数をテスト
"""

using Printf
include("coeff_model.jl")
using .CoeffModel

println("="^60)
println("coefficients_two_region 関数のテスト")
println("="^60)

# テストケース
test_cases = [
    (0.01, 10.0, "低I・低C"),
    (0.05, 16.0, "中I・中C"),
    (0.30, 22.0, "高I・高C"),
    (0.15, 19.0, "ランダム1"),
    (0.005, 25.0, "範囲外テスト（I<0.01, C>22）"),
]

for (I, C, label) in test_cases
    println("\n--- $label (I=$I, C=$C) ---")

    # 二領域モデル
    params = coefficients_two_region(I, C; check_range=true)

    println(@sprintf("kw      = %.6f", params.kw))
    println(@sprintf("Ct_eff  = %.6f", params.Ct_eff))
    println(@sprintf("sigmaJ0 = %.6f", params.sigmaJ0))
    println(@sprintf("sigmaG0 = %.6f", params.sigmaG0))
    println(@sprintf("km      = %.6f", params.km))
    println(@sprintf("x_shift = %.6f", params.x_shift))

    # 物理的妥当性チェック
    checks = []
    push!(checks, ("kw ≥ 0", params.kw >= 0.0))
    push!(checks, ("0 ≤ Ct_eff ≤ 1", 0.0 <= params.Ct_eff <= 1.0))
    push!(checks, ("sigmaJ0 > 0", params.sigmaJ0 > 0.0))
    push!(checks, ("sigmaG0 > 0", params.sigmaG0 > 0.0))
    push!(checks, ("km ≥ 0", params.km >= 0.0))
    push!(checks, ("x_shift > 0", params.x_shift > 0.0))

    all_ok = all(x[2] for x in checks)
    if all_ok
        println("✓ 物理的制約すべて満たす")
    else
        println("⚠ 物理的制約違反:")
        for (check, ok) in checks
            !ok && println("  ✗ $check")
        end
    end
end

# CSVデータとの比較
println("\n\n" * "="^60)
println("CSV実測値との比較（サンプル5ケース）")
println("="^60)

using CSV, DataFrames
df = CSV.read("fit_coefficients_summary.csv", DataFrame)

sample_indices = [1, 8, 15, 22, 29]  # 各I範囲から1つずつ

println(@sprintf("\n%-6s %-6s %-12s %-12s %-12s %-12s %-12s %-12s",
    "I", "C", "kw", "Ct_eff", "sigmaJ0", "sigmaG0", "km", "x_shift"))
println("-"^90)

total_errors = Dict("kw"=>0.0, "Ct_eff"=>0.0, "sigmaJ0"=>0.0,
                    "sigmaG0"=>0.0, "km"=>0.0, "x_shift"=>0.0)

for idx in sample_indices
    I = df.I[idx]
    C = df.Ct[idx]

    # 回帰モデルからの予測
    pred = coefficients_two_region(I, C; check_range=false)

    # CSVからの実測値
    actual_kw = df.kw[idx]
    actual_Ct_eff = df.Ct_eff[idx]
    actual_sigmaJ0 = df.sigmaJ0[idx]
    actual_sigmaG0 = df.sigmaG0[idx]
    actual_km = df.km[idx]
    actual_x_shift = df.x_shift[idx]

    println(@sprintf("%-6.2f %-6.1f", I, C))
    println(@sprintf("  予測: %-12.6f %-12.6f %-12.6f %-12.6f %-12.6f %-12.2f",
        pred.kw, pred.Ct_eff, pred.sigmaJ0, pred.sigmaG0, pred.km, pred.x_shift))
    println(@sprintf("  実測: %-12.6f %-12.6f %-12.6f %-12.6f %-12.6f %-12.2f",
        actual_kw, actual_Ct_eff, actual_sigmaJ0, actual_sigmaG0, actual_km, actual_x_shift))

    # 誤差
    err_kw = abs(pred.kw - actual_kw)
    err_Ct_eff = abs(pred.Ct_eff - actual_Ct_eff)
    err_sigmaJ0 = abs(pred.sigmaJ0 - actual_sigmaJ0)
    err_sigmaG0 = abs(pred.sigmaG0 - actual_sigmaG0)
    err_km = abs(pred.km - actual_km)
    err_x_shift = abs(pred.x_shift - actual_x_shift)

    println(@sprintf("  誤差: %-12.6f %-12.6f %-12.6f %-12.6f %-12.6f %-12.2f",
        err_kw, err_Ct_eff, err_sigmaJ0, err_sigmaG0, err_km, err_x_shift))

    total_errors["kw"] += err_kw
    total_errors["Ct_eff"] += err_Ct_eff
    total_errors["sigmaJ0"] += err_sigmaJ0
    total_errors["sigmaG0"] += err_sigmaG0
    total_errors["km"] += err_km
    total_errors["x_shift"] += err_x_shift

    println()
end

println("\n平均絶対誤差 (サンプル5ケース):")
n = length(sample_indices)
for (param, total_err) in sort(collect(total_errors))
    println(@sprintf("  %-12s: %.6f", param, total_err / n))
end

println("\n" * "="^60)
println("テスト完了")
println("="^60)
