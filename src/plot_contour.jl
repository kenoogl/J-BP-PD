using CSV, DataFrames, Plots

# =====================================================
# 1. データ読み込み
# =====================================================
df = CSV.read("data/result_I=0.01.csv", DataFrame)

# =====================================================
# 2. グリッド整形
# =====================================================
# 一意なx, yを抽出
xv = sort(unique(df.x))
yv = sort(unique(df.y))

nx, ny = length(xv), length(yv)

# uを2次元配列に整形
u_grid = reshape(df.u, nx, ny)'

# =====================================================
# 3. コンター図（u速度）
# =====================================================
gr()

contourf(
    xv, yv, u_grid,
    xlabel="x",
    ylabel="y",
    title="Velocity Contour (u)",
    colorbar_title="u [m/s]",
    aspect_ratio=1,
    levels=30,
    size=(900,600),
    c=:thermal,  # カラーマップ
    dpi=300
)
savefig("u_contour.png")
println("Saved: u_contour.png")

