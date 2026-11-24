# Mathematical models, conventions and units

## Signal-to-concentration surrogates

Let `S(t)` be the measured signal and `S0` the mean of the configured baseline
phases.

- Relative T1-DCE: `C(t) = (S(t) - S0) / S0`
- Absolute T1-DCE: `C(t) = S(t) - S0`
- Relative T2*-DSC: `C(t) = -ln(S(t) / S0)`
- Plasma correction of the arterial curve: `Cp(t) = Cblood(t)/(1-Hct)`

These are proportional concentration surrogates, matching the historical
UMMPerfusion enhancement choices. They are not a substitute for a validated
sequence-specific conversion using native T1, TR, flip angle and relaxivity.

## Standard Tofts

`Ct(t) = Ktrans * integral[0..t](Cp(tau) * exp(-kep*(t-tau)) d tau)`

with `kep = Ktrans / ve`.

The convolution is integrated recursively with a trapezoidal rule on the
actual acquisition times. A logarithmic `kep` grid (0.03 to 6 min^-1) is
searched; for each candidate, nonnegative least squares in one coefficient
provides `Ktrans`. Outputs:

- `Ktrans` in min^-1
- `ve` in percent
- `vp = 0` is an internal model assumption
- coefficient of determination `R2`

## Extended Tofts

`Ct(t) = vp*Cp(t) + Ktrans * integral[0..t](Cp(tau) * exp(-kep*(t-tau)) d tau)`

For every `kep` candidate, `Ktrans` and `vp` are solved as a two-column linear
least-squares problem. Physically impossible solutions are rejected. Outputs:
`Ktrans` in min^-1, `ve` in percent, `vp` in percent and `R2`.

## Regularized deconvolution

The discretized indicator-dilution relation is:

`Ct = A(Cp, dt) * R`

where `A` is a lower-triangular convolution matrix and `R` is the tissue
impulse-residue function. The implementation solves:

`R = inverse(A^T A + lambda I) A^T Ct`

Negative residue values are clipped to zero. Outputs follow the historical
UMMPerfusion scaling:

- plasma flow `PF = max(R) * 6000` in mL/100 mL/min
- plasma volume `PV = sum(R)*dt*100` in percent
- mean transit time `MTT = PV_fraction / PF_per_second` in seconds

This ridge solution is numerically stable but not bit-identical to the old
truncated-SVD implementation. It requires separate validation against the
legacy implementation and a trusted reference package.

## Numerical constraints

- Strictly increasing acquisition times.
- At least four phases and at least one baseline phase.
- Registered, equal image geometry across phases.
- Background masking from mean baseline signal.
- Tofts constraints: `0 <= Ktrans <= 5 min^-1`, `0 < ve <= 1.2`,
  `0 <= vp <= 1`.
- Invalid/non-finite fits are written as zero. An entirely invalid result is
  rejected. The interface displays saved-series and opened-window counts.
