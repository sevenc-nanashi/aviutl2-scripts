/*
    Based on "cleanEdge" by torcado
	https://gist.github.com/torcado194/e2794f5a4b22049ac0a41f972d14c329

	Copyright (c) 2022 torcado
	Permission is hereby granted, free of charge, to any person
	obtaining a copy of this software and associated documentation
	files (the "Software"), to deal in the Software without
	restriction, including without limitation the rights to use,
	copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the
	Software is furnished to do so, subject to the following
	conditions:
	The above copyright notice and this permission notice shall be
	included in all copies or substantial portions of the Software.
	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
	EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
	OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
	NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
	HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
	WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
	FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
	OTHER DEALINGS IN THE SOFTWARE.
*/

Texture2D tex0 : register(t0);
SamplerState sampler0 : register(s0);

cbuffer cb0 : register(b0)
{
    float min_x;
    float min_y;
    float base_w;
    float base_h;
    float center_x;
    float center_y;
    float scale_x;
    float scale_y;
    float angle;
    // cleanEdge params
    // highest_color in 0..1 each channel
    float highest_r;
    float highest_g;
    float highest_b;
    // thresholds are expected in 0..1
    float similar_threshold;
    // line width (typical 0..4, 0.707 for 45deg nice look)
    float line_width;
};

#ifndef DEFINE_THIS_MACRO_IN_MAIN_LUA
// Enables 2:1 slopes
#define ENABLE_SLOPE
// Cleans up small slope transitions
#define ENABLE_CLEANUP
#endif

float2 rotate_point(float x, float y, float angle)
{
    float cos_a = cos(angle);
    float sin_a = sin(angle);
    float rx = cos_a * x - sin_a * y;
    float ry = sin_a * x + cos_a * y;
    return float2(rx, ry);
}

float4 get_pixel(float2 xy)
{
	if (xy.x < 0 || xy.x >= base_w || xy.y < 0 || xy.y >= base_h)
	{
		// NOTE: sampler = "dot"は範囲外を透明にするという仕様になっているけど一応明示的に透明にする
		return float4(0, 0, 0, 0);
	}

	float2 uv = float2(xy.x / base_w, xy.y / base_h);
	return tex0.Sample(sampler0, uv);
}

// Helpers ported from GLSL implementation
bool similar(float4 col1, float4 col2)
{
    return ((col1.a == 0.0 && col2.a == 0.0) || distance(col1, col2) <= similar_threshold);
}

bool similar3(float4 c1, float4 c2, float4 c3)
{
    return similar(c1, c2) && similar(c2, c3);
}

bool similar4(float4 c1, float4 c2, float4 c3, float4 c4)
{
    return similar(c1, c2) && similar(c2, c3) && similar(c3, c4);
}

bool similar5(float4 c1, float4 c2, float4 c3, float4 c4, float4 c5)
{
    return similar(c1, c2) && similar(c2, c3) && similar(c3, c4) && similar(c4, c5);
}

bool higher(float4 thisCol, float4 otherCol)
{
    if (similar(thisCol, otherCol)) return false;
    if (thisCol.a == otherCol.a)
    {
        float3 highest = float3(highest_r, highest_g, highest_b);
        return distance(thisCol.rgb, highest) < distance(otherCol.rgb, highest);
    }
    else
    {
        return thisCol.a > otherCol.a;
    }
}

float cd(float4 col1, float4 col2)
{
    return distance(col1, col2);
}

float distToLine(float2 testPt, float2 pt1, float2 pt2, float2 dir)
{
    float2 lineDir = pt2 - pt1;
    float2 perpDir = float2(lineDir.y, -lineDir.x);
    float2 dirToPt1 = pt1 - testPt;
    return (dot(perpDir, dir) > 0.0 ? 1.0 : -1.0) * dot(normalize(perpDir), dirToPt1);
}

// Returns float4(-1) if slice not applied, else the chosen color.
float4 sliceDist(
    float2 base_point, float2 main_dir, float2 point_dir,
    float4 ub, float4 u, float4 uf, float4 uff,
    float4 b, float4 c, float4 f, float4 ff,
    float4 db, float4 d, float4 df, float4 dff,
    float4 ddb, float4 dd, float4 ddf)
{
    float min_width;
    float max_width;
#ifdef ENABLE_SLOPE
    min_width = 0.45;
    max_width = 1.142;
#else
    min_width = 0.0;
    max_width = 1.4;
#endif
    float local_line_width = max(min_width, min(max_width, line_width));
    base_point = main_dir * (base_point - 0.5) + 0.5; // flip point by main_dir

    // edge detection
    float dist_against = 4.0 * cd(f, d) + cd(uf, c) + cd(c, db) + cd(ff, df) + cd(df, dd);
    float dist_towards = 4.0 * cd(c, df) + cd(u, f) + cd(f, dff) + cd(b, d) + cd(d, ddf);
    bool should_slice = (dist_against < dist_towards) || ((dist_against < dist_towards + 0.001) && !higher(c, f));
    if (similar4(f, d, b, u) && similar4(uf, df, db, ub) && !similar(c, f))
    {
        should_slice = false; // checkerboard edge case
    }
    if (!should_slice) return float4(-1.0, -1.0, -1.0, -1.0);

    float dist = 1.0;
    bool flip = false;
    float2 center = float2(0.5, 0.5);

#ifdef ENABLE_SLOPE
    // lower shallow 2:1 slant
    if (similar3(f, d, db) && !similar3(f, d, b) && !similar(uf, db))
    {
        if (similar(c, df) && higher(c, f))
        {
            // no flip
        }
        else
        {
            if (higher(c, f)) flip = true;
            if (similar(u, f) && !similar(c, df) && !higher(c, u)) flip = true;
        }

        if (flip)
        {
            dist = local_line_width - distToLine(base_point, center + point_dir * float2(1.5, -1.0), center + point_dir * float2(-0.5, 0.0), -point_dir);
        }
        else
        {
            dist = distToLine(base_point, center + point_dir * float2(1.5, 0.0), center + point_dir * float2(-0.5, 1.0), point_dir);
        }

#ifdef ENABLE_CLEANUP
        if (!flip && similar(c, uf) && !(similar3(c, uf, uff) && !similar3(c, uf, ff) && !similar(d, uff)))
        {
            float dist2 = distToLine(base_point, center + point_dir * float2(2.0, -1.0), center + point_dir * float2(-0.0, 1.0), point_dir);
            dist = min(dist, dist2);
        }
#endif

        dist -= (local_line_width / 2.0);
        return (dist <= 0.0) ? ((cd(c, f) <= cd(c, d)) ? f : d) : float4(-1.0, -1.0, -1.0, -1.0);
    }
    // forward steep 2:1 slant
    else if (similar3(uf, f, d) && !similar3(u, f, d) && !similar(uf, db))
    {
        if (similar(c, df) && higher(c, d))
        {
            // no flip
        }
        else
        {
            if (higher(c, d)) flip = true;
            if (similar(b, d) && !similar(c, df) && !higher(c, d)) flip = true;
        }

        if (flip)
        {
            dist = local_line_width - distToLine(base_point, center + point_dir * float2(0.0, -0.5), center + point_dir * float2(-1.0, 1.5), -point_dir);
        }
        else
        {
            dist = distToLine(base_point, center + point_dir * float2(1.0, -0.5), center + point_dir * float2(0.0, 1.5), point_dir);
        }

#ifdef ENABLE_CLEANUP
        if (!flip && similar(c, db) && !(similar3(c, db, ddb) && !similar3(c, db, dd) && !similar(f, ddb)))
        {
            float dist2 = distToLine(base_point, center + point_dir * float2(1.0, 0.0), center + point_dir * float2(-1.0, 2.0), point_dir);
            dist = min(dist, dist2);
        }
#endif

        dist -= (local_line_width / 2.0);
        return (dist <= 0.0) ? ((cd(c, f) <= cd(c, d)) ? f : d) : float4(-1.0, -1.0, -1.0, -1.0);
    }
#endif // ENABLE_SLOPE

    // 45 diagonal
    if (similar(f, d))
    {
        if (similar(c, df) && higher(c, f))
        {
            if (!similar(c, dd) && !similar(c, ff))
            {
                flip = true;
            }
        }
        else
        {
            if (higher(c, f)) flip = true;
            if (!similar(c, b) && similar4(b, f, d, u)) flip = true;
        }

        // single pixel 2:1 slope, don't flip
        if (((similar(f, db) && similar3(u, f, df)) || (similar(uf, d) && similar3(b, d, df))) && !similar(c, df))
        {
            flip = true;
        }

        if (flip)
        {
            dist = local_line_width - distToLine(base_point, center + point_dir * float2(1.0, -1.0), center + point_dir * float2(-1.0, 1.0), -point_dir);
        }
        else
        {
            dist = distToLine(base_point, center + point_dir * float2(1.0, 0.0), center + point_dir * float2(0.0, 1.0), point_dir);
        }

#ifdef ENABLE_SLOPE
#ifdef ENABLE_CLEANUP
        if (!flip && similar3(c, uf, uff) && !similar3(c, uf, ff) && !similar(d, uff))
        {
            float dist2 = distToLine(base_point, center + point_dir * float2(1.5, 0.0), center + point_dir * float2(-0.5, 1.0), point_dir);
            dist = max(dist, dist2);
        }
        if (!flip && similar3(ddb, db, c) && !similar3(dd, db, c) && !similar(ddb, f))
        {
            float dist2 = distToLine(base_point, center + point_dir * float2(1.0, -0.5), center + point_dir * float2(0.0, 1.5), point_dir);
            dist = max(dist, dist2);
        }
#endif
#endif

        dist -= (local_line_width / 2.0);
        return (dist <= 0.0) ? ((cd(c, f) <= cd(c, d)) ? f : d) : float4(-1.0, -1.0, -1.0, -1.0);
    }

#ifdef ENABLE_SLOPE
    // far corner of shallow slant
    else if (similar3(ff, df, d) && !similar3(ff, df, c) && !similar(uff, d))
    {
        if (similar(f, dff) && higher(f, ff))
        {
            // no flip
        }
        else
        {
            if (higher(f, ff)) flip = true;
            if (similar(uf, ff) && !similar(f, dff) && !higher(f, uf)) flip = true;
        }
        if (flip)
        {
            dist = local_line_width - distToLine(base_point, center + point_dir * float2(2.5, -1.0), center + point_dir * float2(0.5, 0.0), -point_dir);
        }
        else
        {
            dist = distToLine(base_point, center + point_dir * float2(2.5, 0.0), center + point_dir * float2(0.5, 1.0), point_dir);
        }
        dist -= (local_line_width / 2.0);
        return (dist <= 0.0) ? ((cd(f, ff) <= cd(f, df)) ? ff : df) : float4(-1.0, -1.0, -1.0, -1.0);
    }
    // far corner of steep slant
    else if (similar3(f, df, dd) && !similar3(c, df, dd) && !similar(f, ddb))
    {
        if (similar(d, ddf) && higher(d, dd))
        {
            // no flip
        }
        else
        {
            if (higher(d, dd)) flip = true;
            if (similar(db, dd) && !similar(d, ddf) && !higher(d, dd)) flip = true;
        }
        if (flip)
        {
            dist = local_line_width - distToLine(base_point, center + point_dir * float2(0.0, 0.5), center + point_dir * float2(-1.0, 2.5), -point_dir);
        }
        else
        {
            dist = distToLine(base_point, center + point_dir * float2(1.0, 0.5), center + point_dir * float2(0.0, 2.5), point_dir);
        }
        dist -= (local_line_width / 2.0);
        return (dist <= 0.0) ? ((cd(d, df) <= cd(d, dd)) ? df : dd) : float4(-1.0, -1.0, -1.0, -1.0);
    }
#endif

    return float4(-1.0, -1.0, -1.0, -1.0);
}

float4 transform(float4 pos: SV_Position, float2 uv: TEXCOORD) : SV_Target
{
    float new_x = min_x + pos.x;
    float new_y = min_y + pos.y;

    float rel_x = new_x - center_x;
    float rel_y = new_y - center_y;

    float2 rotated = rotate_point(rel_x, rel_y, -angle);
    float2 scaled = float2(rotated.x / scale_x, rotated.y / scale_y);

    float sample_x = scaled.x + center_x;
    float sample_y = scaled.y + center_y;

    float2 sample_px = ceil(float2(sample_x, sample_y));
    float2 sample_local = frac(float2(sample_x, sample_y));
    float2 point_dir = step(0.5, sample_local) * 2.0 - 1.0;

    // NOTE: back / present / front
	// NOTE: up / center / down
    float4 uub = get_pixel(sample_px + point_dir * float2(-1.0, -2.0));
	float4 uup = get_pixel(sample_px + point_dir * float2(0.0, -2.0));
	float4 uuf = get_pixel(sample_px + point_dir * float2(1.0, -2.0));

	float4 ubb = get_pixel(sample_px + point_dir * float2(-2.0, -1.0));
	float4 ub = get_pixel(sample_px + point_dir * float2(-1.0, -1.0));
	float4 up = get_pixel(sample_px + point_dir * float2(0.0, -1.0));
	float4 uf = get_pixel(sample_px + point_dir * float2(1.0, -1.0));
	float4 uff = get_pixel(sample_px + point_dir * float2(2.0, -1.0));

	float4 cbb = get_pixel(sample_px + point_dir * float2(-2.0, 0.0));
	float4 cb = get_pixel(sample_px + point_dir * float2(-1.0, 0.0));
	float4 cp = get_pixel(sample_px + point_dir * float2(0.0, 0.0));
	float4 cf = get_pixel(sample_px + point_dir * float2(1.0, 0.0));
	float4 cff = get_pixel(sample_px + point_dir * float2(2.0, 0.0));

	float4 dbb = get_pixel(sample_px + point_dir * float2(-2.0, 1.0));
	float4 db = get_pixel(sample_px + point_dir * float2(-1.0, 1.0));
	float4 dp = get_pixel(sample_px + point_dir * float2(0.0, 1.0));
	float4 df = get_pixel(sample_px + point_dir * float2(1.0, 1.0));
	float4 dff = get_pixel(sample_px + point_dir * float2(2.0, 1.0));

	float4 ddb = get_pixel(sample_px + point_dir * float2(-1.0, 2.0));
	float4 ddp = get_pixel(sample_px + point_dir * float2(0.0, 2.0));
	float4 ddf = get_pixel(sample_px + point_dir * float2(1.0, 2.0));

    float4 col = cp;

    // corner, back, up slices (only these 3 quadrants can be reached)
    float4 c_col = sliceDist(sample_local, float2(1.0, 1.0), point_dir,
        ub, up, uf, uff,
        cb, cp, cf, cff,
        db, dp, df, dff,
        ddb, ddp, ddf);

    float4 b_col = sliceDist(sample_local, float2(-1.0, 1.0), point_dir,
        uf, up, ub, ubb,
        cf, cp, cb, cbb,
        df, dp, db, dbb,
        ddf, ddp, ddb);

    float4 u_col = sliceDist(sample_local, float2(1.0, -1.0), point_dir,
        db, dp, df, dff,
        cb, cp, cf, cff,
        ub, up, uf, uff,
        uub, uup, uuf);

    if (c_col.r >= 0.0) col = c_col;
    if (b_col.r >= 0.0) col = b_col;
    if (u_col.r >= 0.0) col = u_col;

    return col;
}

// vim: set ft=hlsl ts=4 sts=4 sw=4 noet:
