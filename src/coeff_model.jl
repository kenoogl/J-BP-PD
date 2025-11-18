module CoeffModel

export coefficients_from_IC, I_RANGE, CT_RANGE

const I_RANGE = (0.01, 0.30)
const CT_RANGE = (10.0, 22.0)

# 回帰で得た係数（[1, I, Ct, I*Ct] の順）
const C0_COEFFS = (0.06105314, -0.01726864, 0.01902056, -0.01955448)
const C_COEFFS  = (-5.79656796e-3, 1.78585416, -1.69088139e-3, -1.05227425e-2)
const A2_COEFFS = (-9.70730681e-5, -3.94223996e-3, 6.73269532e-6, -2.77654889e-5)
const A1_COEFFS = (8.37763709e-3, 0.154973707, -1.43378099e-4, 5.78183219e-4)
const A0_COEFFS = (0.21326552, 0.25387813, 0.00252791, -0.00542758)

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

linear_combo(coeffs, I, Ct) = coeffs[1] + coeffs[2]*I + coeffs[3]*Ct + coeffs[4]*I*Ct

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

回帰モデルから (C0, c, n, a2, a1, a0) を返す。
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

end # module
