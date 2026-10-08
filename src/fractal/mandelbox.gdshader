shader_type canvas_item;
// Mandelbox raymarcher. Written from the design spec's algorithm; nothing is
// copied from icefractal.com. All float math is highp (WebGL 2 => float32),
// which is Godot's canvas_item default.

uniform vec3 eye;
uniform vec3 cam_right;
uniform vec3 cam_up;
uniform vec3 cam_forward;
uniform float tan_half_fov;
uniform float aspect;
uniform float scale;
uniform float min_r2;
uniform float fixed_r2;
uniform float fold_limit;
uniform float precision;  // the view's precision already divided by its detail
uniform int color_mode;
uniform bool julia_enabled;
uniform vec3 julia_point;
uniform float box_half;
// Level of detail with distance (see hit_eps) and the step budget.
uniform float detail_range;
uniform float detail_falloff;
uniform float near_dist;
uniform int coarse_steps;
uniform int fine_steps;

// NOISE:BEGIN
float noise_displace(vec3 p) { return 0.0; }
float noise_step_scale() { return 1.0; }
vec3 noise_tint(vec3 col, vec3 p) { return col; }
// NOISE:END

// The hit threshold at ray distance t: the pixel cone precision * t (detail is
// folded into `precision` on the CPU, so the defaults are bit-for-bit the plain
// cone), coarsened by (t / start)^falloff past start = detail_range x the
// camera's distance to the nearest surface. Mirrors FractalParams.hit_epsilon.
float hit_eps(float t) {
	float e = precision * t;
	float start = detail_range * near_dist;
	if (detail_falloff > 0.0 && t > start) {
		e *= pow(t / start, detail_falloff);
	}
	return e;
}

// Mandelbox distance estimate, up to `iters` iterations (<= 32).
float de(vec3 p, int iters) {
	vec3 c = julia_enabled ? julia_point : p;
	vec3 z = p;
	float dz = 1.0;
	for (int i = 0; i < 32; i++) {
		if (i >= iters) { break; }
		z = clamp(z, -fold_limit, fold_limit) * 2.0 - z;
		float r2 = dot(z, z);
		float k = 1.0;
		if (r2 < min_r2) {
			k = fixed_r2 / min_r2;
		} else if (r2 < fixed_r2) {
			k = fixed_r2 / r2;
		}
		z *= k;
		dz *= k;
		z = scale * z + c;
		dz = -dz * scale + 1.0;
	}
	return length(z) / abs(dz) + noise_displace(p);
}

// The "Ice Fractal" field: a 16-iteration Mandelbox orbit from z=0, c=q, no
// derivative, offset by -8. Not a true distance; its gradient gives the look.
float field(vec3 q) {
	vec3 z = vec3(0.0);
	vec3 c = q;
	for (int i = 0; i < 16; i++) {
		z = clamp(z, -fold_limit, fold_limit) * 2.0 - z;
		float r2 = dot(z, z);
		float k = 1.0;
		if (r2 < min_r2) {
			k = fixed_r2 / min_r2;
		} else if (r2 < fixed_r2) {
			k = fixed_r2 / r2;
		}
		z *= k;
		z = scale * z + c;
	}
	return length(z) - 8.0 + noise_displace(q);
}

// Central-difference normal from the high-precision estimator.
vec3 calc_normal(vec3 v, float delta) {
	vec2 e = vec2(delta, 0.0);
	return normalize(vec3(
		de(v + e.xyy, 32) - de(v - e.xyy, 32),
		de(v + e.yxy, 32) - de(v - e.yxy, 32),
		de(v + e.yyx, 32) - de(v - e.yyx, 32)));
}

// The Ice Fractal normal: field at the half-scale base point h = v/2, offset
// samples at the full-scale point + 0.01. Not a true gradient, by design.
vec3 calc_nf(vec3 v, vec3 h) {
	float lw = field(h);
	vec3 g = vec3(
		field(v + vec3(0.01, 0.0, 0.0)) - lw,
		field(v + vec3(0.0, 0.01, 0.0)) - lw,
		field(v + vec3(0.0, 0.0, 0.01)) - lw) / 0.01;
	return normalize(g);
}

// Six-segment rainbow ramp: red->yellow->green->cyan->blue->magenta->red.
vec3 hue(float q) {
	q = clamp(q, 0.0, 0.999999);
	float h6 = q * 6.0;
	float x = 1.0 - abs(mod(h6, 2.0) - 1.0);
	if (h6 < 1.0) { return vec3(1.0, x, 0.0); }
	else if (h6 < 2.0) { return vec3(x, 1.0, 0.0); }
	else if (h6 < 3.0) { return vec3(0.0, 1.0, x); }
	else if (h6 < 4.0) { return vec3(0.0, x, 1.0); }
	else if (h6 < 5.0) { return vec3(x, 0.0, 1.0); }
	return vec3(1.0, 0.0, x);
}

// Ray vs axis-aligned cube of half-size `half_size`, centred at the origin.
// Returns vec2(t_enter, t_exit); a miss has t_exit < max(t_enter, 0).
vec2 box_intersect(vec3 ro, vec3 rd, float half_size) {
	// Guard against exactly axis-aligned rays: floor each |component| at 1e-9
	// (keeping its sign), so 1.0/rd never produces an infinity or NaN.
	vec3 sgn = vec3(rd.x >= 0.0 ? 1.0 : -1.0, rd.y >= 0.0 ? 1.0 : -1.0, rd.z >= 0.0 ? 1.0 : -1.0);
	vec3 safe_rd = sgn * max(abs(rd), vec3(1e-9));
	vec3 inv = 1.0 / safe_rd;
	vec3 n = inv * ro;
	vec3 k = abs(inv) * half_size;
	vec3 t1 = -n - k;
	vec3 t2 = -n + k;
	float t_enter = max(max(t1.x, t1.y), t1.z);
	float t_exit = min(min(t2.x, t2.y), t2.z);
	return vec2(t_enter, t_exit);
}

void fragment() {
	vec2 ndc = (UV - 0.5) * 2.0;
	ndc.y = -ndc.y;  // +y up
	vec3 dir = normalize(cam_forward
		+ ndc.x * aspect * tan_half_fov * cam_right
		+ ndc.y * tan_half_fov * cam_up);

	vec3 bg = (color_mode == 5 || color_mode == 6) ? vec3(1.0) : vec3(0.0);

	vec2 tb = box_intersect(eye, dir, box_half);
	if (tb.y < max(tb.x, 0.0)) {
		COLOR = vec4(bg, 1.0);
	} else {
		float t_exit = tb.y;
		float total = max(tb.x, 0.0);
		bool left_cube = false;

		// Phase 1: low precision (N=16), up to coarse_steps (<= 384) steps.
		int n1 = coarse_steps;
		for (int i = 0; i < 384; i++) {
			if (i >= coarse_steps) { break; }
			vec3 pos = eye + dir * total;
			float d = de(pos, 16);
			if (d < hit_eps(total) * 2.0) { n1 = i; break; }
			total += d * noise_step_scale();
			if (total > t_exit) { left_cube = true; break; }
		}

		// Phase 2: high precision (N=32), up to fine_steps (<= 128) steps,
		// continuing on.
		int n2 = fine_steps;
		if (!left_cube) {
			for (int i = 0; i < 128; i++) {
				if (i >= fine_steps) { break; }
				vec3 pos = eye + dir * total;
				float d = de(pos, 32);
				if (d < hit_eps(total)) { n2 = i; break; }
				total += d * noise_step_scale();
				if (total > t_exit) { left_cube = true; break; }
			}
		}

		if (left_cube) {
			COLOR = vec4(bg, 1.0);  // the only miss is leaving the cube
		} else {
			// Step-count shading stays on the original 128-step scale whatever the
			// budget, so a ray that hits looks the same; one that ran out is 1.
			float ce = n2 == fine_steps ? 1.0 : min(float(n1 + n2) / 128.0, 1.0);
			float inv = 1.0 - ce;
			if (color_mode == 0) {
				COLOR = vec4(vec3(inv), 1.0);  // Grayscale needs no normal: stay cheap
			} else {
				vec3 v = eye + dir * total;
			vec3 h = v * 0.5;
			vec3 eh = eye * 0.5;
			float delta = hit_eps(total) * 40.0;

			// Normal: NF for modes 1..9 outside Julia mode, N otherwise.
			vec3 n;
			if (color_mode >= 1 && color_mode <= 9 && !julia_enabled) {
				n = calc_nf(v, h);
			} else {
				n = calc_normal(v, delta);
			}

			vec3 ldir = normalize(2.0 * eh - h);
			float lgt = abs(dot(n, ldir));
			lgt = 0.5 * lgt + pow(lgt, 160.0) + 0.1;
			vec3 base = vec3(lgt) * (-n * 0.25 + 0.75) + vec3(0.0, 0.0, 0.2);

				vec3 col;
				if (color_mode == 1) {
				col = base * vec3(inv + 0.5, 2.0 * inv * inv + 0.5, 5.0 * pow(inv, 4.0) + 0.5);
			} else if (color_mode == 2) {
				col = base * vec3(max(lgt * ce, inv), max(ce, inv), max(0.5 * lgt * ce, inv));
			} else if (color_mode == 3) {
				float q = dot(h, h) / 4.0;
				col = hue(q) * ce + 0.5 * lgt;
			} else if (color_mode == 4) {
				float q = dot(h, h) / 4.0;
				col = hue(q) * inv;
			} else if (color_mode == 8) {
				float q = n.z * 0.5 + 0.5 - 0.1;
				col = hue(q) * inv;
			} else if (color_mode == 5) {
				float avg = (base.r + base.g + base.b) / 3.0;
				col = base * vec3(lgt * max(lgt * ce, inv), lgt + avg, inv + lgt);
			} else if (color_mode == 6) {
				float avg = (base.r + base.g + base.b) / 3.0;
				col = base * vec3(lgt * max(lgt * ce, inv), lgt + avg, inv + lgt) + vec3(ce * ce);
			} else if (color_mode == 7) {
				float avg = (base.r + base.g + base.b) / 3.0;
				col = vec3(1.0 - 2.0 * ce * (lgt + 0.5), avg * inv, inv * (lgt + 0.5));
			} else if (color_mode == 9) {
				col = vec3(inv * inv, 1.0 - 1.9 * ce * ce, 1.17 - ce * ce);
			} else if (color_mode == 16) {
				col = clamp(vec3(inv * inv, 1.0 - 1.9 * ce * ce, 1.17 - ce * ce), 0.0, 1.0) * (lgt + 0.5);
			} else if (color_mode == 15) {
				vec3 nv = vec3(dot(n, cam_right), dot(n, cam_up), dot(n, -cam_forward));
				float lv = pow(max(0.0, nv.z), 4.0);
				vec3 n2v = normalize(nv + vec3(0.5, 0.5, 0.0));
				col = (n2v + 1.0) * 0.5 * (lv - 2.0 * ce + 0.5);
			} else if (color_mode == 14) {
				vec3 nv = vec3(dot(n, cam_right), dot(n, cam_up), dot(n, -cam_forward));
				float lv = pow(max(0.0, nv.z), 4.0);
				col = (0.75 - ce) * 2.0 * vec3(lv, lv * lv, lv * ce);
			} else {
				col = vec3(inv);
			}
				COLOR = vec4(noise_tint(col, v), 1.0);
			}
		}
	}
}
