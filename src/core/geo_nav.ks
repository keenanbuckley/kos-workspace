// geo_nav.ks provides functions for navigating around a sphere using geocordinates
@lazyGlobal off.

function geoAngle {
    parameter g0.
    parameter g1.
    parameter g2.

    return geoHeading(g0, g1) - geoHeading(g0, g2).
}

function geoHeading {
    parameter g0.
    parameter g1.

    return mod(360+arctan2(sin(g1:lng-g0:lng)*cos(g1:lat),cos(g0:lat)*sin(g1:lat)-sin(g0:lat)*cos(g1:lat)*cos(g1:lng-g0:lng)),360).
}

function geoArclength {
    parameter g1.
    parameter g2.
    parameter radius.

    local A is sin((g1:lat-g2:lat)/2)^2 + cos(g1:lat)*cos(g2:lat)*sin((g1:lng-g2:lng)/2)^2.
    return radius*constant():PI*arctan2(sqrt(A),sqrt(1-A))/90.
}
