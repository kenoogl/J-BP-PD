module CoeffModel

export coefficients_from_IC, coefficients_two_region, I_RANGE, CT_RANGE

const I_RANGE = (0.01, 0.30)
const CT_RANGE = (10.0, 22.0)

# =============================================================================
# 旧モデル（単一ガウス領域）の回帰係数
# =============================================================================
# 回帰で得た係数（[1, I, Ct, I*Ct] の順）
const C0_COEFFS = (0.06105314, -0.01726864, 0.01902056, -0.01955448)
const C_COEFFS  = (-5.79656796e-3, 1.78585416, -1.69088139e-3, -1.05227425e-2)
const A2_COEFFS = (-9.70730681e-5, -3.94223996e-3, 6.73269532e-6, -2.77654889e-5)
const A1_COEFFS = (8.37763709e-3, 0.154973707, -1.43378099e-4, 5.78183219e-4)
const A0_COEFFS = (0.21326552, 0.25387813, 0.00252791, -0.00542758)

# =============================================================================
# 新モデル（Jensen + Bastankhah 二領域）の回帰係数
# =============================================================================

# kw: Jensen勾配係数 (拡張基底: [1, I, C, I·C, 1/I, C/I], R²=0.8583)
const KW_COEFFS = (
  -9.18555073e-03,
  +3.11239368e-01,
  +1.69858193e-04,
  -1.18097207e-02,
  +4.40771356e-05,
  +6.72493838e-07,
)

# Ct_eff: 有効推力係数 (基本基底: [1, I, C, I·C], R²=0.945)
const CT_EFF_COEFFS = (
  +1.93033917e-01,
  +1.14861697e-01,
  +2.02774583e-02,
  -3.34105921e-02,
)

# sigmaJ0: Jensen初期半径 (基本基底: [1, I, C, I·C], R²=0.9418)
const SIGMAJ0_COEFFS = (
  +2.04355649e-01,
  +8.09272953e-02,
  +2.21322492e-03,
  -3.60758264e-03,
)

# sigmaG0: ガウス接続点半径 (基本基底: [1, I, C, I·C], R²=0.9763)
const SIGMAG0_COEFFS = (
  +2.53836909e-01,
  +4.65436887e-01,
  +2.35793869e-03,
  -5.51263695e-03,
)

# km: 遠方拡散勾配 (拡張基底: [1, I, C, I·C, 1/I, C/I], R²=0.9717)
const KM_COEFFS = (
  +1.13186663e-02,
  +3.72026280e-02,
  -3.85795327e-05,
  +1.34353468e-04,
  -9.68064442e-05,
  +9.16384886e-07,
)

# x_shift: 接続距離 (基本基底: [1, I, C, I·C], R²=0.4674)
const X_SHIFT_COEFFS = (
  +6.62159932e+00,
  -1.97254894e+01,
  -2.23566740e-02,
  +7.39888239e-02,
)

# n だけは拡張基底 [1, I, Ct, I*Ct, 1/I, Ct/I, 1/I^2, Ct/I^2]
const N_COEFFS = (
    1.00403604e2,   # 1
   -2.20583409e2,   # I
   -3.05515491e1,   # Ct
    8.26105213e1,   # I*Ct
   -1.06836226e1,   # 1/I
    2.32583971e0,   # Ct/I
    1.24013972e-1,  # 1/I^2
   -1.96853750e-2   # Ct/I^2
)

# =============================================================================
# 基底関数
# =============================================================================

linear_combo(coeffs, I, Ct) = coeffs[1] + coeffs[2]*I + coeffs[3]*Ct + coeffs[4]*I*Ct

function extended_combo(coeffs, I, Ct)
    """拡張基底: [1, I, C, I·C, 1/I, C/I]"""
    return coeffs[1] + coeffs[2]*I + coeffs[3]*Ct + coeffs[4]*I*Ct +
           coeffs[5]/I + coeffs[6]*Ct/I
end

function n_combo(I, Ct)
    coeffs = N_COEFFS
    return coeffs[1] +
           coeffs[2]*I +
           coeffs[3]*Ct +
           coeffs[4]*I*Ct +
           coeffs[5]/I +
           coeffs[6]*Ct/I +
           coeffs[7]/(I^2) +
           coeffs[8]*Ct/(I^2)
end

function ensure_range(I, Ct)
    warn = false
    if I < I_RANGE[1] || I > I_RANGE[2]
        warn = true
    end
    if Ct < CT_RANGE[1] || Ct > CT_RANGE[2]
        warn = true
    end
    warn && @warn("I と Ct の回帰適用範囲 (I∈$(I_RANGE), Ct∈$(CT_RANGE)) を外れています。外挿となるため注意してください。")
end

"""
    coefficients_from_IC(I, Ct; check_range=true)

旧モデル: 回帰モデルから (C0, c, n, a2, a1, a0) を返す。
単一ガウス領域モデル用。後方互換性のために残されている。
"""
function coefficients_from_IC(I::Real, Ct::Real; check_range::Bool=true)
    I_val = float(I)
    Ct_val = float(Ct)
    check_range && ensure_range(I_val, Ct_val)

    C0 = linear_combo(C0_COEFFS, I_val, Ct_val)
    c  = linear_combo(C_COEFFS, I_val, Ct_val)
    a2 = linear_combo(A2_COEFFS, I_val, Ct_val)
    a1 = linear_combo(A1_COEFFS, I_val, Ct_val)
    a0 = linear_combo(A0_COEFFS, I_val, Ct_val)
    n  = n_combo(I_val, Ct_val)

    return (; C0, c, n, a2, a1, a0)
end

"""
    coefficients_two_region(I, Ct; check_range=true)

新モデル: Jensen + Bastankhah 二領域モデルのパラメータを返す。

返り値:
- kw: Jensen勾配係数
- Ct_eff: 有効推力係数（0〜1範囲）
- sigmaJ0: Jensen初期半径
- sigmaG0: ガウス接続点半径
- km: 遠方拡散勾配
- x_shift: 接続距離（正値に制約）

回帰精度:
- kw: R²=0.86, RMSE=0.0055
- Ct_eff: R²=0.95, RMSE=0.021
- sigmaJ0: R²=0.94, RMSE=0.0021
- sigmaG0: R²=0.98, RMSE=0.0061
- km: R²=0.97, RMSE=0.0010
- x_shift: R²=0.47, RMSE=2.02
"""
function coefficients_two_region(I::Real, Ct::Real; check_range::Bool=true)
    I_val = float(I)
    Ct_val = float(Ct)
    check_range && ensure_range(I_val, Ct_val)

    kw = extended_combo(KW_COEFFS, I_val, Ct_val)
    Ct_eff = linear_combo(CT_EFF_COEFFS, I_val, Ct_val)
    sigmaJ0 = linear_combo(SIGMAJ0_COEFFS, I_val, Ct_val)
    sigmaG0 = linear_combo(SIGMAG0_COEFFS, I_val, Ct_val)
    km = extended_combo(KM_COEFFS, I_val, Ct_val)
    x_shift = linear_combo(X_SHIFT_COEFFS, I_val, Ct_val)

    # 物理的制約
    kw = max(kw, 0.0)  # 非負
    Ct_eff = clamp(Ct_eff, 0.0, 0.99)  # 0〜1範囲
    sigmaJ0 = max(sigmaJ0, 1e-6)  # 正値
    sigmaG0 = max(sigmaG0, 1e-6)  # 正値
    km = max(km, 0.0)  # 非負
    x_shift = max(x_shift, 0.5)  # 正値（最小0.5D）

    return (; kw, Ct_eff, sigmaJ0, sigmaG0, km, x_shift)
end

end # module
