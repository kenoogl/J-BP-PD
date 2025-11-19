#!/usr/bin/env julia
using CSV, DataFrames, Statistics, LsqFit, Printf, Plots

# =========================================================
# ファイル名からI・Cを抽出する関数
# =========================================================
function parse_case_name(filename)
  m = match(r"result_I(\d+p\d+)_C(\d+p\d+)\.csv", filename)
  if m === nothing
    return nothing
  end
  I_str = replace(m.captures[1], "p" => ".")
  C_str = replace(m.captures[2], "p" => ".")
  I = parse(Float64, I_str)
  C = parse(Float64, C_str)
  case_name = "I$(m.captures[1])_C$(m.captures[2])"
  return (I=I, C=C, name=case_name)
end

# =========================================================
# 1ケースのガウスフィットを実行する関数
# =========================================================
function fit_gaussian_case(filepath, case_info)
  println("\n" * "="^60)
  println("Processing case: $(case_info.name) from $filepath")

  # データ読み込み
  df = CSV.read(filepath, DataFrame)
  println("Loaded data: ", size(df))

  # 基本設定
  df[!, :r] = abs.(df.y)
  U∞ = mean(df[df.x .< -4.8, :u])  # 上流境界は-5
  println(@sprintf("Freestream velocity U∞ = %.4f", U∞))

  x_sections = sort(unique(round.(df.x; digits=2)))
  x_sections = filter(x -> x > 1.0, x_sections) # 1D後方以降

  # 各断面でガウス型フィット
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

  println("Fitted $(nrow(results)) sections successfully.")

  # C(x), σ(x) のx依存性をモデル化
  model_sigma(x, p) = p[1] .* x.^2 .+ p[2] .* x .+ p[3]
  fit_sigma = curve_fit(model_sigma, results.x, results.σ, [0.005, 0.05, 0.5])
  a2, a1, a0 = fit_sigma.param
  println(@sprintf("σ(x) = %.4f * x^2 + %.4f * x + %.4f", a2, a1, a0))

  model_C(x, p) = p[1] .* (1 .+ p[2] .* x) .^ (-p[3])
  fit_C = curve_fit(model_C, results.x, results.C, [0.3, 0.05, 2])
  C0, c, n = fit_C.param
  println(@sprintf("C(x) = %.4f * (1 + %.4f * x)^(-%.4f)", C0, c, n))

  # 最終モデル式
  σ_expr = "$(round(a2, digits=4))*x^2 + $(round(a1, digits=4))*x + $(round(a0, digits=4))"
  println("Final analytical model for $(case_info.name):")
  println("u(x,r) = U∞ * [1 - $(round(C0, digits=4)) * (1 + $(round(c, digits=4))*x)^(-$(round(n, digits=3))) * exp(-r^2 / (2*($σ_expr)^2))]")

  # 結果の可視化
  p1 = plot(results.x, results.σ, label="σ(x) data", xlabel="x", ylabel="σ", lw=2)
  plot!(p1, results.x, model_sigma(results.x, fit_sigma.param), label="fit", lw=2)

  p2 = plot(results.x, results.C, label="C(x) data", xlabel="x", ylabel="C", lw=2)
  plot!(p2, results.x, model_C(results.x, fit_C.param), label="fit", lw=2)

  plot(p1, p2, layout=(1,2), size=(1200,600), legend=:bottomright, dpi=300)

  # figures ディレクトリがなければ作成
  if !isdir("figures")
    mkdir("figures")
  end

  figname = "figures/wake_fit_$(case_info.name).png"
  savefig(figname)
  println("Saved figure: $figname")

  # 係数を返す
  return (
    file=basename(filepath),
    I=case_info.I,
    C=case_info.C,
    U∞=U∞,
    C0=C0,
    c=c,
    n=n,
    a2=a2,
    a1=a1,
    a0=a0,
    sections=nrow(results)
  )
end

# =========================================================
# メイン処理: 全ケースを処理
# =========================================================
function main()
  # data/ 内の全CSVファイルを取得
  data_dir = "data"
  csv_files = filter(f -> endswith(f, ".csv"), readdir(data_dir))

  println("Found $(length(csv_files)) CSV files in $data_dir")

  # 各ファイルを処理
  summary_results = []

  for csv_file in csv_files
    case_info = parse_case_name(csv_file)
    if case_info === nothing
      @warn "Skipping file with unrecognized format: $csv_file"
      continue
    end

    filepath = joinpath(data_dir, csv_file)

    try
      result = fit_gaussian_case(filepath, case_info)
      push!(summary_results, result)
    catch e
      @error "Failed to process $csv_file: $e"
      continue
    end
  end

  # サマリーをCSVに保存
  if !isempty(summary_results)
    summary_df = DataFrame(summary_results)
    CSV.write("fit_coefficients_summary.csv", summary_df)
    println("\nSaved summary table: fit_coefficients_summary.csv")
  else
    @warn "No cases were successfully processed"
  end
end

# 実行
main()
