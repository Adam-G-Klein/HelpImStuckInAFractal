// Noise library pasted into the generated NOISE region and every node preview.
// Not a standalone shader: it has no shader_type and declares no uniforms, only
// the helper functions the node emit()s call. The compiler pastes the whole file
// whenever any node is wired to the Output; unused functions cost nothing.
//
// All functions are deterministic in a `seed` so a node's Seed parameter moves
// the field without changing its character. Written for GL Compatibility / WebGL
// 2 (GLSL ES 3.0): every loop here has constant bounds.

// 3D hash -> [0, 1), after iq (https://iquilezles.org/articles/).
float nz_hash1(vec3 p, float seed) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3) + seed);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

// Value noise with quintic interpolation, in [0, 1].
float nz_value3(vec3 x, float seed) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float n000 = nz_hash1(i + vec3(0.0, 0.0, 0.0), seed);
	float n100 = nz_hash1(i + vec3(1.0, 0.0, 0.0), seed);
	float n010 = nz_hash1(i + vec3(0.0, 1.0, 0.0), seed);
	float n110 = nz_hash1(i + vec3(1.0, 1.0, 0.0), seed);
	float n001 = nz_hash1(i + vec3(0.0, 0.0, 1.0), seed);
	float n101 = nz_hash1(i + vec3(1.0, 0.0, 1.0), seed);
	float n011 = nz_hash1(i + vec3(0.0, 1.0, 1.0), seed);
	float n111 = nz_hash1(i + vec3(1.0, 1.0, 1.0), seed);
	return mix(
		mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
		mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y), u.z);
}

// A pseudo-random unit gradient at a lattice point.
vec3 nz_grad3(vec3 p, float seed) {
	vec3 g = vec3(
		nz_hash1(p, seed),
		nz_hash1(p, seed + 19.19),
		nz_hash1(p, seed + 37.37)) * 2.0 - 1.0;
	return normalize(g + vec3(1e-5, 0.0, 0.0));
}

// Perlin-style gradient noise, normalised to roughly [-1, 1].
float nz_perlin3(vec3 x, float seed) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float v = mix(
		mix(mix(dot(nz_grad3(i + vec3(0.0, 0.0, 0.0), seed), f - vec3(0.0, 0.0, 0.0)),
				dot(nz_grad3(i + vec3(1.0, 0.0, 0.0), seed), f - vec3(1.0, 0.0, 0.0)), u.x),
			mix(dot(nz_grad3(i + vec3(0.0, 1.0, 0.0), seed), f - vec3(0.0, 1.0, 0.0)),
				dot(nz_grad3(i + vec3(1.0, 1.0, 0.0), seed), f - vec3(1.0, 1.0, 0.0)), u.x), u.y),
		mix(mix(dot(nz_grad3(i + vec3(0.0, 0.0, 1.0), seed), f - vec3(0.0, 0.0, 1.0)),
				dot(nz_grad3(i + vec3(1.0, 0.0, 1.0), seed), f - vec3(1.0, 0.0, 1.0)), u.x),
			mix(dot(nz_grad3(i + vec3(0.0, 1.0, 1.0), seed), f - vec3(0.0, 1.0, 1.0)),
				dot(nz_grad3(i + vec3(1.0, 1.0, 1.0), seed), f - vec3(1.0, 1.0, 1.0)), u.x), u.y), u.z);
	return clamp(v * 1.1547, -1.0, 1.0);
}

// Worley / cellular F1: the distance to the nearest of one feature point per
// lattice cell, jittered by `jitter`. Roughly [0, 1] for jitter near 1.
float nz_worley3(vec3 x, float seed, float jitter) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	float d = 1.0e9;
	for (int a = -1; a <= 1; a++) {
		for (int b = -1; b <= 1; b++) {
			for (int c = -1; c <= 1; c++) {
				vec3 g = vec3(float(a), float(b), float(c));
				vec3 o = vec3(
					nz_hash1(i + g, seed),
					nz_hash1(i + g, seed + 11.1),
					nz_hash1(i + g, seed + 23.3));
				vec3 r = g + jitter * o - f;
				d = min(d, dot(r, r));
			}
		}
	}
	return sqrt(d);
}
