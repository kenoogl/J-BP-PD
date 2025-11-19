#!/usr/bin/env julia
using CSV, DataFrames, Plots, Printf

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
# 1ケースのコンター図を描画する関数
# =========================================================
function plot_contour_case(filepath, case_info)
  println("="^60)
  println("Plotting contour for $(case_info.name)")
  println("Loading: $filepath")
  println("="^60)

  # データ読み込み
  df = CSV.read(filepath, DataFrame)
  println("Loaded data: ", size(df))

  # グリッド整形
  xv = sort(unique(df.x))
  yv = sort(unique(df.y))

  nx, ny = length(xv), length(yv)
  println("Grid size: $nx × $ny")

  # uを2次元配列に整形
  u_grid = reshape(df.u, nx, ny)'

  # figuresディレクトリがなければ作成
  if !isdir("figures")
    mkdir("figures")
  end

  # コンター図（u速度）
  gr()

  contourf(
    xv, yv, u_grid,
    xlabel = "x",
    ylabel = "y",
    title = "Velocity Contour: $(case_info.name)",
    colorbar_title = "u [m/s]",
    aspect_ratio = 1,
    levels = 50,
    size = (1200, 800),
    c = :thermal,
    dpi = 300
  )

  figname = "figures/u_contour_$(case_info.name).png"
  savefig(figname)
  println("✅ Saved: $figname\n")
end

# =========================================================
# コマンドライン引数の解析
# =========================================================
function parse_arguments()
  # --all オプションのチェック
  if "--all" in ARGS || "-a" in ARGS || "all" in ARGS
    return nothing, nothing, true
  end

  if length(ARGS) < 2
    println("Usage: julia plot_contour.jl <I> <C>")
    println("       julia plot_contour.jl --all")
    println()
    println("Arguments:")
    println("  <I>:   Turbulence intensity (e.g., 0.05)")
    println("  <C>:   Porous disk resistance coefficient (e.g., 16.0)")
    println("  --all: Process all cases in data/ directory")
    println()
    println("Examples:")
    println("  julia --project=. src/plot_contour.jl 0.05 16")
    println("  julia --project=. src/plot_contour.jl --all")
    exit(1)
  end

  I = parse(Float64, ARGS[1])
  C = parse(Float64, ARGS[2])

  return I, C, false
end

# =========================================================
# メイン処理
# =========================================================
function main()
  I, C, process_all = parse_arguments()

  if process_all
    # 全ケースを処理
    data_dir = "data"
    csv_files = filter(f -> endswith(f, ".csv"), readdir(data_dir))

    println("Found $(length(csv_files)) CSV files in $data_dir")
    println("Processing all cases...\n")

    for csv_file in csv_files
      case_info = parse_case_name(csv_file)
      if case_info === nothing
        @warn "Skipping file with unrecognized format: $csv_file"
        continue
      end

      filepath = joinpath(data_dir, csv_file)

      try
        plot_contour_case(filepath, case_info)
      catch e
        @error "Failed to process $csv_file: $e"
        continue
      end
    end

    println("✅ All contour plots completed!")
  else
    # 単一ケースを処理
    I_str = replace(@sprintf("%.4f", I), "." => "p")
    C_str = replace(@sprintf("%.4f", C), "." => "p")
    filename = "data/result_I$(I_str)_C$(C_str).csv"

    if !isfile(filename)
      @error "Data file not found: $filename"
      println("\nAvailable files:")
      data_dir = "data"
      csv_files = filter(f -> endswith(f, ".csv"), readdir(data_dir))
      for file in csv_files
        println("  $file")
      end
      exit(1)
    end

    case_info = (I=I, C=C, name="I$(I_str)_C$(C_str)")
    plot_contour_case(filename, case_info)
  end
end

# 実行
main()
