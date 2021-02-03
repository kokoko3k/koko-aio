<?xml version="1.0" encoding="UTF-8"?>


<shader language="GLSL">


<fragment scale="1.0" filter="linear"><![CDATA[
   
    #define DO_SCANLINES          0        //1    1 to enable scanlines
    /* Even/odd scanline: */
    #define s1  1.0    
    #define s2  0.0

    uniform sampler2D rubyTexture;
   
    void main(void) {
        vec3 pixel = texture2D(rubyTexture, gl_TexCoord[0].xy).rgb;  //vec4 per modificare anche l'alpha
        if ( DO_SCANLINES == 1) {
            float line = float(int(gl_FragCoord.y));
            if (int(mod(line, 2.0)) < 1) {
                    pixel *= s1;
            } else {
                    pixel *= s2;
            }
        }
        gl_FragColor = vec4(pixel,1.0);
    }
	
]]></fragment>




<fragment outscale="1.0" filter="linear"><![CDATA[
	uniform int rubyFrameCount ;
	uniform sampler2D rubyTexture;
	uniform vec2 rubyTextureSize;
	uniform vec2 rubyOutputSize ;
	uniform vec2 rubyOrigInputSize;


	vec3 int_pow(vec3 v, float fpow){
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
			
			vec3 l3 = texture2D(rubyTexture, pC4 -x2 ).xyz; //l3=pow(l3,vec3(glow_gamma,glow_gamma,glow_gamma));//l3*=l3;
			vec3 l2 = texture2D(rubyTexture, pC4 -dx ).xyz; //l2=pow(l2,vec3(glow_gamma,glow_gamma,glow_gamma));//l2*=l2;
			vec3 l1 = texture2D(rubyTexture, pC4     ).xyz; //l1=pow(l1,vec3(glow_gamma,glow_gamma,glow_gamma));//l1*=l1;
			vec3 r1 = texture2D(rubyTexture, pC4 +dx ).xyz; //r1=pow(r1,vec3(glow_gamma,glow_gamma,glow_gamma));//r1*=r1;
			vec3 r2 = texture2D(rubyTexture, pC4 +x2 ).xyz; //r2=pow(r2,vec3(glow_gamma,glow_gamma,glow_gamma));//r2*=r2;
			vec3 r3 = texture2D(rubyTexture, pC4 +x3 ).xyz; //r3=pow(r3,vec3(glow_gamma,glow_gamma,glow_gamma));//r3*=r3;
			l3=int_pow(l3,glow_gamma); l2=int_pow(l2,glow_gamma); l1=int_pow(l1,glow_gamma); 
			r1=int_pow(r1,glow_gamma); r2=int_pow(r2,glow_gamma); r3=int_pow(r3,glow_gamma); 

			vec3 t1 = (l3*wl3 + l2*wl2 + l1*wl1 + r1*wr1 + r2*wr2 + r3*wr3)*wt;
			
			l3 = texture2D(rubyTexture, pC4 -x2 -dy).xyz; //l3=pow(l3,vec3(glow_gamma,glow_gamma,glow_gamma));//l3*=l3;
			l2 = texture2D(rubyTexture, pC4 -dx -dy).xyz; //l2=pow(l2,vec3(glow_gamma,glow_gamma,glow_gamma));//l2*=l2;
			l1 = texture2D(rubyTexture, pC4     -dy).xyz; //l1=pow(l1,vec3(glow_gamma,glow_gamma,glow_gamma));//l1*=l1;
			r1 = texture2D(rubyTexture, pC4 +dx -dy).xyz; //r1=pow(r1,vec3(glow_gamma,glow_gamma,glow_gamma));//r1*=r1;
			r2 = texture2D(rubyTexture, pC4 +x2 -dy).xyz; //r2=pow(r2,vec3(glow_gamma,glow_gamma,glow_gamma));//r2*=r2;
			r3 = texture2D(rubyTexture, pC4 +x3 -dy).xyz; //r3=pow(r3,vec3(glow_gamma,glow_gamma,glow_gamma));//r3*=r3;
			l3=int_pow(l3,glow_gamma); l2=int_pow(l2,glow_gamma); l1=int_pow(l1,glow_gamma); 
			r1=int_pow(r1,glow_gamma); r2=int_pow(r2,glow_gamma); r3=int_pow(r3,glow_gamma); 
			
			vec3 t2 = (l3*wl3 + l2*wl2 + l1*wl1 + r1*wr1 + r2*wr2 + r3*wr3)*wt;    
			
			l3 = texture2D(rubyTexture, pC4 -x2 +dy).xyz; //l3=pow(l3,vec3(glow_gamma,glow_gamma,glow_gamma));//l3*=l3;5
			l2 = texture2D(rubyTexture, pC4 -dx +dy).xyz; //l2=pow(l2,vec3(glow_gamma,glow_gamma,glow_gamma));//l2*=l2;
			l1 = texture2D(rubyTexture, pC4     +dy).xyz; //l1=pow(l1,vec3(glow_gamma,glow_gamma,glow_gamma));//l1*=l1;
			r1 = texture2D(rubyTexture, pC4 +dx +dy).xyz; //r1=pow(r1,vec3(glow_gamma,glow_gamma,glow_gamma));//r1*=r1;
			r2 = texture2D(rubyTexture, pC4 +x2 +dy).xyz; //r2=pow(r2,vec3(glow_gamma,glow_gamma,glow_gamma));//r2*=r2;
			r3 = texture2D(rubyTexture, pC4 +x3 +dy).xyz; //r3=pow(r3,vec3(glow_gamma,glow_gamma,glow_gamma));//r3*=r3;
			l3=int_pow(l3,glow_gamma); l2=int_pow(l2,glow_gamma); l1=int_pow(l1,glow_gamma); 
			r1=int_pow(r1,glow_gamma); r2=int_pow(r2,glow_gamma); r3=int_pow(r3,glow_gamma); 
			
			vec3 b1 = (l3*wl3 + l2*wl2 + l1*wl1 + r1*wr1 + r2*wr2 + r3*wr3)*wt;

			l3 = texture2D(rubyTexture, pC4 -x2 +y2).xyz; //l3=pow(l3,vec3(glow_gamma,glow_gamma,glow_gamma));//l3*=l3;
			l2 = texture2D(rubyTexture, pC4 -dx +y2).xyz; //l2=pow(l2,vec3(glow_gamma,glow_gamma,glow_gamma));//l2*=l2;
			l1 = texture2D(rubyTexture, pC4     +y2).xyz; //l1=pow(l1,vec3(glow_gamma,glow_gamma,glow_gamma));//l1*=l1;
			r1 = texture2D(rubyTexture, pC4 +dx +y2).xyz; //r1=pow(r1,vec3(glow_gamma,glow_gamma,glow_gamma));//r1*=r1;
			r2 = texture2D(rubyTexture, pC4 +x2 +y2).xyz; //r2=pow(r2,vec3(glow_gamma,glow_gamma,glow_gamma));//r2*=r2;
			r3 = texture2D(rubyTexture, pC4 +x3 +y2).xyz; //r3=pow(r3,vec3(glow_gamma,glow_gamma,glow_gamma));//r3*=r3;
			l3=int_pow(l3,glow_gamma); l2=int_pow(l2,glow_gamma); l1=int_pow(l1,glow_gamma); 
			r1=int_pow(r1,glow_gamma); r2=int_pow(r2,glow_gamma); r3=int_pow(r3,glow_gamma); 
			
			vec3 b2 = (l3*wl3 + l2*wl2 + l1*wl1 + r1*wr1 + r2*wr2 + r3*wr3)*wt;    
			
			wl2 = 1.0 + fp.y; wl2*=wl2; wl2 = exp2(-my_glowpixy*wl2);
			wl1 =       fp.y; wl1*=wl1; wl1 = exp2(-my_glowpixy*wl1);
			wr1 = 1.0 - fp.y; wr1*=wr1; wr1 = exp2(-my_glowpixy*wr1);
			wr2 = 2.0 - fp.y; wr2*=wr2; wr2 = exp2(-my_glowpixy*wr2);
			
			wt = 1.0/(wl2+wl1+wr1+wr2);    
			
			vec3 Bloom = (t2*wl2 + t1*wl1 + b1*wr1 + b2*wr2)*wt;
			return Bloom*my_glow;
	}

	vec3 pixel_vmask(vec3 source,vec3 lm1,vec3 lm2,vec3 lm3) {
		float col = float(int(gl_FragCoord.x));
		vec3 pixel_out;
		if (int(mod(col, 3.0)) < 1) {
			pixel_out = lm1*source;
		}
		else if (int(mod(col, 3.0)) < 2) {
			pixel_out = lm2*source;
		}
		else {
			pixel_out = lm3*source;
		}
		
		return pixel_out;
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
	
vec3 pixel_darklines_offset(vec3 source,float darkline_every, float darkline_trans) {
	vec3 pixel_out=source;
	float col_2 =  gl_FragCoord.x;
	float line_2 = gl_FragCoord.y;

	float fDarkline_part_w=3.0 ;             //Triads width, float type
	float fDarkline_part_w_x2 = 6.0 ;        //Triads width, float type, *2
	int iDarkline_part_w = 3 ;               //Triads width, integer type (3 pixels unless changing m1,m2,m3 datatype
	
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
	
	return pixel_out;
}

	#define FIX_SCANLINES 1.0			 //1.0 to mitigate dephasing when FS-UAE scales the texture
	
	#define DO_IN_GLOW	  0.0			 //1.0 to activate
	#define in_glow_w     1.5            //2.0  Input signal blur/glow width tightness
	#define in_glow_h     1.5            //2.0  Input signal blur/glow height tightness
	#define in_glow_power 1.8            //1.8  Input signal glow strength
	#define in_glow_gamma 5.0            //5.0  1.0-9.0, The higher,  the less the glow on dark colors, use integers.

	#define DO_RGB_MASK	  1.0			 //1.0 to activate
	// RGB mask:       R     G     B
    #define m1 vec3 ( 1.0 , 0.0 , 0.0 )    //col 1
    #define m2 vec3 ( 0.0 , 1.0 , 0.0 )    //col 2
    #define m3 vec3 ( 0.0 , 0.0 , 1.0  )   //col 3

	#define DO_DARKLINES	  0.0			 //1.0 to activate
	
	#define DO_HALO	   0.0			  //1.0 to activate
	#define halo_w     0.5            //1.2  halo width tightness
	#define halo_h     0.5            //1.2  halo height tightness
	#define halo_power 2.0            //1.2   halo strength
	#define halo_gamma 5.0            //2.0   1.0-9.0, The higher, the less the halo on dark colors, use integers.
	
	#define DO_BLOOM	  		0.0	  //1.0 to activate
	#define bloom_directions	16.0  // BLOOM DIRECTIONS (Default 16.0 - More is better but slower)
	#define bloom_quality		2.0   // BLOOM QUALITY (Default 4.0 - More is better but slower)
	#define bloom_size			5.0   // BLOOM SIZE (Radius)
	#define bloom_mix			0.2   // BLOOM final mix 

	#define DO_COLOR_CORRECTION	  0.0			 //1.0 to activate
	#define color_correction vec3(0.46 ,0.45 , 0.44)    //(0.46,0.45,0.44) r,g,b, gamma correction.	
	#define GAMMA_COR    1.5                            //1.8   Gamma correction, the higher, the darker.
	
    void main(void) {
        vec3 pixel_in = texture2D(rubyTexture, gl_TexCoord[0].xy).rgb; 
		vec3 pixel_out = pixel_in;
		
		if (FIX_SCANLINES == 1.0) { 
			//blur scanlines vertically to make them look better when texure scales.
			pixel_out = pixel_glow(10.0,3.0,1.0,1.0);
		}
		
		if (DO_IN_GLOW == 1.0) { 
		    /* Input signal is blurred and glows.
			   glow power versus blur power is defined by in_glow_gamma.
		       this allows the rgb vmask to light up on the black scanline.
		    */
			vec3 glowed = pixel_glow(in_glow_w,in_glow_h,in_glow_power,in_glow_gamma);
			pixel_out +=glowed;
        }
		
	    /* whiteness is useful if we want to draw less darklines on bright colors.
		   we need to calculate it now, nefore applying vmask.
		*/ float whiteness=(pixel_out.r+pixel_out.g+pixel_out.b)/3.0;
		   whiteness=min(whiteness,1.0) ;// whiteness=max(whiteness,0.0) ; 
		
		if (DO_RGB_MASK == 1.0) { 
			pixel_out = pixel_vmask(pixel_out,m1,m2,m3);
		}

		if (DO_DARKLINES == 1.0) { 
			pixel_out = pixel_darklines_offset(pixel_out,4.0,whiteness);
		}
		
		if (DO_HALO == 1.0) { 
			vec3 haloed = pixel_glow(halo_w,halo_h,halo_power,halo_gamma);
			pixel_out +=haloed;
		}
		
		if (DO_BLOOM == 1.0) {
			vec3 bloomed = blur(bloom_directions,bloom_quality,bloom_size);
			pixel_out = (pixel_out * (1.0-bloom_mix) ) + ( bloomed*bloom_mix);
		}

		
		if (DO_COLOR_CORRECTION == 1.0) {
			float Gr = GAMMA_COR * color_correction.r;
			float Gg = GAMMA_COR * color_correction.g;
			float Gb = GAMMA_COR * color_correction.b;
			pixel_out = pow(pixel_out,vec3(Gr,Gg,Gb));
		}
		
		gl_FragColor = vec4(pixel_out,1.0);
    }
]]></fragment>
    
    
<fragment scale="1.0" filter="linear"><![CDATA[
   
    #define DO_SCANLINES           1        //1    1 to enable scanlines
    /* Even/odd scanline: */
    #define s1  1.0    
    #define s2  0.0

    uniform sampler2D rubyTexture;
   
    void main(void) {
        vec3 pixel = texture2D(rubyTexture, gl_TexCoord[0].xy).rgb;  //vec4 per modificare anche l'alpha
        if ( DO_SCANLINES == 1) {
            float line = float(int(gl_FragCoord.y));
            if (int(mod(line, 2.0)) < 1) {
                    pixel *= s1;
            } else {
                    pixel *= s2;
            }
        }
        gl_FragColor = vec4(pixel,1.0);
    }
	
]]></fragment>
    
    

    


</shader>
