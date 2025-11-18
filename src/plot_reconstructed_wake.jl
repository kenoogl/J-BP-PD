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
    mode = COEF_MODE_ANALYTIC
    dataset_args = String[]
    for arg in ARGS
        if arg in ("--summary", "-s")
            mode = COEF_MODE_SUMMARY
        elseif arg in ("--analytic", "--model")
            mode = COEF_MODE_ANALYTIC
        else
            push!(dataset_args, arg)
        end
    end
    return mode, dataset_args
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

function reconstruct_case(data_path::AbstractString, I_token::AbstractString, C_token::AbstractString,
                          coef_mode::Symbol, summary_df::Union{DataFrame,Nothing})
    case_label = "I$(I_token)_C$(C_token)"
    println("Reconstructing wake for $(case_label) from $(data_path) using $(coef_mode) coefficients")

    df = CSV.read(data_path, DataFrame)
    U∞ = mean(df[df.x .< -4.8, :u])
    println(@sprintf("Freestream velocity U∞ = %.4f", U∞))

    I_val = token_to_value(I_token)
    Ct_val = token_to_value(C_token)
    coeffs = if coef_mode == COEF_MODE_SUMMARY
        summary_df === nothing && error("Summary データが読み込まれていません。")
        lookup_coefficients(summary_df, I_val, Ct_val)
    else
        coefficients_from_IC(I_val, Ct_val; check_range=true)
    end
    C0, c, n = coeffs.C0, coeffs.c, coeffs.n
    a2, a1, a0 = coeffs.a2, coeffs.a1, coeffs.a0
    if coef_mode == COEF_MODE_SUMMARY
        println("Using coefficients from $(SUMMARY_PATH):")
    else
        println("Using analytic regression-based coefficients:")
    end
    println(@sprintf("  C(x) = %.4f * (1 + %.4f * x)^(-%.4f)", C0, c, n))
    println(@sprintf("  σ(x) = %.4f * x^2 + %.4f * x + %.4f", a2, a1, a0))

    C(x) = C0 * (1 + c*x)^(-n)
    σ(x) = a2 * x^2 + a1 * x + a0
    u_model(x, r) = U∞ * (1 - C(x) * exp(-r^2 / (2 * σ(x)^2)))

    xv = range(0, stop=10, length=200)
    rv = range(-5, stop=5, length=200)
    u_field = [u_model(x, r) for r in rv, x in xv]

    gr()
    contourf(
        xv, rv, u_field;
        xlabel = "x (downstream)",
        ylabel = "r (radial)",
        title = "Reconstructed Wake Velocity Field $(case_label)",
        colorbar_title = "u [m/s]",
        levels = 100,
        aspect_ratio = 1,
        c = :thermal,
        linewidth = 0,
        size = (1000, 800),
        dpi = 300
    )
    plot!([0, maximum(xv)], [0, 0], lw=2, lc=:white, label="centerline")

    mkpath(FIG_DIR)
    contour_path = joinpath(FIG_DIR, "reconstructed_wake_contour_$(case_label).png")
    savefig(contour_path)
    println("✅ Saved: $(contour_path)")

    Δu_field = U∞ .- u_field
    deficit_plot = contourf(
        xv, rv, Δu_field;
        title="Velocity Deficit (U∞ - u) $(case_label)",
        xlabel="x (downstream)",
        ylabel="r (radial)",
        colorbar_title="Δu [m/s]",
        c=:viridis,
        levels=100,
        aspect_ratio=1,
        dpi=300
    )
    deficit_path = joinpath(FIG_DIR, "velocity_deficit_contour_$(case_label).png")
    savefig(deficit_plot, deficit_path)
    println("✅ Saved: $(deficit_path)")

    profile_plot = plot(rv, u_field[:, 100], xlabel="r", ylabel="u", label="model x≈5")
    df5 = df[abs.(df.x .- 5) .< 0.05, :]
    scatter!(profile_plot, df5.y, df5.u, label="CFD", xlabel="r", ylabel="u")
    plot!(profile_plot, rv, [u_model(5, r) for r in rv], label="Gaussian model", lw=2)
    profile_path = joinpath(FIG_DIR, "profile_$(case_label).png")
    savefig(profile_plot, profile_path)
    println("✅ Saved: $(profile_path)")
end

function main()
    coef_mode, dataset_args = parse_cli_args()
    summary_df = coef_mode == COEF_MODE_SUMMARY ? load_summary() : nothing
    targets = resolve_dataset_targets(dataset_args)
    for (path, I_token, C_token) in targets
        try
            reconstruct_case(path, I_token, C_token, coef_mode, summary_df)
        catch e
            @warn "Failed to reconstruct $(path)" exception=(e, catch_backtrace())
        end
    end
end

main()
