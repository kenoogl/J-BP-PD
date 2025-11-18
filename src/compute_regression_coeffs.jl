#!/usr/bin/env julia
"""
新しいパラメータ (kw, Ct_eff, sigmaJ0, sigmaG0, km, x_shift) の回帰係数を計算

基底関数:
- 基本: [1, I, C, I·C]
- 拡張 (必要に応じて): [1, I, C, I·C, 1/I, C/I]
"""

using CSV, DataFrames, Statistics, LinearAlgebra, Printf

const CSV_PATH = "fit_coefficients_summary.csv"

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

    return coeffs, r2, rmse
end

function build_design_matrix_basic(I::Vector{Float64}, C::Vector{Float64})
    """基本基底: [1, I, C, I·C]"""
    n = length(I)
    X = hcat(ones(n), I, C, I .* C)
    return X
end

function build_design_matrix_extended(I::Vector{Float64}, C::Vector{Float64})
    """拡張基底: [1, I, C, I·C, 1/I, C/I]"""
    n = length(I)
    X = hcat(ones(n), I, C, I .* C, 1.0 ./ I, C ./ I)
    return X
end

function print_coefficients(name::String, coeffs::Vector{Float64}, r2::Float64, rmse::Float64, basis::String)
    println("\n=== $name ===")
    println("R² = $(round(r2, digits=4)), RMSE = $(round(rmse, digits=6))")

    if basis == "basic"
        labels = ["const", "I", "C", "I·C"]
    elseif basis == "extended"
        labels = ["const", "I", "C", "I·C", "1/I", "C/I"]
    end

    println("係数:")
    for (i, (label, coeff)) in enumerate(zip(labels, coeffs))
        println(@sprintf("  %-8s: %+.8e", label, coeff))
    end
end

function main()
    # データ読み込み
    df = CSV.read(CSV_PATH, DataFrame)
    println("Loaded $(nrow(df)) cases from $CSV_PATH")

    I = df.I
    C = df.Ct

    # 基本基底行列
    X_basic = build_design_matrix_basic(I, C)

    # 拡張基底行列（kw用）
    X_extended = build_design_matrix_extended(I, C)

    # 各パラメータの回帰
    params = [
        ("kw", df.kw, X_extended, "extended"),
        ("Ct_eff", df.Ct_eff, X_basic, "basic"),
        ("sigmaJ0", df.sigmaJ0, X_basic, "basic"),
        ("sigmaG0", df.sigmaG0, X_basic, "basic"),
        ("km", df.km, X_extended, "extended"),
        ("x_shift", df.x_shift, X_basic, "basic")
    ]

    results = Dict{String, Tuple{Vector{Float64}, Float64, Float64, String}}()

    println("\n" * "="^60)
    println("回帰分析結果")
    println("="^60)

    for (name, y, X, basis) in params
        coeffs, r2, rmse = linear_regression(X, y)
        results[name] = (coeffs, r2, rmse, basis)
        print_coefficients(name, coeffs, r2, rmse, basis)
    end

    # Julia形式のコード生成
    println("\n\n" * "="^60)
    println("生成されたJuliaコード (coeff_model.jlに追加)")
    println("="^60)

    for (name, (coeffs, r2, rmse, basis)) in results
        coeffs_name = uppercase(name) * "_COEFFS"

        if basis == "basic"
            println("\n# $name (基本基底: [1, I, C, I·C], R²=$(round(r2, digits=4)))")
            println("const $coeffs_name = (")
            for coeff in coeffs
                println(@sprintf("  %+.8e,", coeff))
            end
            println(")")
        elseif basis == "extended"
            println("\n# $name (拡張基底: [1, I, C, I·C, 1/I, C/I], R²=$(round(r2, digits=4)))")
            println("const $coeffs_name = (")
            for coeff in coeffs
                println(@sprintf("  %+.8e,", coeff))
            end
            println(")")
        end
    end

    # 評価サマリー
    println("\n\n" * "="^60)
    println("回帰精度サマリー")
    println("="^60)
    println(@sprintf("%-12s  %-10s  %-12s  %-12s", "Parameter", "R²", "RMSE", "Basis"))
    println("-"^60)

    for (name, (coeffs, r2, rmse, basis)) in sort(collect(results))
        println(@sprintf("%-12s  %10.4f  %12.6e  %-12s", name, r2, rmse, basis))
    end
end

main()
