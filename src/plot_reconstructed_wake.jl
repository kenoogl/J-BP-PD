#!/usr/bin/env julia
using CSV, DataFrames, Statistics, Printf, Plots

# coeff_model.jl を読み込み
include("coeff_model.jl")

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
# コマンドライン引数の解析
# =========================================================
function parse_arguments()
  # --all オプションのチェック
  process_all = "--all" in ARGS || "-a" in ARGS || "all" in ARGS
  use_summary = "--summary" in ARGS

  if process_all
    return nothing, nothing, use_summary, true
  end

  if length(ARGS) < 2
    println("Usage: julia plot_reconstructed_wake.jl <I> <C> [--summary]")
    println("       julia plot_reconstructed_wake.jl --all [--summary]")
    println()
    println("Arguments:")
    println("  <I>:       Turbulence intensity (e.g., 0.05)")
    println("  <C>:       Porous disk resistance coefficient (e.g., 16.0)")
    println("  --summary: Use coefficients from fit_coefficients_summary.csv")
    println("  --all:     Process all cases")
    println()
    println("Examples:")
    println("  julia --project=. src/plot_reconstructed_wake.jl 0.05 16")
    println("  julia --project=. src/plot_reconstructed_wake.jl 0.05 16 --summary")
    println("  julia --project=. src/plot_reconstructed_wake.jl --all")
    println("  julia --project=. src/plot_reconstructed_wake.jl --all --summary")
    exit(1)
  end

  I = parse(Float64, ARGS[1])
  C = parse(Float64, ARGS[2])

  return I, C, use_summary, false
end

# =========================================================
# fit_coefficients_summary.csv から係数を取得
# =========================================================
function get_coefficients_from_summary(I, C)
  if !isfile("fit_coefficients_summary.csv")
    @error "fit_coefficients_summary.csv not found. Please run fit_gaussian_wake.jl first."
    exit(1)
  end

  df = CSV.read("fit_coefficients_summary.csv", DataFrame)

  # 完全一致するケースを検索
  matching_rows = df[(df.I .== I) .& (df.C .== C), :]

  if nrow(matching_rows) == 0
    @error "No matching case found for I=$I, C=$C in fit_coefficients_summary.csv"
    println("Available cases:")
    for row in eachrow(df)
      println("  I=$(row.I), C=$(row.C)")
    end
    exit(1)
  end

  row = matching_rows[1, :]
  return (
    C0=row.C0,
    c=row.c,
    n=row.n,
    a2=row.a2,
    a1=row.a1,
    a0=row.a0,
    U∞=row.U∞
  )
end

# =========================================================
# CFDデータから上流速度を取得
# =========================================================
function get_upstream_velocity(I, C)
  # ファイル名を構築（4桁ゼロ埋め形式: 0.01 → 0p0100）
  I_str = replace(@sprintf("%.4f", I), "." => "p")
  C_str = replace(@sprintf("%.4f", C), "." => "p")
  filename = "data/result_I$(I_str)_C$(C_str).csv"

  if !isfile(filename)
    @warn "CFD data file not found: $filename. Using U∞=1.0"
    return 1.0
  end

  df = CSV.read(filename, DataFrame)
  U∞ = mean(df[df.x .< -4.8, :u])
  return U∞
end

# =========================================================
# 1ケースの再構成を実行する関数
# =========================================================
function reconstruct_case(I, C, use_summary)
  println("="^60)
  println("Reconstructing wake for I=$I, C=$C")
  println("="^60)

  # 係数を取得
  if use_summary
    println("Using coefficients from fit_coefficients_summary.csv")
    coeffs = get_coefficients_from_summary(I, C)
    U∞ = coeffs.U∞
  else
    println("Using coefficients from regression model (coeff_model.jl)")
    coeffs = coefficients_from_IC(I, C)
    U∞ = get_upstream_velocity(I, C)
  end

  println(@sprintf("  U∞  = %.4f", U∞))
  println(@sprintf("  C0  = %.4f", coeffs.C0))
  println(@sprintf("  c   = %.4f", coeffs.c))
  println(@sprintf("  n   = %.4f", coeffs.n))
  println(@sprintf("  a2  = %.6f", coeffs.a2))
  println(@sprintf("  a1  = %.4f", coeffs.a1))
  println(@sprintf("  a0  = %.4f", coeffs.a0))

  # C(x), σ(x), u(x,r) の定義式
  C(x) = coeffs.C0 * (1 + coeffs.c*x)^(-coeffs.n)
  σ(x) = coeffs.a2 * x^2 + coeffs.a1 * x + coeffs.a0
  u_model(x, r) = U∞ * (1 - C(x) * exp(-r^2 / (2 * σ(x)^2)))

  # グリッド生成 (x–r 平面)
  xv = range(0, stop=20, length=300)
  rv = range(-5, stop=5, length=200)

  u_field = [u_model(x, r) for r in rv, x in xv]  # 行: r, 列: x

  # figuresディレクトリがなければ作成
  if !isdir("figures")
    mkdir("figures")
  end

  # ケース名を構築（4桁ゼロ埋め形式: 0.01 → 0p0100）
  I_str = replace(@sprintf("%.4f", I), "." => "p")
  C_str = replace(@sprintf("%.4f", C), "." => "p")
  case_name = "I$(I_str)_C$(C_str)"
  mode_suffix = use_summary ? "_summary" : "_model"

  # コンター可視化: 速度場
  gr()
  contourf(
    xv, rv, u_field;
    xlabel = "x (downstream)",
    ylabel = "r (radial)",
    title = "Reconstructed Wake: $case_name",
    colorbar_title = "u [m/s]",
    levels = 100,
    aspect_ratio = 1,
    c = :thermal,
    linewidth = 0,
    size = (1200, 800),
    dpi = 300
  )

  # 風車中心線の補助線
  plot!([0, maximum(xv)], [0, 0], lw=2, lc=:white, label="centerline", legend=false)

  figname = "figures/reconstructed_wake_$(case_name)$(mode_suffix).png"
  savefig(figname)
  println("✅ Saved: $figname")

  # コンター可視化: 速度欠損
  Δu_field = U∞ .- u_field
  contourf(
    xv, rv, Δu_field;
    xlabel = "x (downstream)",
    ylabel = "r (radial)",
    title = "Velocity Deficit: $case_name",
    colorbar_title = "ΔU [m/s]",
    levels = 100,
    aspect_ratio = 1,
    c = :viridis,
    linewidth = 0,
    size = (1200, 800),
    dpi = 300
  )
  plot!([0, maximum(xv)], [0, 0], lw=2, lc=:white, label="centerline", legend=false)

  figname = "figures/velocity_deficit_$(case_name)$(mode_suffix).png"
  savefig(figname)
  println("✅ Saved: $figname")

  # 半径方向プロファイル（複数のx位置）
  x_positions = [2.0, 5.0, 10.0, 15.0]
  plot(
    xlabel = "r (radial)",
    ylabel = "u [m/s]",
    title = "Radial Profiles: $case_name",
    size = (900, 600),
    dpi = 300,
    legend = :bottomright
  )

  for x_pos in x_positions
    u_profile = [u_model(x_pos, r) for r in rv]
    plot!(rv, u_profile, label="x=$x_pos", lw=2)
  end

  figname = "figures/radial_profiles_$(case_name)$(mode_suffix).png"
  savefig(figname)
  println("✅ Saved: $figname")

  println("✅ Reconstruction complete for I=$I, C=$C\n")
end

# =========================================================
# メイン処理
# =========================================================
function main()
  I, C, use_summary, process_all = parse_arguments()

  if process_all
    # 全ケースを処理
    if use_summary
      # CSVから全ケースを取得
      if !isfile("fit_coefficients_summary.csv")
        @error "fit_coefficients_summary.csv not found. Please run fit_gaussian_wake.jl first."
        exit(1)
      end

      df = CSV.read("fit_coefficients_summary.csv", DataFrame)
      println("Found $(nrow(df)) cases in fit_coefficients_summary.csv")
      println("Processing all cases with coefficients from CSV...\n")

      for row in eachrow(df)
        try
          reconstruct_case(row.I, row.C, use_summary)
        catch e
          @error "Failed to process I=$(row.I), C=$(row.C): $e"
          continue
        end
      end
    else
      # data/から全ケースを取得
      data_dir = "data"
      csv_files = filter(f -> endswith(f, ".csv"), readdir(data_dir))

      println("Found $(length(csv_files)) CSV files in $data_dir")
      println("Processing all cases with regression model...\n")

      for csv_file in csv_files
        case_info = parse_case_name(csv_file)
        if case_info === nothing
          @warn "Skipping file with unrecognized format: $csv_file"
          continue
        end

        try
          reconstruct_case(case_info.I, case_info.C, use_summary)
        catch e
          @error "Failed to process $csv_file: $e"
          continue
        end
      end
    end

    println("✅ All reconstructions completed!")
  else
    # 単一ケースを処理
    reconstruct_case(I, C, use_summary)
  end
end

# 実行
main()
