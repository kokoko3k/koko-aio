<?xml version="1.0" encoding="UTF-8"?>

<shader language="GLSL">


<fragment scale="1.0" filter="linear"><![CDATA[
uniform sampler2D rubyTexture;
uniform vec2 rubyTextureSize;

vec2 InvSize = 1.0/rubyTextureSize;

// FXAA newer version

/**
 * @license
 * Copyright (c) 2011 NVIDIA Corporation. All rights reserved.
 *
 * TO  THE MAXIMUM  EXTENT PERMITTED  BY APPLICABLE  LAW, THIS SOFTWARE  IS PROVIDED
 * *AS IS*  AND NVIDIA AND  ITS SUPPLIERS DISCLAIM  ALL WARRANTIES,  EITHER  EXPRESS
 * OR IMPLIED, INCLUDING, BUT NOT LIMITED  TO, NONINFRINGEMENT,IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  IN NO EVENT SHALL  NVIDIA 
 * OR ITS SUPPLIERS BE  LIABLE  FOR  ANY  DIRECT, SPECIAL,  INCIDENTAL,  INDIRECT,  OR  
 * CONSEQUENTIAL DAMAGES WHATSOEVER (INCLUDING, WITHOUT LIMITATION,  DAMAGES FOR LOSS 
 * OF BUSINESS PROFITS, BUSINESS INTERRUPTION, LOSS OF BUSINESS INFORMATION, OR ANY 
 * OTHER PECUNIARY LOSS) ARISING OUT OF THE  USE OF OR INABILITY  TO USE THIS SOFTWARE, 
 * EVEN IF NVIDIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
 */ 

/*
FXAA_PRESET - Choose compile-in knob preset 0-5.
------------------------------------------------------------------------------
FXAA_EDGE_THRESHOLD - The minimum amount of local contrast required 
                      to apply algorithm.
                      1.0/3.0  - too little
                      1.0/4.0  - good start
                      1.0/8.0  - applies to more edges
                      1.0/16.0 - overkill
------------------------------------------------------------------------------
FXAA_EDGE_THRESHOLD_MIN - Trims the algorithm from processing darks.
                          Perf optimization.
                          1.0/32.0 - visible limit (smaller isn't visible)
                          1.0/16.0 - good compromise
                          1.0/12.0 - upper limit (seeing artifacts)
------------------------------------------------------------------------------
FXAA_SEARCH_STEPS - Maximum number of search steps for end of span.
------------------------------------------------------------------------------
FXAA_SEARCH_THRESHOLD - Controls when to stop searching.
                        1.0/4.0 - seems to be the best quality wise
------------------------------------------------------------------------------
FXAA_SUBPIX_TRIM - Controls sub-pixel aliasing removal.
                   1.0/2.0 - low removal
                   1.0/3.0 - medium removal
                   1.0/4.0 - default removal
                   1.0/8.0 - high removal
                   0.0 - complete removal
------------------------------------------------------------------------------
FXAA_SUBPIX_CAP - Insures fine detail is not completely removed.
                  This is important for the transition of sub-pixel detail,
                  like fences and wires.
                  3.0/4.0 - default (medium amount of filtering)
                  7.0/8.0 - high amount of filtering
                  1.0 - no capping of sub-pixel aliasing removal
*/ 

#ifndef FXAA_PRESET
    #define FXAA_PRESET 4
#endif

#if (FXAA_PRESET == 6)
    #define FXAA_EDGE_THRESHOLD      (1.0/3.0)
    #define FXAA_EDGE_THRESHOLD_MIN  (1.0/12.0)
    #define FXAA_SEARCH_STEPS        64
    #define FXAA_SEARCH_THRESHOLD    (1.0/4.0)
    #define FXAA_SUBPIX_CAP          (1.0)
    #define FXAA_SUBPIX_TRIM         (0.0)
#endif

#if (FXAA_PRESET == 3)
    #define FXAA_EDGE_THRESHOLD      (1.0/16.0)
    #define FXAA_EDGE_THRESHOLD_MIN  (1.0/16.0)
    #define FXAA_SEARCH_STEPS        16
    #define FXAA_SEARCH_THRESHOLD    (1.0/4.0)
    #define FXAA_SUBPIX_CAP          (3.0/4.0)
    #define FXAA_SUBPIX_TRIM         (1.0/4.0)
#endif
#if (FXAA_PRESET == 4)
    #define FXAA_EDGE_THRESHOLD      (1.0/8.0)
    #define FXAA_EDGE_THRESHOLD_MIN  (1.0/24.0)
    #define FXAA_SEARCH_STEPS        8
    #define FXAA_SEARCH_THRESHOLD    (1.0/4.0)
    #define FXAA_SUBPIX_CAP          (3.0/4.0)
    #define FXAA_SUBPIX_TRIM         (1.0/8.0)
#endif
#if (FXAA_PRESET == 5)
    #define FXAA_EDGE_THRESHOLD      (1.0/16.0)
    #define FXAA_EDGE_THRESHOLD_MIN  (1.0/12.0)
    #define FXAA_SEARCH_STEPS        32
    #define FXAA_SEARCH_THRESHOLD    (1.0/4.0)
    #define FXAA_SUBPIX_CAP          (7.0/8.0)
    #define FXAA_SUBPIX_TRIM         (1.0/8.0)
#endif

#define FXAA_SUBPIX_TRIM_SCALE (1.0/(1.0 - FXAA_SUBPIX_TRIM))
 
#define FXAA_SUBPIX_TRIM_SCALE (1.0/(1.0 - FXAA_SUBPIX_TRIM))

// Return the luma, the estimation of luminance from rgb inputs.
// This approximates luma using one FMA instruction,
// skipping normalization and tossing out blue.
// FxaaLuma() will range 0.0 to 2.963210702.

float FxaaLuma(vec3 rgb) {
    return rgb.y * (0.587/0.299) + rgb.x;
}

vec3 FxaaLerp3(vec3 a, vec3 b, float amountOfA) {
    return (vec3(-amountOfA) * b) + ((a * vec3(amountOfA)) + b);
}

vec4 FxaaTexOff(sampler2D tex, vec2 pos, ivec2 off, vec2 rcpFrame) {
    float x = pos.x + float(off.x) * rcpFrame.x;
    float y = pos.y + float(off.y) * rcpFrame.y;
    return texture2D(tex, vec2(x, y));
}

// pos is the output of FxaaVertexShader interpolated across screen.
// xy -> actual texture position {0.0 to 1.0}
// rcpFrame should be a uniform equal to  {1.0/frameWidth, 1.0/frameHeight}

vec3 FxaaPixelShader(vec2 pos, sampler2D tex, vec2 rcpFrame)
{
    vec3 rgbN = FxaaTexOff(tex, pos.xy, ivec2( 0,-1), rcpFrame).xyz;
    vec3 rgbW = FxaaTexOff(tex, pos.xy, ivec2(-1, 0), rcpFrame).xyz;
    vec3 rgbM = FxaaTexOff(tex, pos.xy, ivec2( 0, 0), rcpFrame).xyz;
    vec3 rgbE = FxaaTexOff(tex, pos.xy, ivec2( 1, 0), rcpFrame).xyz;
    vec3 rgbS = FxaaTexOff(tex, pos.xy, ivec2( 0, 1), rcpFrame).xyz;
    
    float lumaN = FxaaLuma(rgbN);
    float lumaW = FxaaLuma(rgbW);
    float lumaM = FxaaLuma(rgbM);
    float lumaE = FxaaLuma(rgbE);
    float lumaS = FxaaLuma(rgbS);
    float rangeMin = min(lumaM, min(min(lumaN, lumaW), min(lumaS, lumaE)));
    float rangeMax = max(lumaM, max(max(lumaN, lumaW), max(lumaS, lumaE)));
    
    float range = rangeMax - rangeMin;
    if(range < max(FXAA_EDGE_THRESHOLD_MIN, rangeMax * FXAA_EDGE_THRESHOLD))
    {
        return rgbM;
    }
    
    vec3 rgbL = rgbN + rgbW + rgbM + rgbE + rgbS;
    
    float lumaL = (lumaN + lumaW + lumaE + lumaS) * 0.25;
    float rangeL = abs(lumaL - lumaM);
    float blendL = max(0.0, (rangeL / range) - FXAA_SUBPIX_TRIM) * FXAA_SUBPIX_TRIM_SCALE; 
    blendL = min(FXAA_SUBPIX_CAP, blendL);
    
    vec3 rgbNW = FxaaTexOff(tex, pos.xy, ivec2(-1,-1), rcpFrame).xyz;
    vec3 rgbNE = FxaaTexOff(tex, pos.xy, ivec2( 1,-1), rcpFrame).xyz;
    vec3 rgbSW = FxaaTexOff(tex, pos.xy, ivec2(-1, 1), rcpFrame).xyz;
    vec3 rgbSE = FxaaTexOff(tex, pos.xy, ivec2( 1, 1), rcpFrame).xyz;
    rgbL += (rgbNW + rgbNE + rgbSW + rgbSE);
    rgbL *= vec3(1.0/9.0);
    
    float lumaNW = FxaaLuma(rgbNW);
    float lumaNE = FxaaLuma(rgbNE);
    float lumaSW = FxaaLuma(rgbSW);
    float lumaSE = FxaaLuma(rgbSE);
    
    float edgeVert = 
        abs((0.25 * lumaNW) + (-0.5 * lumaN) + (0.25 * lumaNE)) +
        abs((0.50 * lumaW ) + (-1.0 * lumaM) + (0.50 * lumaE )) +
        abs((0.25 * lumaSW) + (-0.5 * lumaS) + (0.25 * lumaSE));
    float edgeHorz = 
        abs((0.25 * lumaNW) + (-0.5 * lumaW) + (0.25 * lumaSW)) +
        abs((0.50 * lumaN ) + (-1.0 * lumaM) + (0.50 * lumaS )) +
        abs((0.25 * lumaNE) + (-0.5 * lumaE) + (0.25 * lumaSE));
        
    bool horzSpan = edgeHorz >= edgeVert;
    float lengthSign = horzSpan ? -rcpFrame.y : -rcpFrame.x;
    
    if(!horzSpan)
    {
        lumaN = lumaW;
        lumaS = lumaE;
    }
    
    float gradientN = abs(lumaN - lumaM);
    float gradientS = abs(lumaS - lumaM);
    lumaN = (lumaN + lumaM) * 0.5;
    lumaS = (lumaS + lumaM) * 0.5;
    
    if (gradientN < gradientS)
    {
        lumaN = lumaS;
        lumaN = lumaS;
        gradientN = gradientS;
        lengthSign *= -1.0;
    }
    
    vec2 posN;
    posN.x = pos.x + (horzSpan ? 0.0 : lengthSign * 0.5);
    posN.y = pos.y + (horzSpan ? lengthSign * 0.5 : 0.0);
    
    gradientN *= FXAA_SEARCH_THRESHOLD;
    
    vec2 posP = posN;
    vec2 offNP = horzSpan ? vec2(rcpFrame.x, 0.0) : vec2(0.0, rcpFrame.y); 
    float lumaEndN = lumaN;
    float lumaEndP = lumaN;
    bool doneN = false;
    bool doneP = false;
    posN += offNP * vec2(-1.0, -1.0);
    posP += offNP * vec2( 1.0,  1.0);
    
    for(int i = 0; i < FXAA_SEARCH_STEPS; i++) {
        if(!doneN)
        {
            lumaEndN = FxaaLuma(texture2D(tex, posN.xy).xyz);
        }
        if(!doneP)
        {
            lumaEndP = FxaaLuma(texture2D(tex, posP.xy).xyz);
        }
        
        doneN = doneN || (abs(lumaEndN - lumaN) >= gradientN);
        doneP = doneP || (abs(lumaEndP - lumaN) >= gradientN);
        
        if(doneN && doneP)
        {
            break;
        }
        if(!doneN)
        {
            posN -= offNP;
        }
        if(!doneP)
        {
            posP += offNP;
        }
    }
    
    float dstN = horzSpan ? pos.x - posN.x : pos.y - posN.y;
    float dstP = horzSpan ? posP.x - pos.x : posP.y - pos.y;
    bool directionN = dstN < dstP;
    lumaEndN = directionN ? lumaEndN : lumaEndP;
    
    if(((lumaM - lumaN) < 0.0) == ((lumaEndN - lumaN) < 0.0))
    {
        lengthSign = 0.0;
    }
 

    float spanLength = (dstP + dstN);
    dstN = directionN ? dstN : dstP;
    float subPixelOffset = (0.5 + (dstN * (-1.0/spanLength))) * lengthSign;
    vec3 rgbF = texture2D(tex, vec2(
        pos.x + (horzSpan ? 0.0 : subPixelOffset),
        pos.y + (horzSpan ? subPixelOffset : 0.0))).xyz;
    return FxaaLerp3(rgbL, rgbF, blendL); 
}
 
 
void main()
{	
	
	vec3 fxaa_hq = FxaaPixelShader(gl_TexCoord[0].xy, rubyTexture, InvSize.xy);
	gl_FragColor = vec4(fxaa_hq, 1.0); 
}	
]]></fragment>


<fragment scale="1.0" filter="linear"><![CDATA[
    #define DO_SCANLINES	false	//(true)	enable scanlines
    #define s1 				1.00	//(1.00)		even scanlines opacity
    #define s2				0.0		//(0.01)		odd scanlines opacity

	uniform sampler2D rubyTexture;
    void main(void) {
		//Use a vec4 for the color, so that even the alpha channel will be
		//'scanlined' this will come handy later to understand if a line is
		//a scanline or not. (see the bloom function)
        vec4 pixel = texture2D(rubyTexture, gl_TexCoord[0].xy);
        if ( DO_SCANLINES ) {
            if (mod(gl_FragCoord.y, 2.0) < 1.0) {
                    pixel *= s1;
            } else {
                    pixel *= s2;
            }
        }
        gl_FragColor = pixel;
    }

]]></fragment>

<fragment filter="linear"><![CDATA[
	
	#define DO_IN_GLOW		true			//(true)	Input signal glow, disables FIX_SCANLINES
	#define IN_GLOW_ADD		0.0				//0.0		0.0-1.0 glow overflows from the scanlines and image becomes sharper
	#define in_glow_w		4.0				//(1.5)		Input signal blur/glow width tightness
	#define in_glow_h		4.0				//(1.5)		Input signal blur/glow height tightness
	#define in_glow_power	0.8            //(1.35)	Input signal glow strength
	#define in_glow_gamma	1.0				//(5.0)		1.0-9.0, The higher,  the less the glow on dark colors, use integers.
	
	#define FIX_SCANLINES	false			//(true)	Mitigate dephasing when FS-UAE scales the texture
											//          WW: it only works when is true and DO_IN_GLOW is false


	#define DO_RGB_MASK		true			//(true)	Draw rgb mask
	// RGB mask:       R     G     B
    #define m1 vec3 ( 1.0 , 0.0 , 0.0 )    //col 1
    #define m2 vec3 ( 0.0 , 1.0 , 0.0 )    //col 2
    #define m3 vec3 ( 0.0 , 0.0 , 1.0  )   //col 3

	#define VMASK_OVERWHITE			1.0		//how much vmask should affect bright colors
	#define DRKLN_OVERWHITE			1.0		//how much darklines should affect bright colors
	
	#define DO_DARKLINES			true	//(false)	Draw dark screenlines
	#define DO_DARKLINES_VOFFSET    false    //(true)	When drawind darklines, offset them by triads
	#define DARKLINES_PERIOD		2.0		//(4.0)		Draw one darkline every # pixels
	#define DARKLINES_TRANSPARENCY	0.00		//(0.4)		0.0 to 1.0 from opaque to totally transparent
	#define FIX_FOR_INTEL			true	//1.0		There must be a weird bug into the intel shader compiler
														//which leads to absymal performance when doing 
														//halo after darklines.
														//use 1.0 to fix.
	
	#define DO_HALO	   true			  //(true)		Halation on/off
	#define halo_w     1.25            //(0.5)		Halo width tightness
	#define halo_h     1.25            //(0.5)		Halo height tightness
	#define halo_power 1.1001         //(2.0)		Halo strength
	#define halo_gamma 3.0            //(5.0)		1.0-9.0 The higher, the less the halo on dark colors, use integers.

													//conflicts with real scanlines and autozoom.

	#define DO_BLOOM	  		true	//(true)	Blooming
	#define bloom_directions	16.0	//16.0		BLOOM DIRECTIONS More is better but slower)
	#define bloom_quality		2.0		//2.0		BLOOM QUALITY 4.0 - More is better but slower
	#define bloom_size			4.0		//5.0		BLOOM SIZE (Radius)
	#define bloom_gamma			2.0		//3.0		1.0-9.0 integer: restrict bloom to bright colors
	#define bloom_mix			0.05		//0.2		BLOOM final mix 
	#define bloom_over_scanline false	//true		Set it false to spare some gpu cycles if you disabled scanlines in the first fragment.

	#define DO_ALT_BLANK		false	//false     Show/blank odd/even fields alternately.
                                                    //to emulate short persistence of a CRT display. 
                                                    //Requires vsync and 50/100/150hz modeline and halves brightness.
	
	#define DO_COLOR_CORRECTION		true	//(true) 	RGBb gamma correction
	#define GAMMA					1.2		//1.5		Gamma correction, the higher, the darker.
	#define cc vec3(0.46 ,0.45 , 0.44)		//(0.46,0.45,0.44) r,g,b, gamma correction.	
	#define saturation				1.0		//1.0    Saturation modifier, 1.0 is neutral saturation.

/*****************************************************************************/	
	#define eps 1e-8
	uniform int rubyFrameCount ;
	uniform sampler2D rubyTexture;
	uniform vec2 rubyTextureSize;
	uniform vec2 rubyOutputSize ;
	uniform vec2 rubyOrigInputSize;

	vec3 int_pow3(vec3 v, float fpow){
		if ( fpow == 1.0 ) { return v; };
		if ( fpow == 2.0 ) { return v*v; }; 
		if ( fpow == 3.0 ) { return v*v*v; }; 
		if ( fpow == 4.0 ) { return v*v*v*v; }; 
		if ( fpow == 5.0 ) { return v*v*v*v*v; }; 
		if ( fpow == 6.0 ) { return v*v*v*v*v*v; }; 
		if ( fpow == 7.0 ) { return v*v*v*v*v*v*v; }; 
		if ( fpow == 8.0 ) { return v*v*v*v*v*v*v*v; }; 
		if ( fpow == 9.0 ) { return v*v*v*v*v*v*v*v*v; }; 
	}

	float int_pow(float v, float fpow){
		if ( fpow == 1.0 ) { return v; };
		if ( fpow == 2.0 ) { return v*v; }; 
		if ( fpow == 3.0 ) { return v*v*v; }; 
		if ( fpow == 4.0 ) { return v*v*v*v; }; 
		if ( fpow == 5.0 ) { return v*v*v*v*v; }; 
		if ( fpow == 6.0 ) { return v*v*v*v*v*v; }; 
		if ( fpow == 7.0 ) { return v*v*v*v*v*v*v; }; 
		if ( fpow == 8.0 ) { return v*v*v*v*v*v*v*v; }; 
		if ( fpow == 9.0 ) { return v*v*v*v*v*v*v*v*v; }; 
	}
	
	vec3 pixel_glow(float my_glowpix, float my_glowpixy, float my_glow, float glow_gamma) {
		// Calculating texel coordinates
			vec2 size     = rubyTextureSize;
			vec2 inv_size = 1.0/rubyTextureSize;
			vec2 OGL2Pos = gl_TexCoord[0].xy * size  - vec2(0.5,0.5);
			vec2 fp = fract(OGL2Pos);
			vec2 dx = vec2(inv_size.x,0.0);
			vec2 dy = vec2(0.0, inv_size.y);
			vec2 pC4 = floor(OGL2Pos) * inv_size + 0.5*inv_size;    

			vec2 x2 = 2.0*dx; vec2 x3 = 3.0*dx;
			vec2 y2 = 2.0*dy;

			float wl3 = 2.0 + fp.x; wl3*=wl3; wl3 = exp2(-my_glowpix*wl3);
			float wl2 = 1.0 + fp.x; wl2*=wl2; wl2 = exp2(-my_glowpix*wl2);
			float wl1 =       fp.x; wl1*=wl1; wl1 = exp2(-my_glowpix*wl1);
			float wr1 = 1.0 - fp.x; wr1*=wr1; wr1 = exp2(-my_glowpix*wr1);
			float wr2 = 2.0 - fp.x; wr2*=wr2; wr2 = exp2(-my_glowpix*wr2);
			float wr3 = 3.0 - fp.x; wr3*=wr3; wr3 = exp2(-my_glowpix*wr3);    
			
			float wt = 1.0/(wl3+wl2+wl1+wr1+wr2+wr3);

			vec3 l3 = texture2D(rubyTexture, pC4 -x2 ).xyz;
			vec3 l2 = texture2D(rubyTexture, pC4 -dx ).xyz;
			vec3 l1 = texture2D(rubyTexture, pC4     ).xyz;
			vec3 r1 = texture2D(rubyTexture, pC4 +dx ).xyz;
			vec3 r2 = texture2D(rubyTexture, pC4 +x2 ).xyz;
			vec3 r3 = texture2D(rubyTexture, pC4 +x3 ).xyz;
			l3=int_pow3(l3,glow_gamma); l2=int_pow3(l2,glow_gamma); l1=int_pow3(l1,glow_gamma); 
			r1=int_pow3(r1,glow_gamma); r2=int_pow3(r2,glow_gamma); r3=int_pow3(r3,glow_gamma); 

			vec3 t1 = (l3*wl3 + l2*wl2 + l1*wl1 + r1*wr1 + r2*wr2 + r3*wr3)*wt;

			l3 = texture2D(rubyTexture, pC4 -x2 -dy).xyz;
			l2 = texture2D(rubyTexture, pC4 -dx -dy).xyz;
			l1 = texture2D(rubyTexture, pC4     -dy).xyz;
			r1 = texture2D(rubyTexture, pC4 +dx -dy).xyz;
			r2 = texture2D(rubyTexture, pC4 +x2 -dy).xyz;
			r3 = texture2D(rubyTexture, pC4 +x3 -dy).xyz;
			l3=int_pow3(l3,glow_gamma); l2=int_pow3(l2,glow_gamma); l1=int_pow3(l1,glow_gamma); 
			r1=int_pow3(r1,glow_gamma); r2=int_pow3(r2,glow_gamma); r3=int_pow3(r3,glow_gamma); 

			vec3 t2 = (l3*wl3 + l2*wl2 + l1*wl1 + r1*wr1 + r2*wr2 + r3*wr3)*wt;    

			l3 = texture2D(rubyTexture, pC4 -x2 +dy).xyz;
			l2 = texture2D(rubyTexture, pC4 -dx +dy).xyz;
			l1 = texture2D(rubyTexture, pC4     +dy).xyz;
			r1 = texture2D(rubyTexture, pC4 +dx +dy).xyz;
			r2 = texture2D(rubyTexture, pC4 +x2 +dy).xyz;
			r3 = texture2D(rubyTexture, pC4 +x3 +dy).xyz;
			l3=int_pow3(l3,glow_gamma); l2=int_pow3(l2,glow_gamma); l1=int_pow3(l1,glow_gamma); 
			r1=int_pow3(r1,glow_gamma); r2=int_pow3(r2,glow_gamma); r3=int_pow3(r3,glow_gamma); 

			vec3 b1 = (l3*wl3 + l2*wl2 + l1*wl1 + r1*wr1 + r2*wr2 + r3*wr3)*wt;

			l3 = texture2D(rubyTexture, pC4 -x2 +y2).xyz;
			l2 = texture2D(rubyTexture, pC4 -dx +y2).xyz;
			l1 = texture2D(rubyTexture, pC4     +y2).xyz;
			r1 = texture2D(rubyTexture, pC4 +dx +y2).xyz;
			r2 = texture2D(rubyTexture, pC4 +x2 +y2).xyz;
			r3 = texture2D(rubyTexture, pC4 +x3 +y2).xyz;
			l3=int_pow3(l3,glow_gamma); l2=int_pow3(l2,glow_gamma); l1=int_pow3(l1,glow_gamma); 
			r1=int_pow3(r1,glow_gamma); r2=int_pow3(r2,glow_gamma); r3=int_pow3(r3,glow_gamma); 

			vec3 b2 = (l3*wl3 + l2*wl2 + l1*wl1 + r1*wr1 + r2*wr2 + r3*wr3)*wt;    

			wl2 = 1.0 + fp.y; wl2*=wl2; wl2 = exp2(-my_glowpixy*wl2);
			wl1 =       fp.y; wl1*=wl1; wl1 = exp2(-my_glowpixy*wl1);
			wr1 = 1.0 - fp.y; wr1*=wr1; wr1 = exp2(-my_glowpixy*wr1);
			wr2 = 2.0 - fp.y; wr2*=wr2; wr2 = exp2(-my_glowpixy*wr2);

			wt = 1.0/(wl2+wl1+wr1+wr2);    

			vec3 Bloom = (t2*wl2 + t1*wl1 + b1*wr1 + b2*wr2)*wt;
			return Bloom*my_glow;
	}
	vec3 pixel_vmask(vec3 source,vec3 lm1,vec3 lm2,vec3 lm3, vec3 white_reference,float over_white) {
		float col = float(int(gl_FragCoord.x));
		vec3 pixel_out;
		vec3 vmasked;
		
		if (int(mod(col, 3.0)) < 1) {
			vmasked = lm1*source;
		}
		else if (int(mod(col, 3.0)) < 2) {
			vmasked = lm2*source;
		}
		else {
			vmasked = lm3*source;
		}
		if (over_white == 1.0) {
			return vmasked;
		} else {
			float whiteness=(white_reference.r+white_reference.g+white_reference.b)/3.0;
			whiteness-=over_white;
			whiteness=min(whiteness,1.0);
			whiteness=max(whiteness,0.0);
			return mix(vmasked,source,whiteness);
		}
	}

vec3 blur(float Directions, float Quality, float Size) {
	vec2 iResolution = rubyTextureSize;
	float Pi = 6.28318530718; // Pi*2
	vec2 Radius = Size/iResolution.xy;
	//vec2 uv = vec2(gl_FragCoord.xy / iResolution);
	vec2 uv = gl_TexCoord[0].xy;
		
	vec3 color = texture2D(rubyTexture, uv).rgb;
	float steps=0.0;
	for( float d=0.0; d<Pi; d+=Pi/Directions) {
		for(float i=1.0/Quality; i<=1.0; i+=1.0/Quality) {
			color += texture2D( rubyTexture, uv+vec2(cos(d),sin(d))*Radius*i).rgb;		
			steps+=1.0;
        }
    }	
	color /= steps; //(Quality * Directions - 15.0);


	return color;
}
	
	vec3 bloom(float Directions, float Quality, float Size,float fbloom_gamma,bool over_scanline) {
		float Pi = 6.28318530718; // Pi*2
		vec2 Radius = Size/rubyTextureSize.xy;
		vec2 uv = gl_TexCoord[0].xy;
		float steps=0.0;
		vec4 lookup=vec4(0.0,0.0,0.0,0.0);
		vec3 color=vec3(0.0,0.0,0.0);
		for( float d=0.0; d<Pi; d+=Pi/Directions) {
			for(float i=1.0/Quality; i<=1.0; i+=1.0/Quality) {
				//lookup texel around
				lookup = texture2D( rubyTexture, uv+vec2(cos(d),sin(d))*Radius*i);
				if (over_scanline) {
					color +=int_pow3(lookup.rgb,fbloom_gamma) / (int_pow(lookup.a,fbloom_gamma)+0.00001);
				} else {
					color +=int_pow3(lookup.rgb,fbloom_gamma);
				}
				steps+=1.0;
			}
		}	
		color = color/steps; //(Quality * Directions - 15.0);

		return color;
	}

	vec3 pixel_darklines(vec3 source,float darkline_every, float darkline_trans, bool do_offset, vec3 white_reference,float over_white) {
		vec3 pixel_out=source;
		float col_2 =  gl_FragCoord.x;
		float line_2 = gl_FragCoord.y;

		float fDarkline_part_w=3.0 ;             //Triads width, float type
		float fDarkline_part_w_x2 = 6.0 ;        //Triads width, float type, *2
		int iDarkline_part_w = 3 ;               //Triads width, integer type (3 pixels unless changing m1,m2,m3 datatype
		
		if (over_white != 1.0) {
			//less effect on bright colors.
			float whiteness=(white_reference.r+white_reference.g+white_reference.b)/3.0;
			darkline_trans+=(whiteness-over_white);
			darkline_trans=max(darkline_trans,0.0);
			darkline_trans=min(darkline_trans,1.0);
		}
		
		if (do_offset) { 
			int hmask_shape_offset = int (darkline_every/2.0) + 1 ;
			if  (int(mod(line_2, darkline_every)) == 1) {
				if (int(mod(col_2, fDarkline_part_w_x2)) < iDarkline_part_w) {
					pixel_out =  pixel_out * darkline_trans;
				}
			} else if  (int(mod(line_2, darkline_every)) == hmask_shape_offset ) {
				// DRAW WITH OFFSET:
				col_2+=fDarkline_part_w;
				if ((int(mod(col_2, fDarkline_part_w_x2))) < iDarkline_part_w) {
					pixel_out =  pixel_out * darkline_trans;
				}
			}
		} else {
			if  (int(mod(line_2, darkline_every)) == 1) {
				pixel_out =  pixel_out * darkline_trans;
			}
				
		}
		
		return pixel_out;
	}

	
vec3 blur5(vec2 uv, vec2 resolution, vec2 direction) {
  vec3 color = vec3(0.0);
  vec2 off1 = vec2(1.3333333333333333) * direction;
  color += texture2D(rubyTexture, uv).rgb * 0.29411764705882354;
  color += texture2D(rubyTexture, uv + (off1 / resolution)).rgb * 0.35294117647058826;
  color += texture2D(rubyTexture, uv - (off1 / resolution)).rgb * 0.35294117647058826;
  return color; 
}


vec3 fix_scanlines(float radius) {
	vec2 uv = gl_TexCoord[0].xy;
	vec2 direction=vec2(0.0,1.0);
	vec3 color=vec3(0.0);
	direction*=radius;
	color=blur5(uv,rubyTextureSize.xy,direction);
	return color;
}
	
	
vec3 pixel_alternate(vec3 source) {
	float line = gl_FragCoord.y;
	vec3 pixel_out = source;
	if  (int(mod(float(rubyFrameCount),2.0  )) == 1) {
		if  (int(mod(line,2.0  )) == 1) {
			pixel_out=vec3(0.0,0.0,0.0) ; 
		}
	} else {
		if  (int(mod(line,2.0  )) == 0) {
			pixel_out=vec3(0.0,0.0,0.0) ; 
		}
	}
	return pixel_out;
}
	

    void main(void) {
		vec3 pixel_in = texture2D(rubyTexture, gl_TexCoord[0].xy).rgb; 
		vec3 pixel_out = pixel_in;
		vec3 haloed = pixel_in;
		vec3 glowed = pixel_in;
		vec3 bloomed = pixel_in;

		if (DO_IN_GLOW) { 
			/* Input signal is blurred and glows.
			glow power versus blur power is defined by IN_GLOW_ADD.
			this allows the rgb vmask to light up on the black scanline.
			*/
			glowed = pixel_glow(in_glow_w,in_glow_h,in_glow_power,in_glow_gamma);
			if (IN_GLOW_ADD>0.0) {
				pixel_out =mix(glowed,glowed+pixel_out,IN_GLOW_ADD);
			} else {
				pixel_out =glowed;
			}
		} else if (FIX_SCANLINES) { 
			pixel_out=fix_scanlines(0.2); 	//try from 0.1 to 0.3
		} 

		
		if (DO_RGB_MASK) { 
			pixel_out = pixel_vmask(pixel_out,m1,m2,m3,pixel_in,VMASK_OVERWHITE);
		}

		if (DO_DARKLINES && DO_HALO && FIX_FOR_INTEL) {
			haloed = pixel_glow(halo_w,halo_h,halo_power,halo_gamma);
			pixel_out+=haloed; //yes i know, 
			pixel_out-=haloed; //but still...
		}
		
		
		if (DO_DARKLINES) {
			pixel_out = pixel_darklines(pixel_out,DARKLINES_PERIOD,DARKLINES_TRANSPARENCY,DO_DARKLINES_VOFFSET,pixel_in,DRKLN_OVERWHITE);
		}

		if (DO_HALO) { 
			haloed = pixel_glow(halo_w,halo_h,halo_power,halo_gamma);
			pixel_out +=haloed;
		}

		if (DO_BLOOM) {
			bloomed = bloom(bloom_directions,bloom_quality,bloom_size,bloom_gamma,bloom_over_scanline);
			pixel_out = (pixel_out * (1.0-bloom_mix) ) + ( bloomed*bloom_mix);
		}

		if (DO_COLOR_CORRECTION) {
			pixel_out = pow(pixel_out,cc*GAMMA);
		}

		if (DO_ALT_BLANK) {
			pixel_out = pixel_alternate(pixel_out);
		}
		
		if (!(saturation == 1.0)) {
			float l = length(pixel_out);
			pixel_out = normalize(pow(pixel_out + vec3(eps,eps,eps), vec3(saturation,saturation,saturation)))*l;
		}

		gl_FragColor = vec4(pixel_out,1.0);
    }
]]></fragment>
    

    


</shader>
