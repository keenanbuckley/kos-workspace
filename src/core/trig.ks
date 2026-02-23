// trig.ks provides hyperbolic trigonometric functions not built into kOS
@lazyGlobal off.

function sinh {
    parameter x.
    return (constant:e^x - constant:e^(-x)) / 2.
}

function cosh {
    parameter x.
    return (constant:e^x + constant:e^(-x)) / 2.
}

function asinh {
    parameter x.
    return ln(x + sqrt(x^2 + 1)).
}

function acosh {
    parameter x.
    return ln(x + sqrt(x^2 - 1)).
}
