#!/usr/bin/env python3
"""
Post-processes fit_coefficients_summary.csv to evaluate the regression model,
produce residual diagnostics, correlation matrices, and requested figures.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Dict, List, Tuple

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib.patches import Rectangle

BASE_DIR = Path(__file__).resolve().parents[1]
DATA_FILE = BASE_DIR / "fit_coefficients_summary.csv"
FIG_DIR = BASE_DIR / "figures"
ANALYSIS_DIR = BASE_DIR / "analysis"
CFD_DIR = BASE_DIR / "data"

COEFFICIENTS = ["C0", "c", "n", "a2", "a1", "a0"]
LINEAR_BASIS = ("linear",)
EXTENDED_BASIS = ("extended",)

FIG_DIR.mkdir(exist_ok=True)
ANALYSIS_DIR.mkdir(exist_ok=True)


def build_design_matrix(I: np.ndarray, C: np.ndarray, basis: str) -> np.ndarray:
    """Create the design matrix that mirrors the Julia implementation."""
    if basis == "linear":
        return np.column_stack([np.ones_like(I), I, C, I * C])
    if basis == "extended":
        return np.column_stack(
            [
                np.ones_like(I),
                I,
                C,
                I * C,
                1.0 / I,
                C / I,
                1.0 / (I**2),
                C / (I**2),
            ]
        )
    raise ValueError(f"Unknown basis: {basis}")


def solve_regression(X: np.ndarray, y: np.ndarray) -> Tuple[np.ndarray, np.ndarray, float]:
    """Solve the least-squares system and return beta, predictions, and R^2."""
    beta, *_ = np.linalg.lstsq(X, y, rcond=None)
    y_pred = X @ beta
    ss_res = np.sum((y - y_pred) ** 2)
    ss_tot = np.sum((y - y.mean()) ** 2)
    r2 = 1.0 - ss_res / ss_tot
    return beta, y_pred, r2


def predict(coeff_name: str, I: np.ndarray, C: np.ndarray, beta_lookup: Dict[str, np.ndarray]) -> np.ndarray:
    """Evaluate the regression model for arbitrary I and C."""
    basis = "extended" if coeff_name == "n" else "linear"
    features = build_design_matrix(I, C, basis)
    beta = beta_lookup[coeff_name]
    return features @ beta


def summarize_residuals(df: pd.DataFrame, coeff: str, residuals: np.ndarray, top_k: int = 3) -> List[Dict]:
    """Return the top-k residual entries sorted by magnitude."""
    order = np.argsort(np.abs(residuals))[::-1][:top_k]
    summary = []
    for idx in order:
        summary.append(
            {
                "file": df.loc[idx, "file"],
                "I": float(df.loc[idx, "I"]),
                "C": float(df.loc[idx, "C"]),
                "residual": float(residuals[idx]),
                "actual": float(df.loc[idx, coeff]),
                "predicted": float(df.loc[idx, f"{coeff}_pred"]),
            }
        )
    return summary


def make_dependency_grid(df: pd.DataFrame, beta_lookup: Dict[str, np.ndarray]) -> None:
    """Plot coefficient sensitivity to I and C."""
    fig, axes = plt.subplots(len(COEFFICIENTS), 2, figsize=(12, 20), sharex="col")
    I_line = np.linspace(0.01, 0.30, 200)
    C_line = np.linspace(10.0, 25.0, 200)
    for row, coeff in enumerate(COEFFICIENTS):
        # I sweep (C fixed)
        ax_left = axes[row, 0]
        C_fixed = 16.0
        I_vals = I_line
        preds_I = predict(coeff, I_vals, np.full_like(I_vals, C_fixed), beta_lookup)
        ax_left.plot(I_vals, preds_I, label="Regression", color="#1f77b4")
        subset = df[np.isclose(df["C"], C_fixed)]
        ax_left.scatter(subset["I"], subset[coeff], color="#ff7f0e", label="Data", zorder=3)
        ax_left.set_ylabel(coeff)
        if row == len(COEFFICIENTS) - 1:
            ax_left.set_xlabel("I (C=16)")
        ax_left.grid(alpha=0.3)

        # C sweep (I fixed)
        ax_right = axes[row, 1]
        I_fixed = 0.10
        C_vals = C_line
        preds_C = predict(coeff, np.full_like(C_vals, I_fixed), C_vals, beta_lookup)
        ax_right.plot(C_vals, preds_C, label="Regression", color="#1f77b4")
        subset = df[np.isclose(df["I"], I_fixed)]
        ax_right.scatter(subset["C"], subset[coeff], color="#ff7f0e", label="Data", zorder=3)
        if row == len(COEFFICIENTS) - 1:
            ax_right.set_xlabel("C (I=0.10)")
        ax_right.grid(alpha=0.3)
        if row == 0:
            ax_left.set_title("I sweep (C=16)")
            ax_right.set_title("C sweep (I=0.10)")

    handles, labels = axes[0, 0].get_legend_handles_labels()
    fig.legend(handles, labels, loc="upper center", ncol=2)
    fig.tight_layout(rect=[0, 0, 1, 0.97])
    fig.savefig(FIG_DIR / "coeff_dependency_grid.png", dpi=300)
    plt.close(fig)


def make_prediction_vs_observed(df: pd.DataFrame) -> None:
    """Scatter actual vs predicted for each coefficient."""
    fig, axes = plt.subplots(2, 3, figsize=(12, 8))
    axes = axes.flatten()
    for ax, coeff in zip(axes, COEFFICIENTS):
        actual = df[coeff].values
        predicted = df[f"{coeff}_pred"].values
        ax.scatter(actual, predicted, c="#1f77b4", edgecolor="k")
        min_val = min(actual.min(), predicted.min())
        max_val = max(actual.max(), predicted.max())
        ax.plot([min_val, max_val], [min_val, max_val], "k--", lw=1)
        ax.set_title(f"{coeff} (R²={df.attrs['R2'][coeff]:.3f})")
        ax.set_xlabel("Actual")
        ax.set_ylabel("Predicted")
        ax.grid(alpha=0.3)
    fig.tight_layout()
    fig.savefig(FIG_DIR / "pred_vs_obs_grid.png", dpi=300)
    plt.close(fig)


def make_residual_map(df: pd.DataFrame) -> None:
    """Plot residuals on I–C plane."""
    fig, axes = plt.subplots(2, 3, figsize=(12, 8), sharex=True, sharey=True)
    axes = axes.flatten()
    for ax, coeff in zip(axes, COEFFICIENTS):
        residuals = df[f"{coeff}_resid"].values
        vmax = np.max(np.abs(residuals))
        sc = ax.scatter(df["I"], df["C"], c=residuals, cmap="coolwarm", vmin=-vmax, vmax=vmax, s=60, edgecolor="k")
        ax.set_title(f"{coeff} residuals")
        ax.set_xlabel("I")
        ax.set_ylabel("C")
        ax.grid(alpha=0.3)
        cbar = fig.colorbar(sc, ax=ax, shrink=0.75)
        cbar.ax.set_ylabel("Pred - Actual", rotation=270, labelpad=12)
    fig.tight_layout()
    fig.savefig(FIG_DIR / "residual_map_grid.png", dpi=300)
    plt.close(fig)


def make_surface_contours(df: pd.DataFrame, beta_lookup: Dict[str, np.ndarray]) -> None:
    """Plot coefficient magnitude across the continuous I–C plane."""
    I_vals = np.linspace(0.005, 0.35, 150)
    C_vals = np.linspace(8.0, 27.0, 150)
    I_mesh, C_mesh = np.meshgrid(I_vals, C_vals)

    fig, axes = plt.subplots(2, 3, figsize=(14, 9), sharex=True, sharey=True)
    axes = axes.flatten()
    for ax, coeff in zip(axes, COEFFICIENTS):
        Z = predict(coeff, I_mesh.ravel(), C_mesh.ravel(), beta_lookup).reshape(I_mesh.shape)
        levels = 20
        cf = ax.contourf(I_mesh, C_mesh, Z, levels=levels, cmap="viridis")
        ax.scatter(df["I"], df["C"], s=15, c="white", edgecolor="k")
        rect = Rectangle((0.01, 10.0), 0.29, 15.0, linewidth=1.5, edgecolor="white", facecolor="none", linestyle="--")
        ax.add_patch(rect)
        ax.set_title(f"{coeff}(I, C)")
        ax.set_xlabel("I")
        ax.set_ylabel("C")
        ax.grid(alpha=0.1, color="white")
        cbar = fig.colorbar(cf, ax=ax, shrink=0.75)
        cbar.ax.set_ylabel(coeff)
    fig.suptitle("Coefficient contours (dashed box = measured domain)")
    fig.tight_layout(rect=[0, 0, 1, 0.96])
    fig.savefig(FIG_DIR / "coeff_surface_contours.png", dpi=300)
    plt.close(fig)


def make_velocity_deficit_comparison(df: pd.DataFrame, beta_lookup: Dict[str, np.ndarray]) -> None:
    """Compare CFD data, per-case fit, and regression model for I=0.05, C=16."""
    case_I = 0.05
    case_C = 16.0
    file_name = f"result_I{case_I:0.4f}".replace(".", "p") + f"_C{case_C:0.4f}".replace(".", "p") + ".csv"
    file_path = CFD_DIR / file_name
    if not file_path.exists():
        print(f"[WARN] CFD data for {case_I=} {case_C=} not found; skipping velocity deficit plot.")
        return

    raw = pd.read_csv(file_path)
    raw["r"] = raw["y"].abs()
    U_inf = raw.loc[raw["x"] < -4.8, "u"].mean()

    case_row = df[(df["I"] == case_I) & (df["C"] == case_C)]
    if case_row.empty:
        print(f"[WARN] Summary row for I={case_I}, C={case_C} not found.")
        return
    row = case_row.iloc[0]
    summary_coeffs = {coeff: row[coeff] for coeff in COEFFICIENTS}
    regression_coeffs = {coeff: predict(coeff, np.array([case_I]), np.array([case_C]), beta_lookup)[0] for coeff in COEFFICIENTS}

    def C_func(x: float, params: Dict[str, float]) -> float:
        return params["C0"] * (1.0 + params["c"] * x) ** (-params["n"])

    def sigma_func(x: float, params: Dict[str, float]) -> float:
        return params["a2"] * x**2 + params["a1"] * x + params["a0"]

    def deficit_profile(x: float, r_values: np.ndarray, params: Dict[str, float]) -> np.ndarray:
        Cx = C_func(x, params)
        sigma_x = sigma_func(x, params)
        return Cx * np.exp(-(r_values**2) / (2.0 * sigma_x**2))

    x_samples = [2.0, 4.0, 6.0, 8.0]
    r_line = np.linspace(0.0, 4.0, 400)
    fig, axes = plt.subplots(2, 2, figsize=(12, 10), sharex=True, sharey=True)
    axes = axes.flatten()
    for ax, x_sec in zip(axes, x_samples):
        mask = np.abs(raw["x"] - x_sec) < 0.01
        sec = raw[mask].copy()
        if sec.empty:
            continue
        sec = sec.sort_values("r")
        deficit_data = 1.0 - sec["u"] / U_inf
        ax.scatter(sec["r"], deficit_data, label="CFD", color="k", s=12)
        ax.plot(r_line, deficit_profile(x_sec, r_line, summary_coeffs), label="Per-case fit", color="#d62728")
        ax.plot(r_line, deficit_profile(x_sec, r_line, regression_coeffs), label="Regression", color="#1f77b4", linestyle="--")
        ax.set_title(f"x = {x_sec}")
        ax.set_xlabel("r")
        ax.set_ylabel("ΔU / U∞")
        ax.grid(alpha=0.3)
    handles, labels = axes[0].get_legend_handles_labels()
    fig.legend(handles, labels, loc="upper center", ncol=3)
    fig.suptitle("Velocity deficit profiles (I=0.05, C=16)")
    fig.tight_layout(rect=[0, 0, 1, 0.95])
    fig.savefig(FIG_DIR / "velocity_deficit_profiles_I0p05_C16.png", dpi=300)
    plt.close(fig)


def main() -> None:
    if not DATA_FILE.exists():
        raise FileNotFoundError(f"{DATA_FILE} not found.")

    df = pd.read_csv(DATA_FILE)
    beta_lookup: Dict[str, np.ndarray] = {}
    r2_scores: Dict[str, float] = {}

    for coeff in COEFFICIENTS:
        basis = "extended" if coeff == "n" else "linear"
        X = build_design_matrix(df["I"].values, df["C"].values, basis)
        beta, y_pred, r2 = solve_regression(X, df[coeff].values)
        df[f"{coeff}_pred"] = y_pred
        df[f"{coeff}_resid"] = y_pred - df[coeff].values
        beta_lookup[coeff] = beta
        r2_scores[coeff] = float(r2)

    df.attrs["R2"] = r2_scores
    corr = df[COEFFICIENTS].corr()

    summary_payload = {
        "R2": r2_scores,
        "betas": {k: beta_lookup[k].tolist() for k in COEFFICIENTS},
        "correlation_matrix": corr.round(4).to_dict(),
        "residuals": {
            coeff: summarize_residuals(df, coeff, df[f"{coeff}_resid"].values)
            for coeff in COEFFICIENTS
        },
    }
    with open(ANALYSIS_DIR / "analysis_summary.json", "w") as fh:
        json.dump(summary_payload, fh, indent=2)

    df.to_csv(ANALYSIS_DIR / "model_predictions_with_residuals.csv", index=False)

    make_dependency_grid(df, beta_lookup)
    make_prediction_vs_observed(df)
    make_residual_map(df)
    make_surface_contours(df, beta_lookup)
    make_velocity_deficit_comparison(df, beta_lookup)


if __name__ == "__main__":
    main()
