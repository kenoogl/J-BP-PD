# Repository Guidelines

## Project Structure & Module Organization
Core Julia scripts sit in `src/`. `fit_gaussian_wake.jl` loads every `data/result_I{I_token}_C{C_token}.csv`, fits Gaussian profiles, and refreshes both per-case plots in `figures/` and the aggregated `fit_coefficients_summary.csv`. `plot_reconstructed_wake.jl` pulls `coeff_model.jl` to rebuild velocity fields, while `plot_contour.jl` generates the raw CFD contours. Keep incoming CFD under `data/` (symlinks welcome) and treat `figures/` as disposable artifacts.

## Build, Test, and Development Commands
`julia --project=. -e 'using Pkg; Pkg.instantiate()'` installs the dependencies pinned in `Project.toml`/`Manifest.toml`. `julia --project=. src/fit_gaussian_wake.jl` scans `data/`, fits all cases, and prints diagnostics. `julia --project=. src/plot_contour.jl --all` regenerates contour plots; pass a filename or two tokens (`0p0150 12p0000`) to limit scope. `julia --project=. src/plot_reconstructed_wake.jl --summary result_I0p0100_C10p0000.csv` compares reconstructed wakes to CFD, while `--analytic` uses regression coefficients for extrapolation.

## Coding Style & Naming Conventions
Stick to four-space indentation, `snake_case` for functions, uppercase `const` declarations grouped near the top, and broadcasting (`.*`, `.=`) for vector math. Keep helper utilities pure and log via `println`/`@warn` for consistency. CSV files must follow `result_I{I_token}_C{C_token}.csv`, using `p` instead of a decimal point (e.g., `0.01` → `0p0100`); figures reuse the same label, such as `wake_fit_I0p0100_C10p0000.png`. When extending `coeff_model.jl`, append coefficients in the documented tuple order `[1, I, Ct, I*Ct, …]`.

## Testing Guidelines
There is no automated harness, so treat manual runs as regression tests. After changing code, execute `fit_gaussian_wake.jl` on a baseline case (`I0p0100_C10p0000` is the default), verify `fit_coefficients_summary.csv` contains realistic slopes (`kw`, `km`), and confirm the generated figures overlay measured points without discontinuities. When editing `coeff_model.jl`, run `plot_reconstructed_wake.jl --summary` and `--analytic` for the same file; both reconstructions should closely match the CFD profiles saved under `figures/profile_*.png`.

## Commit & Pull Request Guidelines
This snapshot lacks `.git`, but downstream repos expect conventional commits in the form `<scope>: <imperative summary>` (example: `fit: guard missing CSV files`). Describe affected scripts, list datasets used for validation, and note every command that produced artifacts. Pull requests should link to any CFD case or issue, attach before/after thumbnails for changed figures, and mention external data requirements so reviewers can reproduce the run.

## Language

Japanese
