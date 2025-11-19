#!/usr/bin/env julia
using CSV, DataFrames, Statistics, LsqFit, Printf, Plots

# =========================================================
# 1. 入力ファイルの読み込みと上流条件
# =========================================================
df = CSV.read("data/result_I=0.01.csv", DataFrame)
U∞ = mean(df[df.x .< -4.8, :u])
println(@sprintf("Freestream velocity U∞ = %.4f", U∞))

# 推定済みパラメータ（fit_gaussian_wake.jl の出力結果をコピペ）
# ---------------------------------------------------------
# 例（あなたの実測結果をここに書き換えてください）
C0, c, n = 0.2510, 0.3381, 0.6568
# σ(x) = a2 * x^2 + a1 * x + a0
a2, a1, a0 = -0.0010, 0.0425, 0.2840
# ---------------------------------------------------------

# =========================================================
# 2. C(x), σ(x), u(x,r) の定義式
# =========================================================
C(x) = C0 * (1 + c*x)^(-n)
σ(x) = a2 * x.^2 .+ a1 .* x .+ a0
u_model(x, r) = U∞ * (1 - C(x) * exp(-r^2 / (2 * σ(x)^2)))

# =========================================================
# 3. グリッド生成 (x–r 平面)
# =========================================================
xv = range(0, stop=10, length=200)
rv = range(-5, stop=5, length=200)

u_field = [u_model(x, r) for r in rv, x in xv]  # 行: r, 列: x

# =========================================================
# 4. コンター可視化
# =========================================================
gr()  # GR backend
contourf(
    xv, rv, u_field;
    xlabel = "x (downstream)",
    ylabel = "r (radial)",
    title = "Reconstructed Wake Velocity Field",
    colorbar_title = "u [m/s]",
    levels = 100,
    aspect_ratio = 1,
    c = :thermal,
    linewidth = 0,
    size = (1000, 800),
    dpi = 300
)

# 風車中心線の補助線
plot!([0, maximum(xv)], [0, 0], lw=2, lc=:white, label="centerline")

savefig("reconstructed_wake_contour.png")
println("✅ Saved: reconstructed_wake_contour.png")

Δu_field = U∞ .- u_field
contourf(xv, rv, Δu_field; title="Velocity Deficit (U∞ - u)", c=:viridis)
savefig("velocity_deficit_contour.png")
println("✅ Saved: velocity_deficit_contour.png")


plot(rv, u_field[:, 100], xlabel="r", ylabel="u", label="x=5")
# CFD断面平均 (x=5付近)
df5 = df[abs.(df.x .- 5) .< 0.05, :]
scatter(df5.y, df5.u, label="CFD", xlabel="r", ylabel="u")
plot!(rv, [u_model(5, r) for r in rv], label="Gaussian model")
savefig("profile.png")
println("✅ Saved: profile.png")
