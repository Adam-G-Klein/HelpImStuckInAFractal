class_name NoisePort
extends RefCounted
## The two things a noise-field graph edge can carry, and what depends on which
## one it is: the slot colour in the editor, the slot tooltip, and what an
## unconnected input reads instead of nothing.
##
## Port types are frozen and ordered: node scripts, saved graphs and the compiler
## all refer to them by index, so append only, never reorder.
##
## FLOAT is a scalar field (one number per sample point); VEC3 is a vector field
## (a position or direction per sample point). An unwired FLOAT input reads the
## port's own default constant; an unwired VEC3 input reads `p`, the sample
## position in fractal coordinates.

enum Type { FLOAT, VEC3 }

const NAMES := ["Float", "Vec3"]

## Slot colours in the editor: a scalar is a cool green, a vector a warm amber.
const COLORS: Array[Color] = [
	Color(0.55, 0.85, 0.65),
	Color(0.95, 0.70, 0.35),
]

const TOOLTIPS := [
	"Float: one number per point — a scalar field. An unwired input reads this port's default constant.",
	"Vec3: three numbers per point — a position or direction field. An unwired input reads p, the sample position in fractal coordinates.",
]


## The GLSL type keyword for a port type.
static func glsl_type(type: int) -> String:
	return "vec3" if type == Type.VEC3 else "float"
