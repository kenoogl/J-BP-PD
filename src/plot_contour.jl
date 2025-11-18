#!/usr/bin/env julia
using CSV, DataFrames, Plots, Printf

const DATA_DIR = "data"
const FIG_DIR = "figures"
const DEFAULT_I_TOKEN = "0p0100"
const DEFAULT_C_TOKEN = "10p0000"
const CASE_PATTERN = r"result_I(\d+p\d+)_C(\d+p\d+)\.csv"

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
        if tokens !== nothing
            push!(matches, (f, tokens[1], tokens[2]))
        end
    end
    sort!(matches; by = x -> x[1])
    matches
end

function resolve_dataset_targets()
    if !isempty(ARGS) && (ARGS[1] in ("--all", "-a", "all"))
        cases = discover_cases()
        isempty(cases) && error("data/ に対応する CSV が見つかりません。")
        println("Processing all cases (", length(cases), " files).")
        return cases
    elseif isempty(ARGS)
        path = joinpath(DATA_DIR, "result_I$(DEFAULT_I_TOKEN)_C$(DEFAULT_C_TOKEN).csv")
        return [(path, DEFAULT_I_TOKEN, DEFAULT_C_TOKEN)]
    elseif length(ARGS) == 1
        arg = ARGS[1]
        path = if occursin("/", arg) || endswith(lowercase(arg), ".csv")
            arg
        elseif startswith(arg, "result_")
            joinpath(DATA_DIR, arg)
        else
            error("I/C の 2値、CSV ファイル名、または --all を指定してください。")
        end
        tokens = parse_tokens_from_path(path)
        tokens === nothing && error("ファイル名から I/C を特定できません。")
        return [(path, tokens[1], tokens[2])]
    else
        I_token = format_case_token(ARGS[1])
        C_token = format_case_token(ARGS[2])
        path = joinpath(DATA_DIR, "result_I$(I_token)_C$(C_token).csv")
        return [(path, I_token, C_token)]
    end
end

function plot_case(data_path::AbstractString, I_token::AbstractString, C_token::AbstractString)
    case_label = "I$(I_token)_C$(C_token)"
    println("Reading $(data_path) for $(case_label)")

    df = CSV.read(data_path, DataFrame)

    xv = sort(unique(df.x))
    yv = sort(unique(df.y))

    nx, ny = length(xv), length(yv)
    @assert nx * ny == nrow(df) "格子点が完全なグリッドになっていません。"

    u_grid = reshape(df.u, nx, ny)'

    gr()
    plt = contourf(
        xv, yv, u_grid;
        xlabel="x",
        ylabel="y",
        title="Velocity Contour (u) $(case_label)",
        colorbar_title="u [m/s]",
        aspect_ratio=1,
        levels=30,
        size=(900,600),
        c=:thermal,
        dpi=300
    )

    mkpath(FIG_DIR)
    fig_path = joinpath(FIG_DIR, "u_contour_$(case_label).png")
    savefig(plt, fig_path)
    println("Saved: $(fig_path)")
end

function main()
    targets = resolve_dataset_targets()
    for (path, I_token, C_token) in targets
        plot_case(path, I_token, C_token)
    end
end

main()
