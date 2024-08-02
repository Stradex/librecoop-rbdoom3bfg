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

SamplerState s_LinearClamp	: register(s0 VK_DESCRIPTOR_SET( 1 ) );
SamplerState s_LinearWrap	: register(s1 VK_DESCRIPTOR_SET( 1 ) ); // blue noise 256


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

#define TEX2D(c) dilate(t_CurrentRender.Sample( s_LinearClamp, c ).rgba)
#define FIX(c) max(abs(c), 1e-5)

// Set to 0 to use linear filter and gain speed
#define ENABLE_LANCZOS 0
#define ENABLE_NTSC 1

#define RESOLUTION_DIVISOR 4.0

float4 dilate( float4 col )
{
#if 1
	// FIXME
	//float4 x = lerp( _float4( 1.0 ), col, params.DILATION );
	float4 x = lerp( _float4( 1.0 ), col, 1.0 );
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

	// transpose for HLSL
	//m = transpose(m);
	//return m;
}

float3 filter_lanczos( float4 coeffs, float4x4 color_matrix )
{
	float4 col        = mul( color_matrix,  coeffs );
	float4 sample_min = min( color_matrix[1], color_matrix[2] );
	float4 sample_max = max( color_matrix[1], color_matrix[2] );

	col = clamp( col, sample_min, sample_max );

	return col.rgb;
}

float mod( float x, float y )
{
	return x - y * floor( x / y );
}

float2 curve( float2 uv, float curvature )
{
	uv = ( uv - 0.5 ) * curvature;
	uv *= 1.1;
	uv.x *= 1.0 + pow( ( abs( uv.y ) / 5.0 ), 2.0 );
	uv.y *= 1.0 + pow( ( abs( uv.x ) / 4.0 ), 2.0 );
	uv  = ( uv / curvature ) + 0.5;
	uv =  uv * 0.92 + 0.04;
	return uv;
}

#if 1
float3 rgb2yiq( float3 c )
{
	return float3(
			   ( 0.2989 * c.x + 0.5959 * c.y + 0.2115 * c.z ),
			   ( 0.5870 * c.x - 0.2744 * c.y - 0.5229 * c.z ),
			   ( 0.1140 * c.x - 0.3216 * c.y + 0.3114 * c.z )
		   );
}

float3 yiq2rgb( float3 c )
{
	return float3(
			   ( 1.0 * c.x +	  1.0 * c.y + 	1.0 * c.z ),
			   ( 0.956 * c.x - 0.2720 * c.y - 1.1060 * c.z ),
			   ( 0.6210 * c.x - 0.6474 * c.y + 1.7046 * c.z )
		   );
}

float2 circle( float start, float points, float p )
{
	float rad = ( 3.141592 * 2.0 * ( 1.0 / points ) ) * ( p + start );
	//return float2(sin(rad), cos(rad));
	return float2( -( .3 + rad ), cos( rad ) );

}

float3 blur( float2 uv, float f, float d )
{
	float t = 0.0;
	float b = 1.0;

	float2 pixelOffset = float2( d + 0.0005 * t, 0 );

	float start = 2.0 / 14.0;
	float2 scale = 0.66 * 4.0 * 2.0 * pixelOffset.xy;

	//t_CurrentRender.Sample( s_LinearClamp, c ).rgb
	float3 N0 = t_CurrentRender.Sample( s_LinearClamp, uv + circle( start, 14.0, 0.0 ) * scale ).rgb;
	float3 N1 = t_CurrentRender.Sample( s_LinearClamp, uv + circle( start, 14.0, 1.0 ) * scale ).rgb;
	float3 N2 = t_CurrentRender.Sample( s_LinearClamp, uv + circle( start, 14.0, 2.0 ) * scale ).rgb;
	float3 N3 = t_CurrentRender.Sample( s_LinearClamp, uv + circle( start, 14.0, 3.0 ) * scale ).rgb;
	float3 N4 = t_CurrentRender.Sample( s_LinearClamp, uv + circle( start, 14.0, 4.0 ) * scale ).rgb;
	float3 N5 = t_CurrentRender.Sample( s_LinearClamp, uv + circle( start, 14.0, 5.0 ) * scale ).rgb;
	float3 N6 = t_CurrentRender.Sample( s_LinearClamp, uv + circle( start, 14.0, 6.0 ) * scale ).rgb;
	float3 N7 = t_CurrentRender.Sample( s_LinearClamp, uv + circle( start, 14.0, 7.0 ) * scale ).rgb;
	float3 N8 = t_CurrentRender.Sample( s_LinearClamp, uv + circle( start, 14.0, 8.0 ) * scale ).rgb;
	float3 N9 = t_CurrentRender.Sample( s_LinearClamp, uv + circle( start, 14.0, 9.0 ) * scale ).rgb;
	float3 N10 = t_CurrentRender.Sample( s_LinearClamp, uv + circle( start, 14.0, 10.0 ) * scale ).rgb;
	float3 N11 = t_CurrentRender.Sample( s_LinearClamp, uv + circle( start, 14.0, 11.0 ) * scale ).rgb;
	float3 N12 = t_CurrentRender.Sample( s_LinearClamp, uv + circle( start, 14.0, 12.0 ) * scale ).rgb;
	float3 N13 = t_CurrentRender.Sample( s_LinearClamp, uv + circle( start, 14.0, 13.0 ) * scale ).rgb;
	float3 N14 = t_CurrentRender.Sample( s_LinearClamp, uv ).rgb;

	float4 clr = t_CurrentRender.Sample( s_LinearClamp, uv );
	float W = 1.0 / 15.0;

	clr.rgb =
		( N0 * W ) +
		( N1 * W ) +
		( N2 * W ) +
		( N3 * W ) +
		( N4 * W ) +
		( N5 * W ) +
		( N6 * W ) +
		( N7 * W ) +
		( N8 * W ) +
		( N9 * W ) +
		( N10 * W ) +
		( N11 * W ) +
		( N12 * W ) +
		( N13 * W ) +
		( N14 * W );

	return  float3( clr.xyz ) * b;
}



float3 get_blurred_pixel( float2 uv )
{
	float d = 0.0;
	float s = 0.0;

	float e = min( 0.30, pow( max( 0.0, cos( uv.y * 4.0 + 0.3 ) - 0.75 ) * ( s + 0.5 ) * 1.0, 3.0 ) ) * 25.0;

	d = 0.051 + abs( sin( s / 4.0 ) );
	float c = max( 0.0001, 0.002 * d );
	float2 uvo = uv;
	// uv.x+=.1*d;

	float3 fragColor;
	fragColor.xyz = blur( uv, 0.0, c + c * ( uv.x ) );
	float y = rgb2yiq( fragColor.xyz ).r;

	uv.x += 0.01 * d;
	c *= 6.0;
	fragColor.xyz = blur( uv, 0.333, c );
	float i = rgb2yiq( fragColor.xyz ).g;

	uv.x += 0.005 * d;
	c *= 2.50;
	fragColor.xyz = blur( uv, 0.666, c );
	float q = rgb2yiq( fragColor.xyz ).b;

	fragColor.xyz = yiq2rgb( float3( y, i, q ) ) - pow( s + e * 2.0, 3.0 );
	fragColor.xyz *= smoothstep( 1.0, .999, uv.x - 0.1 );

	return fragColor;
}
#endif


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
	params.BRIGHT_BOOST = 1.5;
	params.DILATION = 1.0;
	params.GAMMA_INPUT = 2.4;
	params.GAMMA_OUTPUT = 2.5;
	params.MASK_SIZE = 1.0;
	params.MASK_STAGGER = 0.0;
	params.MASK_STRENGTH = 0.4;
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


	float4 outputSize;
	outputSize.xy = rpWindowCoord.zw;
	outputSize.zw = float2( 1.0, 1.0 ) / rpWindowCoord.zw;

#if 1
	float4 sourceSize = outputSize;
#else
	float4 sourceSize;
	sourceSize.xy = rpWindowCoord.zw / float2( 4, 4.4 ); //RESOLUTION_DIVISOR;
	sourceSize.zw = float2( 1.0, 1.0 ) / sourceSize.xy;
#endif

	float2 vTexCoord = fragment.texcoord0.xy;

#if 0
	if( rpWindowCoord.x > 0.0 )
	{
		vTexCoord = curve( vTexCoord, 2.0 );
	}
#endif

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

#elif ENABLE_NTSC
	col = col2 = get_blurred_pixel( vTexCoord );
#else
	curve_x = curve_distance( dist.x, params.SHARPNESS_H );

	col  = lerp( TEX2D( tex_co ).rgb,      TEX2D( tex_co + dx ).rgb,      curve_x );
	col2 = lerp( TEX2D( tex_co + dy ).rgb, TEX2D( tex_co + dx + dy ).rgb, curve_x );
#endif

	col = lerp( col, col2, curve_distance( dist.y, params.SHARPNESS_V ) );
	col = pow( col, _float3( params.GAMMA_INPUT ) ); /// ( params.DILATION + 1.0 ) ) );

	float luma        = dot( float3( 0.2126, 0.7152, 0.0722 ), col );
	float bright      = ( max( col.r, max( col.g, col.b ) ) + luma ) * 0.5;
	float scan_bright = clamp( bright, params.SCANLINE_BRIGHT_MIN, params.SCANLINE_BRIGHT_MAX );
	float scan_beam   = clamp( bright * params.SCANLINE_BEAM_WIDTH_MAX, params.SCANLINE_BEAM_WIDTH_MIN, params.SCANLINE_BEAM_WIDTH_MAX );
	float scan_weight = 1.0 - pow( cos( vTexCoord.y * 2.0 * PI * sourceSize.y / RESOLUTION_DIVISOR ) * 0.5 + 0.5, scan_beam ) * params.SCANLINE_STRENGTH;

	float mask   = 1.0 - params.MASK_STRENGTH;
	float2 mod_fac = floor( vTexCoord * outputSize.xy * sourceSize.xy / ( sourceSize.xy * float2( params.MASK_SIZE, params.MASK_DOT_HEIGHT * params.MASK_SIZE ) ) );
	int dot_no   = int( mod( ( mod_fac.x + mod( mod_fac.y, 2.0 ) * params.MASK_STAGGER ) / params.MASK_DOT_WIDTH, 3.0 ) );
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

#if 0
	if( sourceSize.y >= params.SCANLINE_CUTOFF )
	{
		scan_weight = 1.0;
	}
#endif

	col2 = col.rgb;
	col *= _float3( scan_weight );
	col  = lerp( col, col2, scan_bright );
	col *= mask_weight;
	col  = pow( col, _float3( 1.0 / params.GAMMA_OUTPUT ) );

	//col = col2;
	//col = _float3( scan_weight );
	//col = float3( scan_bright, scan_beam, scan_weight );

	result.color = float4( col * params.BRIGHT_BOOST, 1.0 );
}
