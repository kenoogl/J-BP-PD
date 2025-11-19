#!/usr/bin/env julia
using CSV, DataFrames, Statistics, LsqFit, Printf, Plots

# =========================================================
# 1. データ読み込み
# =========================================================
df = CSV.read("data/result_I=0.01.csv", DataFrame)
println("Loaded data: ", size(df))

# =========================================================
# 2. 基本設定
# =========================================================
df[!, :r] = abs.(df.y)
U∞ = mean(df[df.x .< -4.8, :u])  # 上流境界は-5
println(@sprintf("Freestream velocity U∞ = %.4f", U∞))

x_sections = sort(unique(round.(df.x; digits=2)))
x_sections = filter(x -> x > 1.0, x_sections) # 1D後方以降

# =========================================================
# 3. 各断面でガウス型フィット
# =========================================================
model(r, p) = 1 .- p[1] .* exp.(-r.^2 ./ (2 * p[2]^2))  # p = [C, σ]
results = DataFrame(x=Float64[], C=Float64[], σ=Float64[])

for xval in x_sections
    df_sec = df[abs.(df.x .- xval) .< 0.01, :]
    if nrow(df_sec) < 10
        continue
    end
    r = df_sec.r
    u_norm = df_sec.u ./ U∞
    p0 = [0.3, 1.0]
    try
        fit = curve_fit(model, r, u_norm, p0)
        push!(results, (xval, fit.param[1], fit.param[2]))
    catch e
        @warn "Fit failed at x=$(xval): $e"
    end
end

println("Fitted ", nrow(results), " sections successfully.")

# =========================================================
# 4. C(x), σ(x) のx依存性をモデル化（※引数順修正済み）
# =========================================================
# 注意: curve_fit の model は model(x, p)
# σ(x) の変化が直線から外れる区間があるため2次多項式に拡張
model_sigma(x, p) = p[1] .* x.^2 .+ p[2] .* x .+ p[3]
fit_sigma = curve_fit(model_sigma, results.x, results.σ, [0.005, 0.05, 0.5])
a2, a1, a0 = fit_sigma.param
println(@sprintf("σ(x) = %.4f * x^2 + %.4f * x + %.4f", a2, a1, a0))

model_C(x, p) = p[1] .* (1 .+ p[2] .* x) .^ (-p[3])
fit_C = curve_fit(model_C, results.x, results.C, [0.3, 0.05, 2])
C0, c, n = fit_C.param
println(@sprintf("C(x) = %.4f * (1 + %.4f * x)^(-%.4f)", C0, c, n))

# =========================================================
# 5. 最終モデル式
# =========================================================
σ_expr = "$(round(a2, digits=4))*x^2 + $(round(a1, digits=4))*x + $(round(a0, digits=4))"
println("\nFinal analytical model:")
println("u(x,r) = U∞ * [1 - $(round(C0, digits=4)) * (1 + $(round(c, digits=4))*x)^(-$(round(n, digits=3))) * exp(-r^2 / (2*($σ_expr)^2))]")

# =========================================================
# 6. 結果の可視化
# =========================================================
p1 = plot(results.x, results.σ, label="σ(x) data", xlabel="x", ylabel="σ", lw=2)
plot!(p1, results.x, model_sigma(results.x, fit_sigma.param), label="fit", lw=2)

p2 = plot(results.x, results.C, label="C(x) data", xlabel="x", ylabel="C", lw=2)
plot!(p2, results.x, model_C(results.x, fit_C.param), label="fit", lw=2)

plot(p1, p2, layout=(1,2), size=(1200,600), legend=:bottomright, dpi=300)
savefig("wake_fit_results.png")
println("Saved figure: wake_fit_results.png")
