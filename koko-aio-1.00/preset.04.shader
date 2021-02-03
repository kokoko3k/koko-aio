<?xml version="1.0" encoding="UTF-8"?>


<shader language="GLSL">

/* 
    CRT-AIO shader

    Copyright (C) kokoko3k@gmail.com
    
    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
    --
    
    All in one fragment shader for FS-UAE, supports:
    * non linear scanlines on original coordinates
    * non linear screenlines on screen coordinates
    * custom rgb masks with offset
    * glowing
    * gamma correction
    * saturation
    * alternate blanking
    
    It is important to know that it is designed to work in FS-UAE with 
    * line doubling enabled:   line_doubling = 1
    * low resolution disabled: low_resolution = 0
    
    Designed also to work well with FS-UAE's autoscale function.

    Glow code from 2019 guest(r) - guest.r@gmail.com and his Trinitron shader.
    https://github.com/guestrr/FS-UAE-Shaders/blob/master/crt-trinitron.shader
    
    Note:
    Tecnically, scanlines/"screenlines" are the visible part of the screen,
    but in the code i'll use them to refer to the black lines.
	
	
Preset: Sharper, rigid, best ok 4K with more backlight.
	DO_SCANLINES				0
	DO_VMASK					1    
	DO_SCREENLINES				1 
	DO_SCREENLINES_VOFFSET		1 
	DO_BLOOM					1 
	DO_ALT_BLANK				0 
	VMASK_HEIGHT				4
	VMASK_OVER_WHITE			1.0
	SCRNLN_OVER_WHITE			0.0
	SCREENLINE_HEIGHT			2
	SCREENLINES_TRANS			0.0
	bloompix					1.5
	bloompixy					1.5
	glow						1.2
	GAMMA_COR					0.5
	saturation					1.0
	m1 vec3 ( 1.0 , 0.0 , 0.0 )
	m2 vec3 ( 0.0 , 1.0 , 0.0 )
	m3 vec3 ( 0.0 , 0.0 , 1.0 ) 
	
Preset: Smoother, brighter
	DO_SCANLINES				0
	DO_VMASK					1   
	DO_SCREENLINES				1 
	DO_SCREENLINES_VOFFSET		1 
	DO_BLOOM					1 
	DO_ALT_BLANK				0 
	VMASK_HEIGHT				4
	VMASK_OVER_WHITE			0.5
	SCRNLN_OVER_WHITE			0.2
	SCREENLINE_HEIGHT			2
	SCREENLINES_TRANS			0.5
	bloompix					1.2
	bloompixy					1.2
	glow						1.2
	GAMMA_COR					0.5
	saturation					1.0
	m1 vec3 ( 1.0 , 0.0 , 0.0 )
	m2 vec3 ( 0.0 , 1.0 , 0.0 )
	m3 vec3 ( 0.0 , 0.0 , 1.0 )  
	
Preset: Use CMY vmask
	DO_SCANLINES				0
	DO_VMASK					1     
	DO_SCREENLINES				1 
	DO_SCREENLINES_VOFFSET		1 
	DO_BLOOM					1 
	DO_ALT_BLANK				0 
	VMASK_HEIGHT				4
	VMASK_OVER_WHITE			0.5
	SCRNLN_OVER_WHITE			0.2
	SCREENLINE_HEIGHT			2
	SCREENLINES_TRANS			0.0
	bloompix					1.5
	bloompixy					1.5
	glow						1.2
	GAMMA_COR					0.55
	saturation					1.0
	m1 vec3 ( 1.0 , 0.0 , 0.5 )
	m2 vec3 ( 0.5 , 1.0 , 0.0 )
	m3 vec3 ( 0.0 , 0.5 , 1.0 )
	
Preset non-linear scanlines
	DO_SCANLINES				1
	SCAN_OVER_WHITE				0.8
	s1							1.0
	s2							0.5
	DO_VMASK					0
	DO_SCREENLINES				0 
	DO_BLOOM					1 
	DO_ALT_BLANK				0
	bloompix					2.0
	bloompixy					5.0
	glow						1.2
	GAMMA_COR					0.5
	saturation					1.0
	
Preset: Low Persistence
	DO_SCANLINES				0
	DO_VMASK					0
	DO_SCREENLINES				0 
	DO_BLOOM					1 
	DO_ALT_BLANK				1
	bloompix					1.2
	bloompixy					1.2
	glow						1.2
	GAMMA_COR					0.4
	saturation					1.0
*/
    

<fragment scale="1.0" filter="nearest"><![CDATA[

    /* check the next shader for more configuration options */
    
    #define DO_SCANLINES            1        //1    1 to enable scanlines
    #define SCAN_OVER_WHITE         0.8      //0.2  How much scanlines affect bright colors. Range [0.0 -> 1.0] 
                                                    //Used to simulate the effect of the blooming
                                                    //on the 'unpainted' parts of the CRT monitor.

    /* Even/odd scanline alpha: */
    #define s1  1.0    
    #define s2  0.5

    uniform sampler2D rubyTexture;
    
    vec3 mymix(vec3 source, float scanline) {
        vec3 white_over_scanline = source -   ( (source -(source * scanline)) * (1.0 -source) ) ;
        vec3 scanline_over_white = source * scanline;

		scanline_over_white *= SCAN_OVER_WHITE ;
        white_over_scanline *= 1.0-SCAN_OVER_WHITE;
        return scanline_over_white + white_over_scanline;
    }
    
    void main(void) {
        vec3 pixel = texture2D(rubyTexture, gl_TexCoord[0].xy).rgb; 
        if ( DO_SCANLINES == 1) {
            float line = float(int(gl_FragCoord.y));
            if (int(mod(line, 2.0)) < 1) {
                    pixel = mymix(pixel,s1); 
            } else {
                    pixel = mymix(pixel,s2) ;
            }
        }
        gl_FragColor = vec4(pixel,1.0);
    }

]]></fragment>






    
<fragment filter="linear"><![CDATA[

/* Toggles */
#define DO_VMASK                  0       //1      1 Enable horizontal RGB vmask
#define DO_SCREENLINES            0       //1      1 Enable screenlines
#define DO_SCREENLINES_VOFFSET    0       //1      1 Vertically offset even triads, only makes sense with DO_VMASK=1
#define DO_BLOOM                  1       //1      1 Enable blooming *and* blurring
#define DO_ALT_BLANK              0       //0      1 to show/blank odd/even fields alternately.
                                                   //Tries to emulate short persistence of a CRT display. 
                                                   //Requires vsync and 50/100/150hz... modeline and halves brightness.


/* RGB mask and frame */
#define VMASK_HEIGHT              4       //4      When DO_SCREENLINES_VOFFSET=1, draw one screenline (the frame) every # rows. Use even numbers.
#define VMASK_OVER_WHITE          0.5    //0.5   How much rgb vmask affects bright colors. Range [0.0 -> 1.0] 
#define SCRNLN_OVER_WHITE         0.2    //0.05   How much screenlines or vmask frame affect bright colors. Range [0.0 -> 1.0] 
                                                   //Lower levels simulates the glow of the image over the screenline
                                                

/* Screenlines and RGB mask black frame */
#define SCREENLINE_HEIGHT         2       //2      When DO_SCREENLINES_VOFFSET=0, draw one straight screenline every # rows. Use even numbers.
#define SCREENLINES_TRANS         0.0     //0.0    Screenlines or vmask frame alpha. Range [0.0 -> 1.0], ** 0.0 is the darker **



/* Bloom, glow, blur */
#define bloompix     2.0            //1.2    Blurriness and glow width , the less the blurrier
#define bloompixy    5.0           //1.2    Blurriness and glow height, the less the blurrier
#define glow         1.2            //1.2    Glow Strength, sane values from 1.0 to 1.3


/* Post effects: */
#define GAMMA_COR    0.5           //0.5    Gamma correction, the higher, the darker.
#define saturation   1.0            //1.0    Saturation modifier, 1.0 is neutral saturation.




/* Vertical Masks: */

// SIMPLE (strict, for hires displays, or in conjuntion with low SCRNLN_OVER_WHITE): 
//                     R      G      B
//    #define m1 vec3 ( 1.0 , 0.0 , 0.0 )    //col 1
//    #define m2 vec3 ( 0.0 , 1.0 , 0.0 )    //col 2
//   #define m3 vec3 ( 0.0 , 0.0 , 1.0  )    //col 3

//SIMPLE, brighter, good for 1080p, best with GAMMA_COR >= 0.55
//                      R      G      B
//    #define m1 vec3 ( 1.0 , 0.5 , 0.5 )    //col 1
//    #define m2 vec3 ( 0.5 , 1.0 , 0.5 )    //col 2
//    #define m3 vec3 ( 0.5 , 0.5 ,  1.0 )    //col 3

//RGB->CMY (good compromise, good on 1080p), best with GAMMA_COR >= 0.55
//                      R      G      B
    #define m1 vec3 ( 1.0 , 0.0 , 0.5 )    //col 1
    #define m2 vec3 ( 0.5 , 1.0 , 0.0 )    //col 2
    #define m3 vec3 ( 0.0 , 0.5 ,  1.0 )    //col 3

//RGB->CMY, brighter, best with GAMMA_COR >= 0.55
//                      R      G      B
//    #define m1 vec3 ( 1.0  , 0.25 , 0.5 )    //col 1
//    #define m2 vec3 ( 0.5  , 1.0  , 0.25 )    //col 2
//    #define m3 vec3 ( 0.25 , 0.5  , 1.0 )    //col 3
	
//...Grayscale (Vertical screenline, if you like it):
//                      R      G      B
//    #define m1 vec3 ( 1.0 , 1.0 , 1.0 )    //col 1
//    #define m2 vec3 ( 1.0 , 1.0 , 1.0 )    //col 2
//    #define m3 vec3 ( 0.1 , 0.1 , 0.1 )    //col 3

/*  config ends here  */


uniform int rubyFrameCount ;
uniform sampler2D rubyTexture;
uniform vec2 rubyTextureSize;
uniform vec2 rubyOutputSize ;
uniform vec2 rubyOrigInputSize;


#define eps 1e-8

vec3 pixel_scanline(vec3 source) {
	//OGL2Pos give us texture (not screen) coordinates.
	//1080p seems not enough.
	vec2 texcoord = gl_TexCoord[0].xy; 
	vec2 OGL2Pos = texcoord * rubyTextureSize;
	vec3 pixel_out;
	float line = OGL2Pos.y;
	pixel_out=source;
	
	if ( int(mod(line, 2.0))  ==  1    ) {
			pixel_out = source* 0.0;
			} else {
			pixel_out = source* 1.0;
	}

	return pixel_out;
}

vec3 mymix(vec3 source, float scanline, float over_white, vec3 reference) {
    /* Non linear multiplication between "source" and "scanline"
       the more: over_white=1.0, the less the multiplication
       will be effective on bright colors. */

    vec3 white_over_scanline = source -   ( (source -(source * scanline)) * (1.0 -reference) ) ;
    vec3 scanline_over_white = source * scanline;

    scanline_over_white *= over_white ;
    white_over_scanline *= 1.0-over_white;

    return scanline_over_white + white_over_scanline;
}

    
vec3 mymixvec(vec3 source, vec3 mask, float over_white, vec3 reference) {
    /* Non linear multiplication between "source" and "mask"
       the more: over_white=1.0, the less the multiplication
       will be effective on bright colors. */

    vec3 white_over_scanline = source -   ( (source -(source * mask)) * (1.0 - reference) ) ;
    vec3 scanline_over_white = source * mask;
    scanline_over_white *= over_white ;
    white_over_scanline *= 1.0-over_white;
    return scanline_over_white + white_over_scanline;

}

vec3 pixel_bloom(vec3 source) {
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

        float wl3 = 2.0 + fp.x; wl3*=wl3; wl3 = exp2(-bloompix*wl3);
        float wl2 = 1.0 + fp.x; wl2*=wl2; wl2 = exp2(-bloompix*wl2);
        float wl1 =       fp.x; wl1*=wl1; wl1 = exp2(-bloompix*wl1);
        float wr1 = 1.0 - fp.x; wr1*=wr1; wr1 = exp2(-bloompix*wr1);
        float wr2 = 2.0 - fp.x; wr2*=wr2; wr2 = exp2(-bloompix*wr2);
        float wr3 = 3.0 - fp.x; wr3*=wr3; wr3 = exp2(-bloompix*wr3);    
        
        float wt = 1.0/(wl3+wl2+wl1+wr1+wr2+wr3);
        
        vec3 l3 = texture2D(rubyTexture, pC4 -x2 ).xyz; l3*=l3;
        vec3 l2 = texture2D(rubyTexture, pC4 -dx ).xyz; l2*=l2;
        vec3 l1 = texture2D(rubyTexture, pC4     ).xyz; l1*=l1;
        vec3 r1 = texture2D(rubyTexture, pC4 +dx ).xyz; r1*=r1;
        vec3 r2 = texture2D(rubyTexture, pC4 +x2 ).xyz; r2*=r2;
        vec3 r3 = texture2D(rubyTexture, pC4 +x3 ).xyz; r3*=r3;

        vec3 t1 = (l3*wl3 + l2*wl2 + l1*wl1 + r1*wr1 + r2*wr2 + r3*wr3)*wt;
        
        l3 = texture2D(rubyTexture, pC4 -x2 -dy).xyz; l3*=l3;
        l2 = texture2D(rubyTexture, pC4 -dx -dy).xyz; l2*=l2;
        l1 = texture2D(rubyTexture, pC4     -dy).xyz; l1*=l1;
        r1 = texture2D(rubyTexture, pC4 +dx -dy).xyz; r1*=r1;
        r2 = texture2D(rubyTexture, pC4 +x2 -dy).xyz; r2*=r2;
        r3 = texture2D(rubyTexture, pC4 +x3 -dy).xyz; r3*=r3;
        
        vec3 t2 = (l3*wl3 + l2*wl2 + l1*wl1 + r1*wr1 + r2*wr2 + r3*wr3)*wt;    
        
        l3 = texture2D(rubyTexture, pC4 -x2 +dy).xyz; l3*=l3;
        l2 = texture2D(rubyTexture, pC4 -dx +dy).xyz; l2*=l2;
        l1 = texture2D(rubyTexture, pC4     +dy).xyz; l1*=l1;
        r1 = texture2D(rubyTexture, pC4 +dx +dy).xyz; r1*=r1;
        r2 = texture2D(rubyTexture, pC4 +x2 +dy).xyz; r2*=r2;
        r3 = texture2D(rubyTexture, pC4 +x3 +dy).xyz; r3*=r3;

        vec3 b1 = (l3*wl3 + l2*wl2 + l1*wl1 + r1*wr1 + r2*wr2 + r3*wr3)*wt;

        l3 = texture2D(rubyTexture, pC4 -x2 +y2).xyz; l3*=l3;
        l2 = texture2D(rubyTexture, pC4 -dx +y2).xyz; l2*=l2;
        l1 = texture2D(rubyTexture, pC4     +y2).xyz; l1*=l1;
        r1 = texture2D(rubyTexture, pC4 +dx +y2).xyz; r1*=r1;
        r2 = texture2D(rubyTexture, pC4 +x2 +y2).xyz; r2*=r2;
        r3 = texture2D(rubyTexture, pC4 +x3 +y2).xyz; r3*=r3;
        
        vec3 b2 = (l3*wl3 + l2*wl2 + l1*wl1 + r1*wr1 + r2*wr2 + r3*wr3)*wt;    
        
        wl2 = 1.0 + fp.y; wl2*=wl2; wl2 = exp2(-bloompixy*wl2);
        wl1 =       fp.y; wl1*=wl1; wl1 = exp2(-bloompixy*wl1);
        wr1 = 1.0 - fp.y; wr1*=wr1; wr1 = exp2(-bloompixy*wr1);
        wr2 = 2.0 - fp.y; wr2*=wr2; wr2 = exp2(-bloompixy*wr2);
        
        wt = 1.0/(wl2+wl1+wr1+wr2);    
        
        vec3 Bloom = (t2*wl2 + t1*wl1 + b1*wr1 + b2*wr2)*wt;
		return Bloom*glow;

}


vec3 pixel_vmask(vec3 source) {
	float col = float(int(gl_FragCoord.x));
	vec3 pixel_out;
	if (int(mod(col, 3.0)) < 1) {
		//color_masked_scanlined = pixel_processed * m1;
		pixel_out = mymixvec(source, m1, VMASK_OVER_WHITE, source);
	}
	else if (int(mod(col, 3.0)) < 2) {
		//color_masked_scanlined = pixel_processed * m2;
		pixel_out = mymixvec(source, m2, VMASK_OVER_WHITE, source);
	}
	else {
		//color_masked_scanlined = pixel_processed * m3;
		pixel_out = mymixvec(source, m3, VMASK_OVER_WHITE, source);
	}
	return pixel_out;
}


vec3 pixel_screenlines_offset(vec3 source) {
	vec3 pixel_out=source;
	float screenline_every;
	float col_2 =  gl_FragCoord.x;
	float line_2 = gl_FragCoord.y;
	
	float fScreenline_part_w=3.0 ;             //Triads width, float type
	float fScreenline_part_w_x2 = 6.0 ;        //Triads width, float type, *2
	int iScreenline_part_w = 3 ;               //Triads width, integer type (3 pixels unless changing m1,m2,m3 datatype

	vec3 source_clamped = min(source,1.0) ;
	screenline_every = float(VMASK_HEIGHT);     
	int hmask_shape_offset = int (screenline_every/2.0) + 1 ;
	if  (int(mod(line_2, screenline_every)) == 1) {
		if (int(mod(col_2, fScreenline_part_w_x2)) < iScreenline_part_w) {
			pixel_out =  mymix (source_clamped, SCREENLINES_TRANS, SCRNLN_OVER_WHITE,source);
		}
	} else if  (int(mod(line_2, screenline_every)) == hmask_shape_offset ) {
		// DRAW WITH OFFSET:
		col_2+=fScreenline_part_w;
		if ((int(mod(col_2, fScreenline_part_w_x2))) < iScreenline_part_w) {
			pixel_out = mymix (source_clamped, SCREENLINES_TRANS, SCRNLN_OVER_WHITE,source);
		}
	}
	return pixel_out;
}

vec3 pixel_screenlines_straight(vec3 source) {
	float screenline_every = float(SCREENLINE_HEIGHT);       
	float line_2 = gl_FragCoord.y;
	vec3 pixel_out=source;
	vec3 source_clamped = min(source,1.0) ;
	if  (int(mod(line_2, screenline_every)) == 1) {
		pixel_out =  mymix (source_clamped, SCREENLINES_TRANS, SCRNLN_OVER_WHITE,source);
	}
	return pixel_out;
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


void main()
{
	vec3 pixel_source = texture2D(rubyTexture, gl_TexCoord[0].xy).xyz; 
	vec3 pixel_processed = pixel_source;

	pixel_processed = pixel_scanline(pixel_processed);
	
	/* BLOOM */
    if ( DO_BLOOM == 1) { 
        pixel_processed=pixel_bloom(pixel_source);
    } 


	/* VMASK */
	if ( DO_VMASK == 1) {
	    pixel_processed=pixel_vmask(pixel_processed);
	}
	
	/* SCREENLINES */
    if ( DO_SCREENLINES == 1 ) {
		if ( DO_SCREENLINES_VOFFSET == 1 ) {
			pixel_processed = pixel_screenlines_offset(pixel_processed);
		} else {
			pixel_processed = pixel_screenlines_straight(pixel_processed);
        }
    }

	/* GAMMA */
	pixel_processed = pow(pixel_processed, vec3(GAMMA_COR, GAMMA_COR, GAMMA_COR));

    /* SATURATION */
    float l = length(pixel_processed);
    pixel_processed = normalize(pow(pixel_processed + vec3(eps,eps,eps), vec3(saturation,saturation,saturation)))*l;

	/* ALTERNATE FIELDS */
    if ( DO_ALT_BLANK == 1 ) {
		pixel_processed=pixel_alternate(pixel_processed);
    }


    //output
    gl_FragColor = vec4(pixel_processed,1.0);
}
    
]]></fragment>
    


</shader>
