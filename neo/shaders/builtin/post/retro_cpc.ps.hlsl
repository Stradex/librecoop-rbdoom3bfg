/*
===========================================================================

Doom 3 BFG Edition GPL Source Code
Copyright (C) 1993-2012 id Software LLC, a ZeniMax Media company.
Copyright (C) 2024 Robert Beckebans

This file is part of the Doom 3 BFG Edition GPL Source Code ("Doom 3 BFG Edition Source Code").

Doom 3 BFG Edition Source Code is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Doom 3 BFG Edition Source Code is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Doom 3 BFG Edition Source Code.  If not, see <http://www.gnu.org/licenses/>.

In addition, the Doom 3 BFG Edition Source Code is also subject to certain additional terms. You should have received a copy of these additional terms immediately following the terms and conditions of the GNU General Public License which accompanied the Doom 3 BFG Edition Source Code.  If not, please request a copy in writing from id Software at the address below.

If you have questions concerning this license or the applicable additional terms, you may contact in writing id Software LLC, c/o ZeniMax Media Inc., Suite 120, Rockville, Maryland 20850 USA.

===========================================================================
*/

#include "global_inc.hlsl"


// *INDENT-OFF*
Texture2D t_BaseColor	: register( t0 VK_DESCRIPTOR_SET( 0 ) );
Texture2D t_BlueNoise	: register( t1 VK_DESCRIPTOR_SET( 0 ) );
Texture2D t_Normals		: register( t2 VK_DESCRIPTOR_SET( 0 ) );
Texture2D t_Depth		: register( t3 VK_DESCRIPTOR_SET( 0 ) );

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


#define RESOLUTION_DIVISOR 4.0
#define NUM_COLORS 4 // original 27


float3 Average( float3 pal[NUM_COLORS] )
{
	float3 sum = _float3( 0 );

	for( int i = 0; i < NUM_COLORS; i++ )
	{
		sum += pal[i];
	}

	return sum / float( NUM_COLORS );
}

float3 Deviation( float3 pal[NUM_COLORS] )
{
	float3 sum = _float3( 0 );
	float3 avg = Average( pal );

	for( int i = 0; i < NUM_COLORS; i++ )
	{
		sum += abs( pal[i] - avg );
	}

	return sum / float( NUM_COLORS );
}

// squared distance to avoid the sqrt of distance function
float ColorCompare( float3 a, float3 b )
{
	float3 diff = b - a;
	return dot( diff, diff );
}

// find nearest palette color using Euclidean distance
float3 LinearSearch( float3 c, float3 pal[NUM_COLORS] )
{
	int index = 0;
	float minDist = ColorCompare( c, pal[0] );

	for( int i = 1; i <	NUM_COLORS; i++ )
	{
		float dist = ColorCompare( c, pal[i] );

		if( dist < minDist )
		{
			minDist = dist;
			index = i;
		}
	}

	return pal[index];
}

#define RGB(r, g, b) float3(float(r)/255.0, float(g)/255.0, float(b)/255.0)

// http://www.cse.cuhk.edu.hk/~ttwong/papers/spheremap/spheremap.html
float3 healpix( float3 p )
{
	float a = atan2( p.z, p.x ) * 0.63662;
	float h = 3.0 * abs( p.y );
	float h2 = 0.75 * p.y;
	float2 uv = float2( a + h2, a - h2 );
	h2 = sqrt( 3.0 - h );
	float a2 = h2 * frac( a );
	uv = lerp( uv, float2( -h2 + a2, a2 ), step( 2.0, h ) );

#if 1
	return float3( uv, 1.0 );
#else
	float3 col = spheretex( uv );
	col.x = a * 0.5;

	return HSVToRGB( float3( col.x, 0.8, col.z ) );
#endif
}

// can be either view space or world space depending on rpModelMatrix
float3 ReconstructPosition( float2 S, float depth )
{
	// derive clip space from the depth buffer and screen position
	float2 uv = S * rpWindowCoord.xy;
	float3 ndc = float3( uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0, depth );
	float clipW = -rpProjectionMatrixZ.w / ( -rpProjectionMatrixZ.z - ndc.z );

	float4 clip = float4( ndc * clipW, clipW );

	// camera space position
	float4 csP;
	csP.x = dot4( rpModelMatrixX, clip );
	csP.y = dot4( rpModelMatrixY, clip );
	csP.z = dot4( rpModelMatrixZ, clip );
	csP.w = dot4( rpModelMatrixW, clip );

	csP.xyz /= csP.w;

	return csP.xyz;
}

float3 GetPosition( int2 ssP )
{
	float depth = texelFetch( t_Depth, ssP, 0 ).r;

	// offset to pixel center
	float3 P = ReconstructPosition( float2( ssP ) + _float2( 0.5 ), depth );

	return P;
}

float BlueNoise( float2 n, float x )
{
	float noise = t_BlueNoise.Sample( s_LinearWrap, n.xy * rpJitterTexOffset.xy ).r;

	noise = frac( noise + c_goldenRatioConjugate * rpJitterTexOffset.z * x );

	noise = RemapNoiseTriErp( noise );
	noise = noise * 2.0 - 0.5;

	return noise;
}

// Total number of direct samples to take at each pixel
#define NUM_SAMPLES 11

// This is the number of turns around the circle that the spiral pattern makes.  This should be prime to prevent
// taps from lining up.  This particular choice was tuned for NUM_SAMPLES == 9
#define NUM_SPIRAL_TURNS 7

// If using depth mip levels, the log of the maximum pixel offset before we need to switch to a lower
// miplevel to maintain reasonable spatial locality in the cache
// If this number is too small (< 3), too many taps will land in the same pixel, and we'll get bad variance that manifests as flashing.
// If it is too high (> 5), we'll get bad performance because we're not using the MIP levels effectively
#define LOG_MAX_OFFSET (3)

// This must be less than or equal to the MAX_MIP_LEVEL defined in SAmbientOcclusion.cpp
#define MAX_MIP_LEVEL (5)
#define MIN_MIP_LEVEL 0

#define USE_MIPMAPS 1

static const float radius = 1.0 * METERS_TO_DOOM;
static const float radius2 = radius * radius;
static const float invRadius2 = 1.0 / radius2;

/** Bias to avoid AO in smooth corners, e.g., 0.01m */
static const float bias = 0.01 * METERS_TO_DOOM;

/** intensity / radius^6 */
static const float intensity = 0.6;
static const float intensityDivR6 = intensity / ( radius* radius* radius* radius* radius* radius );

/** The height in pixels of a 1m object if viewed from 1m away.
	You can compute it from your projection matrix.  The actual value is just
	a scale factor on radius; you can simply hardcode this to a constant (~500)
	and make your radius value unitless (...but resolution dependent.)  */
static const float projScale = 500.0;

float fallOffFunction( float vv, float vn, float epsilon )
{
	// A: From the HPG12 paper
	// Note large epsilon to avoid overdarkening within cracks
	//  Assumes the desired result is intensity/radius^6 in main()
	// return float(vv < radius2) * max((vn - bias) / (epsilon + vv), 0.0) * radius2 * 0.6;

	// B: Smoother transition to zero (lowers contrast, smoothing out corners). [Recommended]
	//
	// Epsilon inside the sqrt for rsqrt operation
	float f = max( 1.0 - vv * invRadius2, 0.0 );
	return f * max( ( vn - bias ) * rsqrt( epsilon + vv ), 0.0 );
}

float aoValueFromPositionsAndNormal( float3 C, float3 n_C, float3 Q )
{
	float3 v = Q - C;
	//v = normalize( v );
	float vv = dot( v, v );
	float vn = dot( v, n_C );
	const float epsilon = 0.001;

	// Without the angular adjustment term, surfaces seen head on have less AO
	return fallOffFunction( vv, vn, epsilon ) * lerp( 1.0, max( 0.0, 1.5 * n_C.z ), 0.35 );
}

void computeMipInfo( float ssR, int2 ssP, out int mipLevel, out int2 mipP )
{
	// Derivation:
	//  mipLevel = floor(log(ssR / MAX_OFFSET));
#ifdef GL_EXT_gpu_shader5
	mipLevel = clamp( findMSB( int( ssR ) ) - LOG_MAX_OFFSET, 0, MAX_MIP_LEVEL );
#else
	mipLevel = clamp( int( floor( log2( ssR ) ) ) - LOG_MAX_OFFSET, 0, MAX_MIP_LEVEL );
#endif

	// We need to divide by 2^mipLevel to read the appropriately scaled coordinate from a MIP-map.
	// Manually clamp to the texture size because texelFetch bypasses the texture unit

	// used in newer radiosity
	//mipP = ssP >> mipLevel;

	mipP = clamp( ssP >> mipLevel, _int2( 0 ), textureSize( t_Depth, mipLevel ) - _int2( 1 ) );
}

float3 getOffsetPosition( int2 issC, float2 unitOffset, float ssR, float invCszBufferScale )
{
	int2 ssP = int2( ssR * unitOffset ) + issC;

	float3 P;

	int mipLevel;
	int2 mipP;
	computeMipInfo( ssR, ssP, mipLevel, mipP );

#if USE_MIPMAPS
	// RB: this is the key for fast ambient occlusion - use a hierarchical depth buffer
	// for more information see McGuire12SAO.pdf - Scalable Ambient Obscurance
	// http://graphics.cs.williams.edu/papers/SAOHPG12/
	P.z = t_Depth.Load( int3( mipP, mipLevel ) ).r;
#else
	P.z = t_Depth.Load( int3( mipP, 0 ) ).r;
#endif

	// Offset to pixel center
	P = ReconstructPosition( float2( ssP ) + _float2( 0.5 ), P.z );

	return P;
}

float2 tapLocation( int sampleNumber, float spinAngle, out float ssR )
{
	// Radius relative to ssR
	float alpha = ( float( sampleNumber ) + 0.5 ) * ( 1.0 / float( NUM_SAMPLES ) );
	float angle = alpha * ( float( NUM_SPIRAL_TURNS ) * 6.28 ) + spinAngle;

	ssR = alpha;

	return float2( cos( angle ), sin( angle ) );
}

float sampleAO( int2 issC, float3 C, float3 n_C, float ssDiskRadius, int tapIndex, float randomPatternRotationAngle, float invCszBufferScale )
{
	// Offset on the unit disk, spun for this pixel
	float ssR;
	float2 unitOffset = tapLocation( tapIndex, randomPatternRotationAngle, ssR );

	// Ensure that the taps are at least 1 pixel away
	ssR = max( 0.75, ssR * ssDiskRadius );

	// The occluding point in camera space
	float3 Q = getOffsetPosition( issC, unitOffset, ssR, invCszBufferScale );

	return aoValueFromPositionsAndNormal( C, n_C, Q );
}

float3 ditherRGB( float2 fragPos, float3 quantDeviation )
{
	float2 uvDither = fragPos / ( RESOLUTION_DIVISOR / rpJitterTexScale.x );
	float dither = DitherArray8x8( uvDither ) - 0.5;

	return float3( dither, dither, dither ) * quantDeviation * rpJitterTexScale.y;
}

float2 cubeProject( float3 p )
{
	float2 x = p.zy;
	float2 y = p.xz;
	float2 z = p.xy;

	//select face
	p = abs( p );
	if( p.x > p.y && p.x > p.z )
	{
		return x;
	}
	else if( p.y > p.x && p.y > p.z )
	{
		return y;
	}
	else
	{
		return z;
	}
}

void main( PS_IN fragment, out PS_OUT result )
{
#if 0
	// Amstrad CPC colors https://www.cpcwiki.eu/index.php/CPC_Palette
	const float3 palette[NUM_COLORS] =
	{
		RGB( 0, 0, 0 ),			// black
		RGB( 0, 0, 128 ),		// blue
		RGB( 0, 0, 255 ),		// bright blue
		RGB( 128, 0, 0 ),		// red
		RGB( 128, 0, 128 ),		// magenta
		RGB( 128, 0, 255 ),		// mauve
		RGB( 255, 0, 0 ),		// bright red
		RGB( 255, 0, 128 ),		// purple
		RGB( 255, 0, 255 ),		// bright magenta
		RGB( 0, 128, 0 ),		// green
		RGB( 0, 128, 128 ),		// cyan
		RGB( 0, 128, 255 ),		// sky blue
		RGB( 128, 128, 0 ),		// yellow
		RGB( 128, 128, 128 ),	// white
		RGB( 128, 128, 255 ),	// pastel blue
		RGB( 255, 128, 0 ),		// orange
		RGB( 255, 128, 128 ),	// pink
		RGB( 255, 128, 255 ),	// pastel magenta
		RGB( 0, 255, 0 ),		// bright green
		RGB( 0, 255, 128 ),		// sea green
		RGB( 0, 255, 255 ),		// bright cyan
		RGB( 128, 255, 0 ),		// lime
		RGB( 128, 255, 128 ),	// pastel green
		RGB( 128, 255, 255 ),	// pastel cyan
		RGB( 255, 255, 0 ),		// bright yellow
		RGB( 255, 255, 128 ),	// pastel yellow
		RGB( 255, 255, 255 ),	// bright white

#if 0
		RGB( 16, 16, 16 ),		// black
		RGB( 0, 28, 28 ),		// dark cyan
		RGB( 112, 164, 178 ) * 1.3,	// cyan

#else
		// https://lospec.com/palette-list/2bit-demichrome
		RGB( 33, 30, 32 ),
		RGB( 85, 85, 104 ),
		RGB( 160, 160, 139 ),
		RGB( 233, 239, 236 ),

#endif
	};

#elif 0
	// Tweaked LOSPEC CPC BOY PALETTE which is less saturated by Arne Niklas Jansson
	// https://lospec.com/palette-list/cpc-boy

	const float3 palette[NUM_COLORS] = // 32
	{
		RGB( 0, 0, 0 ),
		RGB( 27, 27, 101 ),
		RGB( 53, 53, 201 ),
		RGB( 102, 30, 37 ),
		RGB( 85, 51, 97 ),
		RGB( 127, 53, 201 ),
		RGB( 188, 53, 53 ),
		RGB( 192, 70, 110 ),
		RGB( 223, 109, 155 ),
		RGB( 27, 101, 27 ),
		RGB( 27, 110, 131 ),
		RGB( 30, 121, 229 ),
		RGB( 121, 95, 27 ),
		RGB( 128, 128, 128 ),
		RGB( 145, 148, 223 ),
		RGB( 201, 127, 53 ),
		RGB( 227, 155, 141 ),
		RGB( 248, 120, 248 ),
		RGB( 53, 175, 53 ),
		RGB( 53, 183, 143 ),
		RGB( 53, 193, 215 ),
		RGB( 127, 201, 53 ),
		RGB( 173, 200, 170 ),
		RGB( 141, 225, 199 ),
		RGB( 225, 198, 67 ),
		RGB( 228, 221, 154 ),
		RGB( 255, 255, 255 ),
		RGB( 238, 234, 224 ),
		RGB( 172, 181, 107 ),
		RGB( 118, 132, 72 ),
		RGB( 63, 80, 63 ),
		RGB( 36, 49, 55 ),
	};

#elif 0

	// NES 1
	// https://lospec.com/palette-list/nintendo-entertainment-system

	const float3 palette[NUM_COLORS] = // 55
	{
		RGB( 0, 0, 0 ),
		RGB( 252, 252, 252 ),
		RGB( 248, 248, 248 ),
		RGB( 188, 188, 188 ),
		RGB( 124, 124, 124 ),
		RGB( 164, 228, 252 ),
		RGB( 60, 188, 252 ),
		RGB( 0, 120, 248 ),
		RGB( 0, 0, 252 ),
		RGB( 184, 184, 248 ),
		RGB( 104, 136, 252 ),
		RGB( 0, 88, 248 ),
		RGB( 0, 0, 188 ),
		RGB( 216, 184, 248 ),
		RGB( 152, 120, 248 ),
		RGB( 104, 68, 252 ),
		RGB( 68, 40, 188 ),
		RGB( 248, 184, 248 ),
		RGB( 248, 120, 248 ),
		RGB( 216, 0, 204 ),
		RGB( 148, 0, 132 ),
		RGB( 248, 164, 192 ),
		RGB( 248, 88, 152 ),
		RGB( 228, 0, 88 ),
		RGB( 168, 0, 32 ),
		RGB( 240, 208, 176 ),
		RGB( 248, 120, 88 ),
		RGB( 248, 56, 0 ),
		RGB( 168, 16, 0 ),
		RGB( 252, 224, 168 ),
		RGB( 252, 160, 68 ),
		RGB( 228, 92, 16 ),
		RGB( 136, 20, 0 ),
		RGB( 248, 216, 120 ),
		RGB( 248, 184, 0 ),
		RGB( 172, 124, 0 ),
		RGB( 80, 48, 0 ),
		RGB( 216, 248, 120 ),
		RGB( 184, 248, 24 ),
		RGB( 0, 184, 0 ),
		RGB( 0, 120, 0 ),
		RGB( 184, 248, 184 ),
		RGB( 88, 216, 84 ),
		RGB( 0, 168, 0 ),
		RGB( 0, 104, 0 ),
		RGB( 184, 248, 216 ),
		RGB( 88, 248, 152 ),
		RGB( 0, 168, 68 ),
		RGB( 0, 88, 0 ),
		RGB( 0, 252, 252 ),
		RGB( 0, 232, 216 ),
		RGB( 0, 136, 136 ),
		RGB( 0, 64, 88 ),
		RGB( 248, 216, 248 ),
		RGB( 120, 120, 120 ),
	};

#elif 0

	// NES Advanced
	// https://lospec.com/palette-list/nes-advanced

	const float3 palette[NUM_COLORS] = // 55
	{
		RGB( 0, 0, 0 ),
		RGB( 38, 35, 47 ),
		RGB( 49, 64, 71 ),
		RGB( 89, 109, 98 ),
		RGB( 146, 156, 116 ),
		RGB( 200, 197, 163 ),
		RGB( 252, 252, 252 ),
		RGB( 27, 55, 127 ),
		RGB( 20, 122, 191 ),
		RGB( 64, 175, 221 ),
		RGB( 178, 219, 244 ),
		RGB( 24, 22, 103 ),
		RGB( 59, 44, 150 ),
		RGB( 112, 106, 225 ),
		RGB( 143, 149, 238 ),
		RGB( 68, 10, 65 ),
		RGB( 129, 37, 147 ),
		RGB( 204, 75, 185 ),
		RGB( 236, 153, 219 ),
		RGB( 63, 0, 17 ),
		RGB( 179, 28, 53 ),
		RGB( 239, 32, 100 ),
		RGB( 242, 98, 130 ),
		RGB( 150, 8, 17 ),
		RGB( 232, 24, 19 ),
		RGB( 167, 93, 105 ),
		RGB( 236, 158, 164 ),
		RGB( 86, 13, 4 ),
		RGB( 196, 54, 17 ),
		RGB( 226, 106, 18 ),
		RGB( 240, 175, 102 ),
		RGB( 42, 26, 20 ),
		RGB( 93, 52, 42 ),
		RGB( 166, 110, 70 ),
		RGB( 223, 156, 110 ),
		RGB( 142, 78, 17 ),
		RGB( 216, 149, 17 ),
		RGB( 234, 209, 30 ),
		RGB( 245, 235, 107 ),
		RGB( 47, 84, 28 ),
		RGB( 90, 131, 27 ),
		RGB( 162, 187, 30 ),
		RGB( 198, 223, 107 ),
		RGB( 15, 69, 15 ),
		RGB( 0, 139, 18 ),
		RGB( 11, 203, 18 ),
		RGB( 62, 243, 63 ),
		RGB( 17, 81, 83 ),
		RGB( 12, 133, 99 ),
		RGB( 4, 191, 121 ),
		RGB( 106, 230, 170 ),
		RGB( 38, 39, 38 ),
		RGB( 81, 79, 76 ),
		RGB( 136, 126, 131 ),
		RGB( 179, 170, 192 ),
	};

#elif 0

	// Atari STE
	// https://lospec.com/palette-list/astron-ste32
	const float3 palette[NUM_COLORS] = // 32
	{
		RGB( 0, 0, 0 ),
		RGB( 192, 64, 80 ),
		RGB( 240, 240, 240 ),
		RGB( 192, 192, 176 ),
		RGB( 128, 144, 144 ),
		RGB( 96, 96, 112 ),
		RGB( 96, 64, 64 ),
		RGB( 64, 48, 32 ),
		RGB( 112, 80, 48 ),
		RGB( 176, 112, 64 ),
		RGB( 224, 160, 80 ),
		RGB( 224, 192, 128 ),
		RGB( 240, 224, 96 ),
		RGB( 224, 128, 48 ),
		RGB( 208, 80, 32 ),
		RGB( 144, 48, 32 ),
		RGB( 96, 48, 112 ),
		RGB( 176, 96, 160 ),
		RGB( 224, 128, 192 ),
		RGB( 192, 160, 208 ),
		RGB( 112, 112, 192 ),
		RGB( 48, 64, 144 ),
		RGB( 32, 32, 64 ),
		RGB( 32, 96, 208 ),
		RGB( 64, 160, 224 ),
		RGB( 128, 208, 224 ),
		RGB( 160, 240, 144 ),
		RGB( 48, 160, 96 ),
		RGB( 48, 64, 48 ),
		RGB( 48, 112, 32 ),
		RGB( 112, 160, 48 ),
		RGB( 160, 208, 80 ),
	};

#elif 0

	// Sega Genesis Evangelion
	// https://lospec.com/palette-list/sega-genesis-evangelion

	const float3 palette[NUM_COLORS] = // 17
	{
		RGB( 207, 201, 179 ),
		RGB( 163, 180, 158 ),
		RGB( 100, 166, 174 ),
		RGB( 101, 112, 141 ),
		RGB( 52, 54, 36 ),
		RGB( 37, 34, 70 ),
		RGB( 39, 28, 21 ),
		RGB( 20, 14, 11 ),
		RGB( 0, 0, 0 ),
		RGB( 202, 168, 87 ),
		RGB( 190, 136, 51 ),
		RGB( 171, 85, 92 ),
		RGB( 186, 47, 74 ),
		RGB( 131, 25, 97 ),
		RGB( 102, 52, 143 ),
		RGB( 203, 216, 246 ),
		RGB( 140, 197, 79 ),
	};

#elif 0

	// https://lospec.com/palette-list/existential-demo
	const float3 palette[NUM_COLORS] = // 8
	{
		RGB( 248, 243, 253 ),
		RGB( 250, 198, 180 ),
		RGB( 154, 218, 231 ),
		RGB( 151, 203, 29 ),
		RGB( 93, 162, 202 ),
		RGB( 218, 41, 142 ),
		RGB( 11, 134, 51 ),
		RGB( 46, 43, 18 ),
	};

#elif 0

	// Gameboy
	const float3 palette[NUM_COLORS] = // 4
	{
		RGB( 27, 42, 9 ),
		RGB( 14, 69, 11 ),
		RGB( 73, 107, 34 ),
		RGB( 154, 158, 63 ),
	};

#else

	// https://lospec.com/palette-list/2bit-demichrome
	const float3 palette[NUM_COLORS] = // 4
	{
		RGB( 33, 30, 32 ),
		RGB( 85, 85, 104 ),
		RGB( 160, 160, 139 ),
		RGB( 233, 239, 236 ),
	};

#endif

	float2 uv = ( fragment.texcoord0 );
	float2 uvPixelated = floor( fragment.position.xy / RESOLUTION_DIVISOR ) * RESOLUTION_DIVISOR;

	float3 quantizationPeriod = _float3( 1.0 / NUM_COLORS );
	float3 quantDeviation = Deviation( palette );

	// get pixellated base color
	float3 color = t_BaseColor.Sample( s_LinearClamp, uvPixelated * rpWindowCoord.xy ).rgb;

	float2 uvDither = uvPixelated;
	//if( rpJitterTexScale.x > 1.0 )
	{
		uvDither = fragment.position.xy / ( RESOLUTION_DIVISOR / rpJitterTexScale.x );
	}
	float dither = DitherArray8x8( uvDither ) - 0.5;

#if 0
	if( uv.y < 0.0625 )
	{
		color = HSVToRGB( float3( uv.x, 1.0, uv.y * 16.0 ) );

		result.color = float4( color, 1.0 );
		return;
	}
	else if( uv.y < 0.125 )
	{
		// quantized
		color = HSVToRGB( float3( uv.x, 1.0, ( uv.y - 0.0625 ) * 16.0 ) );
		color = LinearSearch( color, palette );

		result.color = float4( color, 1.0 );
		return;
	}
	else if( uv.y < 0.1875 )
	{
		// dithered quantized
		color = HSVToRGB( float3( uv.x, 1.0, ( uv.y - 0.125 ) * 16.0 ) );

		color.rgb += float3( dither, dither, dither ) * quantDeviation * rpJitterTexScale.y;
		color = LinearSearch( color, palette );

		result.color = float4( color, 1.0 );
		return;
	}
	else if( uv.y < 0.25 )
	{
		color = _float3( uv.x );
		color = floor( color * NUM_COLORS ) * ( 1.0 / ( NUM_COLORS - 1.0 ) );

		color.rgb += float3( dither, dither, dither ) * quantDeviation * rpJitterTexScale.y;
		color = LinearSearch( color, palette );

		result.color = float4( color, 1.0 );
		return;
	}
#endif

	//color.rgb += float3( dither, dither, dither ) * quantizationPeriod;
	color.rgb += float3( dither, dither, dither ) * quantDeviation * rpJitterTexScale.y;

	// find closest color match from CPC color palette
	color = LinearSearch( color.rgb, palette );

#if 1
	// similar to Obra Dinn

	// triplanar mapping based on reconstructed depth buffer

	int2 ssP = int2( fragment.position.xy );
	float3 C = GetPosition( ssP );
	//float3 n_C = t_Normals.Sample( s_LinearClamp, uv ).rgb;
	float3 n_C = ( ( 2.0 * t_Normals.Sample( s_LinearClamp, uv ).rgb ) - 1.0 );

	//result.color = float4( n_C * 0.5 + 0.5, 1.0 );
	//return;

#if 0
	// SSAO to test the ReconstructPosition function
	float vis = 1.0;

	//float randomPatternRotationAngle = BlueNoise( float2( ssP.xy ), 10.0 ) * 10.0;
	float randomPatternRotationAngle = InterleavedGradientNoise( ssP.xy ) * 10.0;

	float ssDiskRadius = -projScale * radius / C.z;

	float sum = 0.0;
	for( int i = 0; i < NUM_SAMPLES; ++i )
	{
		sum += sampleAO( ssP, C, n_C, ssDiskRadius, i, randomPatternRotationAngle, 1.0 );
	}

	float A = pow( max( 0.0, 1.0 - sqrt( sum * ( 3.0 / float( NUM_SAMPLES ) ) ) ), intensity );

	const float minRadius = 3.0;
	vis = lerp( 1.0, A, saturate( ssDiskRadius - minRadius ) );
	result.color = float4( _float3( vis ), 1.0 );
	return;
#endif

	// triplanar UVs
	float3 worldPos = C;

	float2 uvX = worldPos.zy; // x facing plane
	float2 uvY = worldPos.xz; // y facing plane
	float2 uvZ = worldPos.xy; // z facing plane

#if 0
	uvX = abs( uvX );
	uvY = abs( uvY );
	uvZ = abs( uvZ );
#endif

#if 0
	uvX *= 4.0;
	uvY *= 4.0;
	uvZ *= 4.0;
#endif

#if 0
	uvX = round( float2( uvX.x, uvX.y ) );
	uvY = round( float2( uvY.x, uvY.y ) );
	uvZ = round( float2( uvZ.x, uvZ.y ) );
#endif

	// offset UVs to prevent obvious mirroring
	//uvY += 0.33;
	//uvZ += 0.67;

	float3 worldNormal = normalize( abs( n_C ) );
	//float3 worldNormal = normalize( n_C );

	float3 triblend = saturate( pow( worldNormal, 4.0 ) );
	triblend /= max( dot( triblend, float3( 1, 1, 1 ) ), 0.0001 );

#if 0
	// preview blend
	result.color = float4( triblend.xyz, 1.0 );
	return;
#endif

	float3 axisSign = sign( n_C );

#if 0
	uvX.x *= axisSign.x;
	uvY.x *= axisSign.y;
	uvZ.x *= -axisSign.z;
#endif

	//result.color = float4( suv.xy, 0.0, 1.0 );
	//return;

	// FIXME get pixellated base color
	//color = t_BaseColor.Sample( s_LinearClamp, uvPixelated * rpWindowCoord.xy ).rgb;
	color = t_BaseColor.Sample( s_LinearClamp, uv ).rgb;

	float3 colX = ditherRGB( uvX, quantDeviation ) * 2.0;
	float3 colY = ditherRGB( uvY, quantDeviation ) * 2.0;
	float3 colZ = ditherRGB( uvZ, quantDeviation ) * 2.0;

	float3 dither3D = colX * triblend.x + colY * triblend.y + colZ * triblend.z;
	color.rgb += dither3D;

	// find closest color match from CPC color palette
	color = LinearSearch( color.rgb, palette );

#if 0
	float2 uvC = cubeProject( abs( worldPos ) );
	color.rgb = _float3( DitherArray8x8( uvC ) - 0.5 );
#endif

#if 1
	colX = _float3( DitherArray8x8( uvX ) - 0.5 );
	colY = _float3( DitherArray8x8( uvY ) - 0.5 );
	colZ = _float3( DitherArray8x8( uvZ ) - 0.5 );

	dither3D = colX * triblend.x + colY * triblend.y + colZ * triblend.z;
	color.rgb = dither3D;
#endif

#if 0
	colX =  float3( uvZ * 0.5 + 0.5, 0.0 );
	colY = _float3( 0 );
	colZ = _float3( 0 );

	dither3D = colX * triblend.x + colY * triblend.y + colZ * triblend.z;
	color.rgb = dither3D;
#endif

#if 0
	color = _float3( uvZ.x * 0.5 + 0.5 );
	color = dither3D;
	color = floor( color * NUM_COLORS ) * ( 1.0 / ( NUM_COLORS - 1.0 ) );
	color.rgb += dither3D;
	//color.rgb += float3( dither, dither, dither ) * quantDeviation * rpJitterTexScale.y;
	color = LinearSearch( color, palette );
#endif

#endif // cubic mapping

	//color.rgb = float3( suv.xy * 0.5 + 0.5, 1.0 );
	result.color = float4( color, 1.0 );
}
