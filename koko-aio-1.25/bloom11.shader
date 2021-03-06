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
    * non linear darklines on screen coordinates
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
    Tecnically, scanlines/"darklines" are the visible part of the screen,
    but in the code i'll use them to refer to the black lines.
*/	
	
//Sfoco il segnale in ingresso:


//Scanline reali

<fragment scale="1.0" filter="nearest"><![CDATA[

    /* check the next shader for more configuration options */
    
    #define DO_SCANLINES           1        //1    1 to enable scanlines
    #define SCAN_OVER_WHITE         0.0      //0.2  How much scanlines affect bright colors. Range [0.0 -> 1.0] 
                                                    //Used to simulate the effect of the blooming
                                                    //on the 'unpainted' parts of the CRT monitor.

    /* Even/odd scanline alpha: */
    #define s1  1.0    
    #define s2  0.01

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

//riscalo a 1X per non appesantire i calcoli successivi
	
]]></fragment>



    
<fragment filter="linear"><![CDATA[

/* Toggles */
#define DO_VMASK                  1       //1      1 Enable horizontal RGB vmask
#define DO_DARKLINES            1       //1      1 Enable darklines
#define DO_DARKLINES_VOFFSET    1       //1      1 Vertically offset even triads, only makes sense with DO_VMASK=1
#define DO_GLOW                  1       //1      1 Enable glowing *and* blurring
#define DO_GLOW_OVER_VMASK       0       //0      1 draw glow 'over' VMASK pattern (need higher GAMMA_COR)  
#define DO_GLOW_OVER_SCRNL       0       //0      1 draw glow 'over' darklines
#define DO_BLOOM				 1		 //		  1 do fullscreen bloom
#define DO_ALT_BLANK              0       //0      1 to show/blank odd/even fields alternately.
                                                   //Tries to emulate short persistence of a CRT display. 
                                                   //Requires vsync and 50/100/150hz... modeline and halves brightness.

/* RGB mask and frame */
#define VMASK_HEIGHT              3      //4      When DO_DARKLINES_VOFFSET=1, draw one darkline (the frame) every # rows. Use even numbers.
#define VMASK_OVER_WHITE          0.9    //0.5   How much rgb vmask affects bright colors. Range [0.0 -> 1.0] 
#define DARKLN_OVER_WHITE         0.0   //0.05   How much darklines or vmask frame affect bright colors. Range [0.0 -> 1.0] 
                                                   //Lower levels simulates the glow of the image over the darkline
                                                

/* Darklines and RGB mask black frame */
#define DARKLINE_PERIOD         5       //2      When DO_DARKLINES_VOFFSET=0, draw one straight darkline every # rows. Use even numbers.
#define DARKLINE_HEIGHT         1       //2      straight darkline height

#define DARKLINES_TRANS         0.0     //0.0    Darklines or vmask frame alpha. Range [0.0 -> 1.0], ** 0.0 is the darker **



/* Glow, blur */
#define glowpix     10.0            //1.2  Blurriness and glow width , the less the blurrier
#define glowpixy    2.0            //1.2  Blurriness and glow height, the less the blurrier
#define glow         1.5           //1.2  Glow Strength, sane values from 1.0 to 1.3



/* Real bloom */
#define BLOOM_KERNEL_SIZE 4     //bloom steps, the more the smoother, the slower, 4 could be enough.
#define BLOOM_WIDTH       0.004    //bloom width,  0.01 is a good starting point
#define BLOOM_HEIGHT      0.004    //bloom height, 0.01 is a good starting point
#define BLOOM_MULTIPLIER  1.5    //the more, the bloomer, try in range 3.0 - 5.0
#define BLOOM_SIGMA       3.0	  //lowering this, will make the the gaussian steeper, start with 10.0
#define BLOOM_GAMMA   1.0     //higher values limit bloom to brighter colors, range 1.0 - 10.0



/* Post effects: */

#define saturation   1.3           //1.0    Saturation modifier, 1.0 is neutral saturation.
#define GAMMA_COR    0.35           //0.5   Gamma correction, the higher, the darker.
//                              R   G   B
#define color_correction vec3(1.1 , 1.0 , 0.9)      //(1.0,1.0,1.0) r,g,b, gamma correction.



/* Vertical Masks: */

// SIMPLE (strict, for hires displays, or in conjuntion with low DARKLN_OVER_WHITE): 
//                     R      G      B
    #define m1 vec3 ( 1.5 , 0.0 , 0.0 )    //col 1
    #define m2 vec3 ( 0.0 , 1.5 , 0.0 )    //col 2
    #define m3 vec3 ( 0.0 , 0.0 , 1.5  )    //col 3

//SIMPLE, brighter, good for 1080p, best with GAMMA_COR >= 0.55
//                      R      G      B
//    #define m1 vec3 ( 1.0 , 0.5 , 0.5 )    //col 1
//    #define m2 vec3 ( 0.5 , 1.0 , 0.5 )    //col 2
//    #define m3 vec3 ( 0.5 , 0.5 ,  1.0 )    //col 3

//RGB->CMY (good compromise, good on 1080p), best with GAMMA_COR >= 0.55
//                      R      G      B
//    #define m1 vec3 ( 1.0 , 0.0 , 0.5 )    //col 1
//    #define m2 vec3 ( 0.5 , 1.0 , 0.0 )    //col 2
//    #define m3 vec3 ( 0.0 , 0.5 ,  1.0 )    //col 3

//RGB->CMY, brighter, best with GAMMA_COR >= 0.55
//                      R      G      B
//    #define m1 vec3 ( 1.0  , 0.25 , 0.5 )    //col 1
//    #define m2 vec3 ( 0.5  , 1.0  , 0.25 )    //col 2
//    #define m3 vec3 ( 0.25 , 0.5  , 1.0 )    //col 3
	
//...Grayscale (Vertical darkline, if you like it):
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





vec3 clamp_01(vec3 source) {
	source = min(source,1.0) ;
	source = max(source,0.0) ;
	return source;
}


vec3 pixel_glow(float my_glowpix, float my_glowpixy, float my_glow) {
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
        
        wl2 = 1.0 + fp.y; wl2*=wl2; wl2 = exp2(-my_glowpixy*wl2);
        wl1 =       fp.y; wl1*=wl1; wl1 = exp2(-my_glowpixy*wl1);
        wr1 = 1.0 - fp.y; wr1*=wr1; wr1 = exp2(-my_glowpixy*wr1);
        wr2 = 2.0 - fp.y; wr2*=wr2; wr2 = exp2(-my_glowpixy*wr2);
        
        wt = 1.0/(wl2+wl1+wr1+wr2);    
        
        vec3 Bloom = (t2*wl2 + t1*wl1 + b1*wr1 + b2*wr2)*wt;
		return Bloom*my_glow;

}


vec3 whitemix(vec3 source, float darkline_transparency, float over_white, vec3 reference,float glowed_strength) {
    /* Non linear multiplication between "source" and "darkline_transparency"
       the more: over_white=1.0, the less the multiplication
       will be effective on bright colors.
	*/

	darkline_transparency=min(1.0,darkline_transparency);

    vec3 white_over_scanline = source -   ( (source -(source * darkline_transparency)) * (1.0 -reference) ) ;
    vec3 scanline_over_white = source * darkline_transparency;

	
    scanline_over_white *= over_white ;
    white_over_scanline *= 1.0-over_white;

	return scanline_over_white + white_over_scanline;
}

vec3 mymix(vec3 source, float darkline_transparency, float over_white, vec3 reference,float glowed_strength) {
    /* Non linear mix between black and "source"
       the more over_white=1.0, the more the darkline on bright colors.
	   the more glowed_strength=1.0, the less the darkline
	   the more "darkline_transparency"=0,0, the less the darkline
	*/
	vec3 whitemixed=whitemix(source,darkline_transparency,over_white,reference,glowed_strength);
	//do it again to amplify the effect on darker colors.
	whitemixed=whitemix(whitemixed,darkline_transparency,over_white,reference,glowed_strength);
	whitemixed=whitemix(whitemixed,darkline_transparency,over_white,reference,glowed_strength);
	
	return mix(whitemixed,source,glowed_strength);
}




vec3 pixel_darklines_offset(vec3 source, float glowed_strength, vec3 reference) {
	vec3 pixel_out=source;
	float darkline_every;
	float col_2 =  gl_FragCoord.x;
	float line_2 = gl_FragCoord.y;
	
	float fDarkline_part_w=3.0 ;             //Triads width, float type
	float fDarkline_part_w_x2 = 6.0 ;        //Triads width, float type, *2
	int iDarkline_part_w = 3 ;               //Triads width, integer type (3 pixels unless changing m1,m2,m3 datatype

	vec3 source_clamped = clamp_01(source);
	
	//zeroing glowed_strength has the effect of disabling the effwect of the glow over darklines
	if (DO_GLOW_OVER_SCRNL == 0) { glowed_strength = 0.0; }
	
	darkline_every = float(VMASK_HEIGHT);     
	int hmask_shape_offset = int (darkline_every/2.0) + 1 ;
	if  (int(mod(line_2, darkline_every)) == 1) {
		if (int(mod(col_2, fDarkline_part_w_x2)) < iDarkline_part_w) {
			pixel_out =  mymix (source_clamped, DARKLINES_TRANS, DARKLN_OVER_WHITE,reference,glowed_strength);
		}
	} else if  (int(mod(line_2, darkline_every)) == hmask_shape_offset ) {
		// DRAW WITH OFFSET:
		col_2+=fDarkline_part_w;
		if ((int(mod(col_2, fDarkline_part_w_x2))) < iDarkline_part_w) {
			pixel_out = mymix (source_clamped, DARKLINES_TRANS, DARKLN_OVER_WHITE,reference,glowed_strength);
		}
	}
	
	return pixel_out;
}



vec3 pixel_darklines_straight(vec3 source, float glowed_strength, vec3 reference) {
	float darkline_every = float(DARKLINE_PERIOD);      
	//DARKLINE_HEIGHT
	float line_2 = gl_FragCoord.y;
	vec3 pixel_out=source;
	vec3 source_clamped = clamp_01(source) ;

	//zeroing glowed_strength has the effect of disabling the effect of the glow over darklines
	if (DO_GLOW_OVER_SCRNL == 0) { glowed_strength = 0.0; }
	
	/*if  (int(mod(line_2, darkline_every)) == 1) {
		pixel_out =  mymix (source_clamped, DARKLINES_TRANS, DARKLN_OVER_WHITE,source,glowed_strength);
	}*/
	
	if  (int(mod(line_2, darkline_every)) < DARKLINE_HEIGHT ) {
		pixel_out =  mymix (source_clamped, DARKLINES_TRANS, DARKLN_OVER_WHITE,reference,glowed_strength);
	}
	
	
	return pixel_out;
}


float is_glowed(vec3 pixel_glowed,vec3 pixel_vanilla) {
	/*given a 'pixel', returns a number between 0..1
	  1 means this pixel has been completely glowed
	  0 means it is completely vanilla.*/
	float sum_glowed=(pixel_glowed.r+pixel_glowed.g+pixel_glowed.b)/3.0;
	float sum_vanilla=(pixel_vanilla.r+pixel_vanilla.g+pixel_vanilla.b)/3.0;
	// (  ( sum_glowed/sum_reference) / ( sum_glowed/sum_reference) +1.0 ) ;
	return sum_glowed / (sum_glowed+sum_vanilla) ; //the same as above, simplified.
}


vec3 mask_white_mix(vec3 source, vec3 mask, float over_white, vec3 reference) {
    /* Non linear multiplication between "source" and "mask"
       the more: over_white=1.0, the less the multiplication
       will be effective on bright colors. */

    vec3 white_over_scanline = source -   ( (source -(source * mask)) * (1.0 - reference) ) ;
    vec3 scanline_over_white = source * mask;
    scanline_over_white *= over_white ;
    white_over_scanline *= 1.0-over_white;
    return scanline_over_white + white_over_scanline;
}


vec3 mask_glow_mix(vec3 glowed, vec3 mask_component, vec3 reference, float glowed_strength, float over_white) {
	/* mixa la vmask e il glow in modo che il glow sia solo un alone
		e pertanto non "attivi" la maschera rgb.
		lo realizziamo mixando il glow alla maschera rgb
		il mix tenderà tanto più al glow quanto più il rapporto tra 
		il glow e l'immagine originaria di riferimento è alta.
		l massima differenza possibile è 1*max_glow. (dall'algoritmo di glowing)
	*/
	vec3 vmasked;
	vec3 pixel_out;
	if ( DO_GLOW_OVER_VMASK == 1 ) {
		vmasked=mask_white_mix(reference,mask_component,over_white,reference);
		pixel_out= mix(vmasked,glowed,glowed_strength);
		} else{
		vmasked=mask_white_mix(glowed,mask_component,over_white,glowed);
		pixel_out= mix(vmasked,glowed,0.0);
	}
	return pixel_out;

}

vec3 pixel_vmask(vec3 source, vec3 reference, float over_white, float glowed_strength) {
	//apply rgb mask to source.
	//the amount of rgb mask to apply depends on:
	//the difference between reference and source
	//the whiteness of reference
	float col = float(int(gl_FragCoord.x));
	vec3 pixel_out;
	if (int(mod(col, 3.0)) < 1) {
		//color_masked_scanlined = pixel_processed * m1;
		//pixel_out = mymixvec(source, m1, over_white, reference);
		pixel_out = mask_glow_mix(source, m1, reference, glowed_strength, over_white );
	}
	else if (int(mod(col, 3.0)) < 2) {
		//color_masked_scanlined = pixel_processed * m2;
		pixel_out = mask_glow_mix(source, m2, reference, glowed_strength, over_white );
	}
	else {
		//color_masked_scanlined = pixel_processed * m3;
		pixel_out = mask_glow_mix(source, m3, reference, glowed_strength, over_white );
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


float blurWeight(float x, float bloom, float sigma) {
    return (bloom * exp(-(x*x) / (2.0 * sigma * sigma)));
}

vec3 pixel_bloomed(vec4 pixel_source) {
	vec4 color = vec4(0.0);
	float bloom = BLOOM_MULTIPLIER / (BLOOM_SIGMA * sqrt(2.0 * 3.14159)) / float(BLOOM_KERNEL_SIZE) ;
	vec2 texCoordcenter= gl_TexCoord[0].xy;
    vec2 texCoord;
	float inv_step_width=1.0 / (BLOOM_WIDTH/float(BLOOM_KERNEL_SIZE));
	float inv_step_height=1.0/ (BLOOM_HEIGHT/float(BLOOM_KERNEL_SIZE));
    for (int i = -BLOOM_KERNEL_SIZE; i <= BLOOM_KERNEL_SIZE; i++) {
		texCoord = texCoordcenter; //left-right;
		texCoord.x = gl_TexCoord[0].x + (float(i) / inv_step_width);
		color += texture2D(rubyTexture, texCoord) * blurWeight(float(i),bloom, BLOOM_SIGMA) ;

		texCoord = texCoordcenter; //up-down
		texCoord.y = gl_TexCoord[0].y - (float(i) / inv_step_height);
		color += texture2D(rubyTexture, texCoord) * blurWeight(float(i),bloom, BLOOM_SIGMA) ;

		texCoord = texCoordcenter; //diagonal '\'
		texCoord.x = gl_TexCoord[0].x - (float(i) / inv_step_width); 
		texCoord.y = gl_TexCoord[0].y - (float(i) / inv_step_height);
		color += texture2D(rubyTexture, texCoord) * blurWeight(float(i),bloom, BLOOM_SIGMA) ;
		
		texCoord = texCoordcenter; //diagonal '/'
		texCoord.x = gl_TexCoord[0].x + (float(i) / inv_step_width); 
		texCoord.y = gl_TexCoord[0].y - (float(i) / inv_step_height);
		color += texture2D(rubyTexture, texCoord) * blurWeight(float(i),bloom, BLOOM_SIGMA) ;
    }
    //vec4 pixel_source=texture2D(rubyTexture, gl_TexCoord[0].xy);

	return vec3(color.r,color.g,color.b);
}





void main()
{
	vec3 pixel_source = texture2D(rubyTexture, gl_TexCoord[0].xy).xyz; 
	vec3 pixel_processed = pixel_source;
	float glowed_strength = 0.0; //how much the color of the pixel has been changed by the glow.
	vec3 pixel_glowed=pixel_source;
	/* GLOW */
    if ( DO_GLOW == 1) { 
        pixel_processed=pixel_glow(glowpix,glowpixy,glow);

		glowed_strength=is_glowed(pixel_processed,pixel_source);
		pixel_glowed=pixel_processed;
    } 
	

	/* VMASK */
	if ( DO_VMASK == 1) {
	    pixel_processed=pixel_vmask(pixel_processed,pixel_source,VMASK_OVER_WHITE, glowed_strength);
	}
	
	/* DARKLINES */
    if ( DO_DARKLINES == 1 ) {
		if ( DO_DARKLINES_VOFFSET == 1 ) {
			pixel_processed = pixel_darklines_offset(pixel_processed,glowed_strength,pixel_source);
		} else {
			pixel_processed = pixel_darklines_straight(pixel_processed,glowed_strength, pixel_source);
        }
    }
	/* GAMMA */
	float Gr = GAMMA_COR * color_correction.r;
	float Gg = GAMMA_COR * color_correction.g;
	float Gb = GAMMA_COR * color_correction.b;
	pixel_processed = pow(pixel_processed, vec3(Gr,Gg,Gb));




	/* BLOOM */
	if ( DO_BLOOM == 1 ) {
		vec3 p_bloomed=pixel_bloomed(vec4(pixel_glowed,1.0));
		p_bloomed=clamp_01(p_bloomed);
		//float bloom_gamma=2.0; //usalo per limitare l'effetto del bloom
		p_bloomed = pow(p_bloomed, vec3(BLOOM_GAMMA,BLOOM_GAMMA,BLOOM_GAMMA));
		pixel_processed = pixel_processed + p_bloomed;
		pixel_processed /=2.0;
	     
	 
	}
	
	
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
