#!/usr/bin/env julia
using CSV, DataFrames, Statistics, LsqFit, Printf, Plots

const DATA_DIR = "data"
const FIG_DIR = "figures"
const SUMMARY_PATH = "fit_coefficients_summary.csv"

const NEAR_REGION_MAX_X = 2.0
const FAR_REGION_MIN_X = 5.0
const FALLBACK_POINT_COUNT = 5
const CENTERLINE_HALF_WIDTH = 0.05
const KW_RESIDUAL_THRESHOLD = 0.04
const KM_RESIDUAL_THRESHOLD = 0.02
const TRANSITION_SEARCH_SAMPLES = 200
const TRANSITION_BISECTION_STEPS = 30

gr()  # backend は最初に指定

case_pattern = r"result_I(\d+p\d+)_C(\d+p\d+)\.csv"

token_to_value(token::AbstractString) = parse(Float64, replace(token, "p" => "."))

function discover_input_files()
    if !isdir(DATA_DIR)
        error("Data directory $(DATA_DIR) が存在しません。シンボリックリンクまたは CSV を配置してください。")
    end
    files = filter(f -> endswith(lowercase(f), ".csv"), readdir(DATA_DIR; join=true))
    sort(files)
end

function parse_case_tokens(path::AbstractString)
    filename = basename(path)
    m = match(case_pattern, filename)
    return isnothing(m) ? nothing : (m.captures[1], m.captures[2])
end

function make_case_label(I_token::AbstractString, C_token::AbstractString)
    "I$(I_token)_C$(C_token)"
end

model_profile(r, p) = 1 .- p[1] .* exp.(-r.^2 ./ (2 * p[2]^2))  # p = [C, σ]
model_sigma(x, p) = p[1] .* x.^2 .+ p[2] .* x .+ p[3]
model_C(x, p) = p[1] .* (1 .+ p[2] .* x) .^ (-p[3])

function linear_regression(xvals::AbstractVector{<:Real}, yvals::AbstractVector{<:Real})
    n = length(xvals)
    if n < 2
        return (NaN, NaN, NaN)
    end
    x = float.(xvals)
    y = float.(yvals)
    x̄ = mean(x)
    ȳ = mean(y)
    denom = sum((x .- x̄).^2)
    slope = abs(denom) < 1e-9 ? 0.0 : sum((x .- x̄) .* (y .- ȳ)) / denom
    intercept = ȳ - slope * x̄
    residuals = y .- (intercept .+ slope .* x)
    rmse = sqrt(sum(residuals.^2) / n)
    return (slope, intercept, rmse)
end

function select_region_indices(xs::AbstractVector{<:Real}, predicate, fallback::Symbol)
    idx = findall(predicate, xs)
    if length(idx) < 2
        if fallback === :start
            idx = collect(1:min(length(xs), FALLBACK_POINT_COUNT))
        else
            idx = collect(max(1, length(xs) - FALLBACK_POINT_COUNT + 1):length(xs))
        end
    end
    return idx
end

function select_region(xs::AbstractVector{<:Real}, ys::AbstractVector{<:Real}, predicate, fallback::Symbol)
    idx = select_region_indices(xs, predicate, fallback)
    return xs[idx], ys[idx]
end

function compute_centerline_deficit(df_sec::DataFrame, U∞::Real)
    mask = abs.(df_sec.y) .<= CENTERLINE_HALF_WIDTH
    values = df_sec.u[mask]
    if isempty(values)
        idx = argmin(abs.(df_sec.y))
        values = df_sec.u[idx:idx]
    end
    deficit = 1 .- values ./ U∞
    return clamp(mean(deficit), 0.0, 0.9999)
end

jensen_deficit_value(x::Real, kw::Real, Ct::Real) = begin
    x_safe = max(x, 1e-6)
    kw_safe = max(kw, 1e-6)
    denom = (1 + 2 * kw_safe * x_safe)^2
    inside = clamp(1 - Ct / denom, 1e-6, 1.0)
    return 1 - sqrt(inside)
end

gaussian_deficit_value(x::Real, C0::Real, c::Real, n::Real) = begin
    base = max(1 + c * x, 1e-6)
    return clamp(C0 * base^(-n), 0.0, 0.9999)
end

function jensen_deficit_model(xs, kw, Ct)
    return [jensen_deficit_value(x, kw, Ct) for x in xs]
end

function fit_jensen_gradient(xs::AbstractVector{<:Real}, deficits::AbstractVector{<:Real})
    mask = [isfinite(d) && d > 0 for d in deficits]
    if count(mask) < 2
        return (NaN, NaN, NaN)
    end
    xvals = xs[mask]
    yvals = deficits[mask]
    # 2パラメータフィット: [kw, Ct_eff]
    model(x, p) = jensen_deficit_model(x, p[1], p[2])
    p0 = [0.05, 0.3]  # kw初期値0.05, Ct_eff初期値0.3
    try
        fit = curve_fit(model, xvals, yvals, p0)
        kw = max(fit.param[1], 1e-6)
        Ct_eff = clamp(fit.param[2], 0.0, 0.99)
        preds = model(xvals, fit.param)
        residual = sqrt(mean((preds .- yvals).^2))
        return (kw, Ct_eff, residual)
    catch e
        @warn "Jensen fit failed" exception=(e, catch_backtrace())
        return (NaN, NaN, NaN)
    end
end

function derive_transition(kw, Ct, C0, c, n, xs)
    xmin = max(minimum(xs), NEAR_REGION_MAX_X)
    xmax = maximum(xs)
    if !(isfinite(kw) && isfinite(C0) && isfinite(c) && isfinite(n)) || xmin >= xmax
        return xmin
    end
    diff(x) = jensen_deficit_value(x, kw, Ct) - gaussian_deficit_value(x, C0, c, n)
    grid = range(xmin, stop=xmax, length=TRANSITION_SEARCH_SAMPLES)
    last_x = first(grid)
    last_val = diff(last_x)
    for x in Iterators.drop(grid, 1)
        val = diff(x)
        if last_val == 0
            return last_x
        end
        if sign(val) != sign(last_val)
            lo, hi = last_x, x
            for _ in 1:TRANSITION_BISECTION_STEPS
                mid = (lo + hi) / 2
                mid_val = diff(mid)
                if mid_val == 0
                    return mid
                elseif sign(mid_val) == sign(last_val)
                    lo = mid
                    last_val = mid_val
                else
                    hi = mid
                end
            end
            return (lo + hi) / 2
        end
        last_x = x
        last_val = val
    end
    return clamp(xmin, xmin, xmax)
end

function fit_case(file_path::AbstractString, I_token::AbstractString, C_token::AbstractString)
    case_label = make_case_label(I_token, C_token)
    println("\n==============================")
    println("Processing case: $(case_label) from $(file_path)")

    df = CSV.read(file_path, DataFrame)
    println("Loaded data: ", size(df))

    df[!, :r] = abs.(df.y)
    U∞ = mean(df[df.x .< -4.8, :u])  # 上流境界は-5
    println(@sprintf("Freestream velocity U∞ = %.4f", U∞))

    x_sections = sort(unique(round.(df.x; digits=2)))
    x_sections = filter(x -> x > 1.0, x_sections) # 1D後方以降

    results = DataFrame(x=Float64[], C=Float64[], σ=Float64[], centerline_deficit=Float64[])
    for xval in x_sections
        df_sec = df[abs.(df.x .- xval) .< 0.01, :]
        if nrow(df_sec) < 10
            continue
        end
        r = df_sec.r
        u_norm = df_sec.u ./ U∞
        p0 = [0.3, 1.0]
        centerline_deficit = compute_centerline_deficit(df_sec, U∞)
        try
            fit = curve_fit(model_profile, r, u_norm, p0)
            push!(results, (xval, fit.param[1], fit.param[2], centerline_deficit))
        catch e
            @warn "Fit failed at x=$(xval)" exception=(e, catch_backtrace())
        end
    end

    if nrow(results) == 0
        error("No valid sections for $(case_label)")
    end

    println("Fitted ", nrow(results), " sections successfully.")

    fit_sigma = curve_fit(model_sigma, results.x, results.σ, [0.005, 0.05, 0.5])
    a2, a1, a0 = fit_sigma.param
    println(@sprintf("σ(x) = %.4f * x^2 + %.4f * x + %.4f", a2, a1, a0))

    fit_C = curve_fit(model_C, results.x, results.C, [0.3, 0.05, 2])
    C0, c, n = fit_C.param
    println(@sprintf("C(x) = %.4f * (1 + %.4f * x)^(-%.4f)", C0, c, n))

    σ_expr = "$(round(a2, digits=4))*x^2 + $(round(a1, digits=4))*x + $(round(a0, digits=4))"
    println("Final analytical model for $(case_label):")
    println("u(x,r) = U∞ * [1 - $(round(C0, digits=4)) * (1 + $(round(c, digits=4))*x)^(-$(round(n, digits=3))) * exp(-r^2 / (2*($σ_expr)^2))]")

    xs = results.x
    sigmas = results.σ
    deficits = results.centerline_deficit
    near_idx = select_region_indices(xs, x -> x <= NEAR_REGION_MAX_X, :start)
    near_x = xs[near_idx]
    near_sigma = sigmas[near_idx]
    near_deficits = deficits[near_idx]
    sigma_slope, sigma_intercept, sigma_rmse = linear_regression(near_x, near_sigma)
    kw, Ct_eff, fit_residual_kw = fit_jensen_gradient(near_x, near_deficits)
    far_idx = select_region_indices(xs, x -> x >= FAR_REGION_MIN_X, :end)
    far_x = xs[far_idx]
    far_sigma = sigmas[far_idx]
    km, far_intercept, rmse_km = linear_regression(far_x, far_sigma)
    x_shift = derive_transition(kw, Ct_eff, C0, c, n, xs)
    sigmaJ0 = max(sigma_intercept, 1e-6)
    sigmaG0 = max(model_sigma([x_shift], fit_sigma.param)[1], 1e-6)
    fit_residual_km = rmse_km

    println(@sprintf("Jensen centerline fit: kw=%.4f, Ct_eff=%.4f (residual %.5f)", kw, Ct_eff, fit_residual_kw))
    println(@sprintf("Near-field σ fit: σ ≈ %.4f + %.4f·x (RMSE %.4f)", sigma_intercept, sigma_slope, sigma_rmse))
    println(@sprintf("Far-field σ fit: σ ≈ %.4f + %.4f·x (RMSE %.4f)", far_intercept, km, rmse_km))
    println(@sprintf("Derived transition: sigmaJ0=%.4f, kw=%.4f, Ct_eff=%.4f, x_shift=%.4f, sigmaG0=%.4f", sigmaJ0, kw, Ct_eff, x_shift, sigmaG0))

    kw_outlier = !(isfinite(kw) && fit_residual_kw <= KW_RESIDUAL_THRESHOLD)
    km_outlier = !(isfinite(km) && fit_residual_km <= KM_RESIDUAL_THRESHOLD)
    kw_outlier && @warn("Centerline Jensen fit residual is large (kw=$(kw), residual=$(fit_residual_kw)) for $(case_label)")
    km_outlier && @warn("Far-field σ fit residual is large (km=$(km), residual=$(fit_residual_km)) for $(case_label)")

    mkpath(FIG_DIR)
    p1 = plot(results.x, results.σ, label="σ(x) data", xlabel="x", ylabel="σ", lw=2)
    plot!(p1, results.x, model_sigma(results.x, fit_sigma.param), label="fit", lw=2)

    p2 = plot(results.x, results.C, label="C(x) data", xlabel="x", ylabel="C", lw=2)
    plot!(p2, results.x, model_C(results.x, fit_C.param), label="fit", lw=2)

    fig_path = joinpath(FIG_DIR, "wake_fit_$(case_label).png")
    plot(p1, p2, layout=(1,2), size=(1200,600), legend=:bottomright, dpi=300)
    savefig(fig_path)
    println("Saved figure: $(fig_path)")

    return (
        file = basename(file_path),
        I = token_to_value(I_token),
        Ct = token_to_value(C_token),
        U∞ = U∞,
        C0 = C0,
        c = c,
        n = n,
        a2 = a2,
        a1 = a1,
        a0 = a0,
        sections = nrow(results),
        kw = kw,
        Ct_eff = Ct_eff,
        sigmaJ0 = sigmaJ0,
        sigmaG0 = sigmaG0,
        km = km,
        x_shift = x_shift,
        rmse_kw = fit_residual_kw,
        rmse_km = fit_residual_km,
        fit_residual_kw = fit_residual_kw,
        fit_residual_km = fit_residual_km,
        kw_outlier = kw_outlier,
        km_outlier = km_outlier
    )
end

function main()
    csv_files = discover_input_files()
    if isempty(csv_files)
        error("data ディレクトリに CSV が見つかりません。")
    end

    summary_cols = (
        file = String[],
        I = Float64[],
        Ct = Float64[],
        U∞ = Float64[],
        C0 = Float64[],
        c = Float64[],
        n = Float64[],
        a2 = Float64[],
        a1 = Float64[],
        a0 = Float64[],
        sections = Int[],
        kw = Float64[],
        Ct_eff = Float64[],
        sigmaJ0 = Float64[],
        sigmaG0 = Float64[],
        km = Float64[],
        x_shift = Float64[],
        rmse_kw = Float64[],
        rmse_km = Float64[],
        fit_residual_kw = Float64[],
        fit_residual_km = Float64[],
        kw_outlier = Bool[],
        km_outlier = Bool[]
    )
    summary_df = DataFrame(summary_cols)

    for file_path in csv_files
        tokens = parse_case_tokens(file_path)
        if tokens === nothing
            @warn "Skipping file without I/C naming pattern: $(file_path)"
            continue
        end
        I_token, C_token = tokens
        case_label = make_case_label(I_token, C_token)
        try
            fit_row = fit_case(file_path, I_token, C_token)
            push!(summary_df, fit_row)
        catch e
            @warn "Fit failed for $(case_label)" exception=(e, catch_backtrace())
        end
    end

    if nrow(summary_df) == 0
        error("単一ケースもフィットできませんでした。ログを確認してください。")
    end

    CSV.write(SUMMARY_PATH, summary_df)
    println("\nSaved summary table: $(SUMMARY_PATH)")
end

main()
