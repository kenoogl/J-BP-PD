#!/usr/bin/env julia
using CSV, DataFrames, Statistics, Printf, Plots

include(joinpath(@__DIR__, "coeff_model.jl"))
using .CoeffModel

const DATA_DIR = "data"
const FIG_DIR = "figures"
const SUMMARY_PATH = "fit_coefficients_summary.csv"
const DEFAULT_I_TOKEN = "0p0100"
const DEFAULT_C_TOKEN = "10p0000"
const CASE_PATTERN = r"result_I(\d+p\d+)_C(\d+p\d+)\.csv"
const COEF_MODE_ANALYTIC = :analytic
const COEF_MODE_SUMMARY = :summary
const WAKE_MODEL_SINGLE_GAUSS = :single_gauss
const WAKE_MODEL_TWO_REGION = :two_region

token_to_value(token::AbstractString) = parse(Float64, replace(token, "p" => "."))

function format_case_token(value::AbstractString; digits::Int=4)
    occursin("p", value) ? value : replace(@sprintf("%.*f", digits, parse(Float64, value)), "." => "p")
end

function parse_tokens_from_path(path::AbstractString)
    m = match(CASE_PATTERN, basename(path))
    return isnothing(m) ? nothing : (m.captures[1], m.captures[2])
end

function discover_cases()
    isdir(DATA_DIR) || error("DATA_DIR=$(DATA_DIR) が存在しません。")
    files = readdir(DATA_DIR; join=true)
    matches = Tuple{String,String,String}[]
    for f in files
        tokens = parse_tokens_from_path(f)
        tokens === nothing && continue
        push!(matches, (f, tokens[1], tokens[2]))
    end
    sort!(matches; by = x -> x[1])
    matches
end

function parse_cli_args()
    coef_mode = COEF_MODE_ANALYTIC
    wake_model = WAKE_MODEL_TWO_REGION  # デフォルトは二領域モデル
    dataset_args = String[]
    for arg in ARGS
        if arg in ("--summary", "-s")
            coef_mode = COEF_MODE_SUMMARY
        elseif arg in ("--analytic", "--model")
            coef_mode = COEF_MODE_ANALYTIC
        elseif arg in ("--two-region", "--two")
            wake_model = WAKE_MODEL_TWO_REGION
        elseif arg in ("--single-gauss", "--single")
            wake_model = WAKE_MODEL_SINGLE_GAUSS
        else
            push!(dataset_args, arg)
        end
    end
    return coef_mode, wake_model, dataset_args
end

function resolve_dataset_targets(dataset_args::Vector{String})
    if !isempty(dataset_args) && (dataset_args[1] in ("--all", "-a", "all"))
        cases = discover_cases()
        isempty(cases) && error("data/ に対象 CSV がありません。")
        println("Reconstructing all cases (", length(cases), " files).")
        return cases
    elseif isempty(dataset_args)
        path = joinpath(DATA_DIR, "result_I$(DEFAULT_I_TOKEN)_C$(DEFAULT_C_TOKEN).csv")
        return [(path, DEFAULT_I_TOKEN, DEFAULT_C_TOKEN)]
    elseif length(dataset_args) == 1
        arg = dataset_args[1]
        path = if occursin("/", arg) || endswith(lowercase(arg), ".csv")
            arg
        elseif startswith(arg, "result_")
            joinpath(DATA_DIR, arg)
        else
            error("I/C 指定か CSV ファイル、または --all を指定してください。")
        end
        tokens = parse_tokens_from_path(path)
        tokens === nothing && error("ファイル名から I/C を特定できません。")
        return [(path, tokens[1], tokens[2])]
    else
        I_token = format_case_token(dataset_args[1])
        C_token = format_case_token(dataset_args[2])
        path = joinpath(DATA_DIR, "result_I$(I_token)_C$(C_token).csv")
        return [(path, I_token, C_token)]
    end
end

function load_summary()
    isfile(SUMMARY_PATH) || error("$(SUMMARY_PATH) が見つかりません。先に fit_gaussian_wake.jl を実行してください。")
    CSV.read(SUMMARY_PATH, DataFrame)
end

function lookup_coefficients(summary_df::DataFrame, I_val::Float64, Ct_val::Float64)
    row = findfirst(r -> isapprox(r.I, I_val; atol=1e-8) && isapprox(r.Ct, Ct_val; atol=1e-8), eachrow(summary_df))
    row === nothing && error(@sprintf("Summary に (I=%.4f, C=%.4f) が見つかりません。", I_val, Ct_val))
    r = summary_df[row, :]
    return (
        C0 = r.C0,
        c = r.c,
        n = r.n,
        a2 = r.a2,
        a1 = r.a1,
        a0 = r.a0
    )
end

function lookup_two_region_coefficients(summary_df::DataFrame, I_val::Float64, Ct_val::Float64)
    row = findfirst(r -> isapprox(r.I, I_val; atol=1e-8) && isapprox(r.Ct, Ct_val; atol=1e-8), eachrow(summary_df))
    row === nothing && error(@sprintf("Summary に (I=%.4f, C=%.4f) が見つかりません。", I_val, Ct_val))
    r = summary_df[row, :]
    return (
        kw = r.kw,
        Ct_eff = r.Ct_eff,
        sigmaJ0 = r.sigmaJ0,
        sigmaG0 = r.sigmaG0,
        km = r.km,
        x_shift = r.x_shift
    )
end

# =============================================================================
# 二領域モデル関数
# =============================================================================

"""
    compute_jensen_deficit(x, kw, Ct_eff)

Jensen領域の中心線速度欠損を計算

数式: ΔU/U∞ = 1 - √{1 - Ct_eff/(1 + 2*kw*x)²}
"""
function compute_jensen_deficit(x::Real, kw::Real, Ct_eff::Real)
    denominator = 1 + 2 * kw * x
    ratio = Ct_eff / (denominator^2)
    # 物理的制約: 0 <= ratio < 1
    ratio = clamp(ratio, 0.0, 0.99)
    return 1 - sqrt(1 - ratio)
end

"""
    compute_jensen_sigma(x, sigmaJ0, kw)

Jensen領域のσ(x)を計算

数式: σ(x) = sigmaJ0 + 2*kw*x
"""
function compute_jensen_sigma(x::Real, sigmaJ0::Real, kw::Real)
    return sigmaJ0 + 2 * kw * x
end

"""
    compute_bastankhah_deficit(sigma, Ct_eff)

Bastankhah領域の中心線速度欠損を計算

数式: ΔU/U∞ = 1 - √{1 - Ct_eff/(8*(σ/D)²)}
ここでD=1（正規化済み）
"""
function compute_bastankhah_deficit(sigma::Real, Ct_eff::Real)
    ratio = Ct_eff / (8 * sigma^2)
    # 物理的制約: 0 <= ratio < 1
    ratio = clamp(ratio, 0.0, 0.99)
    return 1 - sqrt(1 - ratio)
end

"""
    compute_bastankhah_sigma(x, x_shift, sigmaG0, km)

Bastankhah領域のσ(x)を計算

数式: σ(x) = sigmaG0 + km*(x - x_shift)
"""
function compute_bastankhah_sigma(x::Real, x_shift::Real, sigmaG0::Real, km::Real)
    return sigmaG0 + km * (x - x_shift)
end

"""
    compute_two_region_wake(x, r, params, U∞)

二領域モデルで速度場を計算

Parameters:
- x: 下流距離
- r: 半径方向距離
- params: (kw, Ct_eff, sigmaJ0, sigmaG0, km, x_shift)
- U∞: 自由流速度

Returns: u(x, r)
"""
function compute_two_region_wake(x::Real, r::Real, params::NamedTuple, U∞::Real)
    (; kw, Ct_eff, sigmaJ0, sigmaG0, km, x_shift) = params

    if x < x_shift
        # Jensen領域
        ΔU_centerline = compute_jensen_deficit(x, kw, Ct_eff)
        σ = compute_jensen_sigma(x, sigmaJ0, kw)
    else
        # Bastankhah領域
        σ = compute_bastankhah_sigma(x, x_shift, sigmaG0, km)
        ΔU_centerline = compute_bastankhah_deficit(σ, Ct_eff)
    end

    # ガウス分布で径方向に減衰
    ΔU = ΔU_centerline * exp(-r^2 / (2 * σ^2))

    return U∞ * (1 - ΔU)
end

"""
    create_two_region_analysis_plots(df, U∞, params, xv, case_label, fig_dir)

二領域モデルの詳細解析プロットを作成

生成される図:
1. σ(x) 推移プロット（Jensen/Bastankhah領域を色分け）
2. 中心線速度欠損プロット（CFDデータとの比較）
"""
function create_two_region_analysis_plots(df::DataFrame, U∞::Float64, params::NamedTuple,
                                          xv::AbstractRange, case_label::String, fig_dir::String)
    (; kw, Ct_eff, sigmaJ0, sigmaG0, km, x_shift) = params

    # =============================================================================
    # 1. σ(x) 推移プロット
    # =============================================================================
    sigma_plot = plot(
        xlabel = "x/D",
        ylabel = "σ/D",
        title = "Wake Width Evolution - $(case_label)",
        legend = :topleft,
        size = (900, 600),
        dpi = 300
    )

    # Jensen領域
    x_jensen = filter(x -> x < x_shift, xv)
    if !isempty(x_jensen)
        sigma_jensen = [compute_jensen_sigma(x, sigmaJ0, kw) for x in x_jensen]
        plot!(sigma_plot, x_jensen, sigma_jensen, lw=3, lc=:red, label="Jensen region")

        # Jensen領域の背景色
        vspan!(sigma_plot, [0, x_shift], alpha=0.1, color=:red, label="")
    end

    # Bastankhah領域
    x_bastankhah = filter(x -> x >= x_shift, xv)
    if !isempty(x_bastankhah)
        sigma_bastankhah = [compute_bastankhah_sigma(x, x_shift, sigmaG0, km) for x in x_bastankhah]
        plot!(sigma_plot, x_bastankhah, sigma_bastankhah, lw=3, lc=:blue, label="Bastankhah region")

        # Bastankhah領域の背景色
        vspan!(sigma_plot, [x_shift, maximum(xv)], alpha=0.1, color=:blue, label="")
    end

    # x_shift位置
    vline!(sigma_plot, [x_shift], lw=2, lc=:black, ls=:dash, label="x_shift=$(round(x_shift, digits=2))")

    # 接続点をマーク
    scatter!(sigma_plot, [x_shift], [sigmaG0], mc=:green, ms=8, label="Connection point")

    sigma_path = joinpath(fig_dir, "sigma_evolution_$(case_label).png")
    savefig(sigma_plot, sigma_path)
    println("✅ Saved: $(sigma_path)")

    # =============================================================================
    # 2. 中心線速度欠損プロット（CFDとの比較）
    # =============================================================================
    deficit_centerline_plot = plot(
        xlabel = "x/D",
        ylabel = "ΔU/U∞",
        title = "Centerline Velocity Deficit - $(case_label)",
        legend = :topright,
        size = (900, 600),
        dpi = 300
    )

    # CFDデータから中心線（r≈0）の速度欠損を抽出
    df_centerline = df[abs.(df.y) .< 0.1, :]  # r < 0.1 を中心線とみなす
    if !isempty(df_centerline)
        x_cfd = df_centerline.x
        deficit_cfd = (U∞ .- df_centerline.u) ./ U∞
        scatter!(deficit_centerline_plot, x_cfd, deficit_cfd,
                 mc=:gray, ms=3, alpha=0.5, label="CFD data")
    end

    # モデル予測（Jensen領域）
    if !isempty(x_jensen)
        deficit_jensen = [compute_jensen_deficit(x, kw, Ct_eff) for x in x_jensen]
        plot!(deficit_centerline_plot, x_jensen, deficit_jensen,
              lw=3, lc=:red, label="Jensen model")
    end

    # モデル予測（Bastankhah領域）
    if !isempty(x_bastankhah)
        deficit_bastankhah = [begin
            σ = compute_bastankhah_sigma(x, x_shift, sigmaG0, km)
            compute_bastankhah_deficit(σ, Ct_eff)
        end for x in x_bastankhah]
        plot!(deficit_centerline_plot, x_bastankhah, deficit_bastankhah,
              lw=3, lc=:blue, label="Bastankhah model")
    end

    # 領域の背景色
    vspan!(deficit_centerline_plot, [0, x_shift], alpha=0.1, color=:red, label="")
    vspan!(deficit_centerline_plot, [x_shift, maximum(xv)], alpha=0.1, color=:blue, label="")

    # x_shift位置
    vline!(deficit_centerline_plot, [x_shift], lw=2, lc=:black, ls=:dash, label="")

    deficit_centerline_path = joinpath(fig_dir, "deficit_centerline_$(case_label).png")
    savefig(deficit_centerline_plot, deficit_centerline_path)
    println("✅ Saved: $(deficit_centerline_path)")
end

function reconstruct_case(data_path::AbstractString, I_token::AbstractString, C_token::AbstractString,
                          coef_mode::Symbol, wake_model::Symbol, summary_df::Union{DataFrame,Nothing})
    case_label = "I$(I_token)_C$(C_token)"
    model_name = wake_model == WAKE_MODEL_TWO_REGION ? "two-region" : "single-gauss"
    println("Reconstructing wake for $(case_label) from $(data_path)")
    println("  Coefficient mode: $(coef_mode)")
    println("  Wake model: $(model_name)")

    df = CSV.read(data_path, DataFrame)
    U∞ = mean(df[df.x .< -4.8, :u])
    println(@sprintf("Freestream velocity U∞ = %.4f", U∞))

    I_val = token_to_value(I_token)
    Ct_val = token_to_value(C_token)

    # 速度場計算関数とパラメータ情報を設定
    u_model, param_info = if wake_model == WAKE_MODEL_TWO_REGION
        # 二領域モデル
        params = if coef_mode == COEF_MODE_SUMMARY
            summary_df === nothing && error("Summary データが読み込まれていません。")
            lookup_two_region_coefficients(summary_df, I_val, Ct_val)
        else
            coefficients_two_region(I_val, Ct_val; check_range=true)
        end

        info = @sprintf("""Two-region model parameters:
  kw      = %.6f
  Ct_eff  = %.6f
  sigmaJ0 = %.6f
  sigmaG0 = %.6f
  km      = %.6f
  x_shift = %.6f""", params.kw, params.Ct_eff, params.sigmaJ0, params.sigmaG0, params.km, params.x_shift)

        model_func = (x, r) -> compute_two_region_wake(x, r, params, U∞)
        (model_func, info)
    else
        # 単一ガウスモデル（旧モデル）
        coeffs = if coef_mode == COEF_MODE_SUMMARY
            summary_df === nothing && error("Summary データが読み込まれていません。")
            lookup_coefficients(summary_df, I_val, Ct_val)
        else
            coefficients_from_IC(I_val, Ct_val; check_range=true)
        end

        C0, c, n = coeffs.C0, coeffs.c, coeffs.n
        a2, a1, a0 = coeffs.a2, coeffs.a1, coeffs.a0

        info = @sprintf("""Single Gaussian model parameters:
  C(x) = %.4f * (1 + %.4f * x)^(-%.4f)
  σ(x) = %.4f * x^2 + %.4f * x + %.4f""", C0, c, n, a2, a1, a0)

        C(x) = C0 * (1 + c*x)^(-n)
        σ(x) = a2 * x^2 + a1 * x + a0
        model_func = (x, r) -> U∞ * (1 - C(x) * exp(-r^2 / (2 * σ(x)^2)))
        (model_func, info)
    end

    println(param_info)

    # 速度場を計算
    xv = range(0, stop=10, length=200)
    rv = range(-5, stop=5, length=200)
    u_field = [u_model(x, r) for r in rv, x in xv]

    # コンター図の作成
    gr()
    suffix = wake_model == WAKE_MODEL_TWO_REGION ? "_two_region" : "_single_gauss"
    plot_title = "Reconstructed Wake ($(model_name)) - $(case_label)"

    contourf(
        xv, rv, u_field;
        xlabel = "x (downstream)",
        ylabel = "r (radial)",
        title = plot_title,
        colorbar_title = "u [m/s]",
        levels = 100,
        aspect_ratio = 1,
        c = :thermal,
        linewidth = 0,
        size = (1000, 800),
        dpi = 300
    )
    plot!([0, maximum(xv)], [0, 0], lw=2, lc=:white, label="centerline")

    # 二領域モデルの場合、x_shift位置を表示
    if wake_model == WAKE_MODEL_TWO_REGION
        x_shift_val = if coef_mode == COEF_MODE_SUMMARY
            lookup_two_region_coefficients(summary_df, I_val, Ct_val).x_shift
        else
            coefficients_two_region(I_val, Ct_val; check_range=true).x_shift
        end
        vline!([x_shift_val], lw=2, lc=:cyan, ls=:dash, label="x_shift=$(round(x_shift_val, digits=2))")
    end

    mkpath(FIG_DIR)
    contour_path = joinpath(FIG_DIR, "wake$(suffix)_$(case_label).png")
    savefig(contour_path)
    println("✅ Saved: $(contour_path)")

    Δu_field = U∞ .- u_field
    deficit_plot = contourf(
        xv, rv, Δu_field;
        title="Velocity Deficit ($(model_name)) - $(case_label)",
        xlabel="x (downstream)",
        ylabel="r (radial)",
        colorbar_title="Δu [m/s]",
        c=:viridis,
        levels=100,
        aspect_ratio=1,
        dpi=300
    )
    deficit_path = joinpath(FIG_DIR, "deficit$(suffix)_$(case_label).png")
    savefig(deficit_plot, deficit_path)
    println("✅ Saved: $(deficit_path)")

    profile_plot = plot(rv, u_field[:, 100], xlabel="r", ylabel="u", label="model x≈5")
    df5 = df[abs.(df.x .- 5) .< 0.05, :]
    scatter!(profile_plot, df5.y, df5.u, label="CFD", xlabel="r", ylabel="u")
    plot!(profile_plot, rv, [u_model(5, r) for r in rv], label=model_name, lw=2)
    profile_path = joinpath(FIG_DIR, "profile$(suffix)_$(case_label).png")
    savefig(profile_plot, profile_path)
    println("✅ Saved: $(profile_path)")

    # 二領域モデルの場合、追加の詳細可視化を作成
    if wake_model == WAKE_MODEL_TWO_REGION
        params = if coef_mode == COEF_MODE_SUMMARY
            lookup_two_region_coefficients(summary_df, I_val, Ct_val)
        else
            coefficients_two_region(I_val, Ct_val; check_range=true)
        end
        create_two_region_analysis_plots(df, U∞, params, xv, case_label, FIG_DIR)
    end
end

function main()
    coef_mode, wake_model, dataset_args = parse_cli_args()
    summary_df = coef_mode == COEF_MODE_SUMMARY ? load_summary() : nothing
    targets = resolve_dataset_targets(dataset_args)
    for (path, I_token, C_token) in targets
        try
            reconstruct_case(path, I_token, C_token, coef_mode, wake_model, summary_df)
        catch e
            @warn "Failed to reconstruct $(path)" exception=(e, catch_backtrace())
        end
    end
end

main()
