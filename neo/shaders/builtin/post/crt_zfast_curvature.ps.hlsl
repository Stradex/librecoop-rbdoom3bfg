/*
    CRT Shader by EasyMode
    License: GPL

    A flat CRT shader ideally for 1080p or higher displays.

    Recommended Settings:

    Video
    - Aspect Ratio:  4:3
    - Integer Scale: Off

    Shader
    - Filter: Nearest
    - Scale:  Don't Care

    Example RGB Mask Parameter Settings:

    Aperture Grille (Default)
    - Dot Width:  1
    - Dot Height: 1
    - Stagger:    0

    Lottes' Shadow Mask
    - Dot Width:  2
    - Dot Height: 1
    - Stagger:    3
*/


#include <global_inc.hlsl>


// *INDENT-OFF*
Texture2D t_CurrentRender	: register( t0 VK_DESCRIPTOR_SET( 0 ) );
Texture2D t_BlueNoise		: register( t1 VK_DESCRIPTOR_SET( 0 ) );

SamplerState LinearSampler	: register(s0 VK_DESCRIPTOR_SET( 1 ) );
SamplerState samp1			: register(s1 VK_DESCRIPTOR_SET( 1 ) ); // blue noise 256

struct PS_IN
{
	float4 position : SV_Position;
	float2 texcoord0 : TEXCOORD0_centroid;
};

struct PS_OUT
{
	float4 color : SV_Target0;
};
// *INDENT-ON*

#define TEX2D(c) dilate(t_CurrentRender.Sample( LinearSampler, c ).rgba)
#define FIX(c) max(abs(c), 1e-5)

// Set to 0 to use linear filter and gain speed
#define ENABLE_LANCZOS 1

float4 dilate( float4 col )
{
#if 0
	// FIXME
	float4 x = lerp( _float4( 1.0 ), col, params.DILATION );
	return col * x;
#else
	return col;
#endif
}

float curve_distance( float x, float sharp )
{

	/*
	    apply half-circle s-curve to distance for sharper (more pixelated) interpolation
	    single line formula for Graph Toy:
	    0.5 - sqrt(0.25 - (x - step(0.5, x)) * (x - step(0.5, x))) * sign(0.5 - x)
	*/

	float x_step = step( 0.5, x );
	float curve = 0.5 - sqrt( 0.25 - ( x - x_step ) * ( x - x_step ) ) * sign( 0.5 - x );

	return lerp( x, curve, sharp );
}

float4x4 get_color_matrix( float2 co, float2 dx )
{
	return float4x4( TEX2D( co - dx ), TEX2D( co ), TEX2D( co + dx ), TEX2D( co + 2.0 * dx ) );
}

float3 filter_lanczos( float4 coeffs, float4x4 color_matrix )
{
	float4 col        = mul( color_matrix, coeffs );
	float4 sample_min = min( color_matrix[1], color_matrix[2] );
	float4 sample_max = max( color_matrix[1], color_matrix[2] );

	col = clamp( col, sample_min, sample_max );

	return col.rgb;
}

void main( PS_IN fragment, out PS_OUT result )
{
	// revised version from RetroArch

	struct Params
	{
		float BRIGHT_BOOST;
		float DILATION;
		float GAMMA_INPUT;
		float GAMMA_OUTPUT;
		float MASK_SIZE;
		float MASK_STAGGER;
		float MASK_STRENGTH;
		float MASK_DOT_HEIGHT;
		float MASK_DOT_WIDTH;
		float SCANLINE_CUTOFF;
		float SCANLINE_BEAM_WIDTH_MAX;
		float SCANLINE_BEAM_WIDTH_MIN;
		float SCANLINE_BRIGHT_MAX;
		float SCANLINE_BRIGHT_MIN;
		float SCANLINE_STRENGTH;
		float SHARPNESS_H;
		float SHARPNESS_V;
	};

	Params params;
	params.BRIGHT_BOOST = 1.0;
	params.DILATION = 1.0;
	params.GAMMA_INPUT = 2.0;
	params.GAMMA_OUTPUT = 1.8;
	params.MASK_SIZE = 1.0;
	params.MASK_STAGGER = 0.0;
	params.MASK_STRENGTH = 1.0;
	params.MASK_DOT_HEIGHT = 1.0;
	params.MASK_DOT_WIDTH = 1.0;
	params.SCANLINE_CUTOFF = 400.0;
	params.SCANLINE_BEAM_WIDTH_MAX = 1.5;
	params.SCANLINE_BEAM_WIDTH_MIN = 1.5;
	params.SCANLINE_BRIGHT_MAX = 0.65;
	params.SCANLINE_BRIGHT_MIN = 0.35;
	params.SCANLINE_STRENGTH = 1.0;
	params.SHARPNESS_H = 0.5;
	params.SHARPNESS_V = 1.0;

#if 0
	float2 uv = fragment.texcoord0.xy;
	float2 uv2 = 2.0 * uv - 1.0;
	float2 offset = uv2 / 3.0; //float(params.curvature);

	offset *= offset; // Distance from the center, squared

	uv2 += uv2 * ( offset.yx );
	uv2 = 0.5 * uv2 + 0.5;

	uv = uv2;

	float3 col = t_CurrentRender.Sample( LinearSampler, uv2 ).rgb;// + _float3( 0.1 );
	//float3 col = texture(iChannel0, uv2).xyz + float3(0.1);
	col = ( uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0 )
		  ? col
		  : float3( 0.0, 0.0, 0.0 );
	col = col * ( 0.9 + 0.1 * sin( uv.y * 2.0 * rpWindowCoord.w ) );

	result.color = float4( col, 1.0 );
#else

	float4 sourceSize;
	sourceSize.xy = rpWindowCoord.zw;
	sourceSize.zw = float2( 1.0, 1.0 ) / rpWindowCoord.zw;

	float4 outputSize = sourceSize;

	float2 vTexCoord = fragment.texcoord0.xy;
	float2 dx     = float2( sourceSize.z, 0.0 );
	float2 dy     = float2( 0.0, sourceSize.w );
	float2 pix_co = vTexCoord * sourceSize.xy - float2( 0.5, 0.5 );
	float2 tex_co = ( floor( pix_co ) + float2( 0.5, 0.5 ) ) * sourceSize.zw;
	float2 dist   = frac( pix_co );
	float curve_x;
	float3 col, col2;

#if ENABLE_LANCZOS
	curve_x = curve_distance( dist.x, params.SHARPNESS_H * params.SHARPNESS_H );

	float4 coeffs = PI * float4( 1.0 + curve_x, curve_x, 1.0 - curve_x, 2.0 - curve_x );

	coeffs = FIX( coeffs );
	coeffs = 2.0 * sin( coeffs ) * sin( coeffs * 0.5 ) / ( coeffs * coeffs );
	coeffs /= dot( coeffs, _float4( 1.0 ) );

	col  = filter_lanczos( coeffs, get_color_matrix( tex_co, dx ) );
	col2 = filter_lanczos( coeffs, get_color_matrix( tex_co + dy, dx ) );
#else
	curve_x = curve_distance( dist.x, params.SHARPNESS_H );

	col  = lerp( TEX2D( tex_co ).rgb,      TEX2D( tex_co + dx ).rgb,      curve_x );
	col2 = lerp( TEX2D( tex_co + dy ).rgb, TEX2D( tex_co + dx + dy ).rgb, curve_x );
#endif

	col = lerp( col, col2, curve_distance( dist.y, params.SHARPNESS_V ) );
	col = pow( col, _float3( params.GAMMA_INPUT / ( params.DILATION + 1.0 ) ) );

	float luma        = dot( float3( 0.2126, 0.7152, 0.0722 ), col );
	float bright      = ( max( col.r, max( col.g, col.b ) ) + luma ) * 0.5;
	float scan_bright = clamp( bright, params.SCANLINE_BRIGHT_MIN, params.SCANLINE_BRIGHT_MAX );
	float scan_beam   = clamp( bright * params.SCANLINE_BEAM_WIDTH_MAX, params.SCANLINE_BEAM_WIDTH_MIN, params.SCANLINE_BEAM_WIDTH_MAX );
	float scan_weight = 1.0 - pow( cos( vTexCoord.y * 2.0 * PI * sourceSize.y ) * 0.5 + 0.5, scan_beam ) * params.SCANLINE_STRENGTH;

	float mask   = 1.0 - params.MASK_STRENGTH;
	float2 mod_fac = floor( vTexCoord * outputSize.xy * sourceSize.xy / ( sourceSize.xy * float2( params.MASK_SIZE, params.MASK_DOT_HEIGHT * params.MASK_SIZE ) ) );
	int dot_no   = int( fmod( ( mod_fac.x + fmod( mod_fac.y, 2.0 ) * params.MASK_STAGGER ) / params.MASK_DOT_WIDTH, 3.0 ) );
	float3 mask_weight;

	if( dot_no == 0 )
	{
		mask_weight = float3( 1.0,  mask, mask );
	}
	else if( dot_no == 1 )
	{
		mask_weight = float3( mask, 1.0,  mask );
	}
	else
	{
		mask_weight = float3( mask, mask, 1.0 );
	}

	if( sourceSize.y >= params.SCANLINE_CUTOFF )
	{
		scan_weight = 1.0;
	}

	col2 = col.rgb;
	col *= _float3( scan_weight );
	col  = lerp( col, col2, scan_bright );
	col *= mask_weight;
	col  = pow( col, _float3( 1.0 / params.GAMMA_OUTPUT ) );

	result.color = float4( col * params.BRIGHT_BOOST, 1.0 );
#endif
}
