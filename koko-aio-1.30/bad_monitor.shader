<?xml version="1.0" encoding="UTF-8"?>




<shader language="GLSL">


<fragment scale="1.0" filter="linear"><![CDATA[

    /* check the next shader for more configuration options */
    
    #define DO_SCANLINES           1        //1    1 to enable scanlines
    #define SCAN_OVER_WHITE         1.0      //0.2  How much scanlines affect bright colors. Range [0.0 -> 1.0] 
                                                    //Used to simulate the effect of the blooming
                                                    //on the 'unpainted' parts of the CRT monitor.

    /* Even/odd scanline alpha: */
    #define s1  1.0    
    #define s2  0.0

    uniform sampler2D rubyTexture;
    
    vec4 mymix(vec4 source, float scanline) {
        vec4 white_over_scanline = source -   ( (source -(source * scanline)) * (1.0 -source) ) ;
        vec4 scanline_over_white = source * scanline;

		scanline_over_white *= SCAN_OVER_WHITE ;
        white_over_scanline *= 1.0-SCAN_OVER_WHITE;
        return scanline_over_white + white_over_scanline;
	
    }
    
    void main(void) {
        vec4 pixel = texture2D(rubyTexture, gl_TexCoord[0].xy);  //vec4 per modificare anche l'alpha
        if ( DO_SCANLINES == 1) {
            float line = float(int(gl_FragCoord.y));
            if (int(mod(line, 2.0)) < 1) {
                    pixel *= s1;
            } else {
                    pixel *= s2;
            }
        }
        gl_FragColor = pixel;
    }

//riscalo a 1X per non appesantire i calcoli successivi
	
]]></fragment>


















<fragment filter="linear"><![CDATA[
	uniform int rubyFrameCount ;
	uniform sampler2D rubyTexture;
	uniform vec2 rubyTextureSize;
	uniform vec2 rubyOutputSize ;
	uniform vec2 rubyOrigInputSize;


		

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
			
			vec3 l3 = texture2D(rubyTexture, pC4 -x2 ).xyz; l3=pow(l3,vec3(glow_gamma,glow_gamma,glow_gamma));//l3*=l3;
			vec3 l2 = texture2D(rubyTexture, pC4 -dx ).xyz; l2=pow(l2,vec3(glow_gamma,glow_gamma,glow_gamma));//l2*=l2;
			vec3 l1 = texture2D(rubyTexture, pC4     ).xyz; l1=pow(l1,vec3(glow_gamma,glow_gamma,glow_gamma));//l1*=l1;
			vec3 r1 = texture2D(rubyTexture, pC4 +dx ).xyz; r1=pow(r1,vec3(glow_gamma,glow_gamma,glow_gamma));//r1*=r1;
			vec3 r2 = texture2D(rubyTexture, pC4 +x2 ).xyz; r2=pow(r2,vec3(glow_gamma,glow_gamma,glow_gamma));//r2*=r2;
			vec3 r3 = texture2D(rubyTexture, pC4 +x3 ).xyz; r3=pow(r3,vec3(glow_gamma,glow_gamma,glow_gamma));//r3*=r3;

			vec3 t1 = (l3*wl3 + l2*wl2 + l1*wl1 + r1*wr1 + r2*wr2 + r3*wr3)*wt;
			
			l3 = texture2D(rubyTexture, pC4 -x2 -dy).xyz; l3=pow(l3,vec3(glow_gamma,glow_gamma,glow_gamma));//l3*=l3;
			l2 = texture2D(rubyTexture, pC4 -dx -dy).xyz; l2=pow(l2,vec3(glow_gamma,glow_gamma,glow_gamma));//l2*=l2;
			l1 = texture2D(rubyTexture, pC4     -dy).xyz; l1=pow(l1,vec3(glow_gamma,glow_gamma,glow_gamma));//l1*=l1;
			r1 = texture2D(rubyTexture, pC4 +dx -dy).xyz; r1=pow(r1,vec3(glow_gamma,glow_gamma,glow_gamma));//r1*=r1;
			r2 = texture2D(rubyTexture, pC4 +x2 -dy).xyz; r2=pow(r2,vec3(glow_gamma,glow_gamma,glow_gamma));//r2*=r2;
			r3 = texture2D(rubyTexture, pC4 +x3 -dy).xyz; r3=pow(r3,vec3(glow_gamma,glow_gamma,glow_gamma));//r3*=r3;
			
			vec3 t2 = (l3*wl3 + l2*wl2 + l1*wl1 + r1*wr1 + r2*wr2 + r3*wr3)*wt;    
			
			l3 = texture2D(rubyTexture, pC4 -x2 +dy).xyz; l3=pow(l3,vec3(glow_gamma,glow_gamma,glow_gamma));//l3*=l3;5
			l2 = texture2D(rubyTexture, pC4 -dx +dy).xyz; l2=pow(l2,vec3(glow_gamma,glow_gamma,glow_gamma));//l2*=l2;
			l1 = texture2D(rubyTexture, pC4     +dy).xyz; l1=pow(l1,vec3(glow_gamma,glow_gamma,glow_gamma));//l1*=l1;
			r1 = texture2D(rubyTexture, pC4 +dx +dy).xyz; r1=pow(r1,vec3(glow_gamma,glow_gamma,glow_gamma));//r1*=r1;
			r2 = texture2D(rubyTexture, pC4 +x2 +dy).xyz; r2=pow(r2,vec3(glow_gamma,glow_gamma,glow_gamma));//r2*=r2;
			r3 = texture2D(rubyTexture, pC4 +x3 +dy).xyz; r3=pow(r3,vec3(glow_gamma,glow_gamma,glow_gamma));//r3*=r3;

			vec3 b1 = (l3*wl3 + l2*wl2 + l1*wl1 + r1*wr1 + r2*wr2 + r3*wr3)*wt;

			l3 = texture2D(rubyTexture, pC4 -x2 +y2).xyz; l3=pow(l3,vec3(glow_gamma,glow_gamma,glow_gamma));//l3*=l3;
			l2 = texture2D(rubyTexture, pC4 -dx +y2).xyz; l2=pow(l2,vec3(glow_gamma,glow_gamma,glow_gamma));//l2*=l2;
			l1 = texture2D(rubyTexture, pC4     +y2).xyz; l1=pow(l1,vec3(glow_gamma,glow_gamma,glow_gamma));//l1*=l1;
			r1 = texture2D(rubyTexture, pC4 +dx +y2).xyz; r1=pow(r1,vec3(glow_gamma,glow_gamma,glow_gamma));//r1*=r1;
			r2 = texture2D(rubyTexture, pC4 +x2 +y2).xyz; r2=pow(r2,vec3(glow_gamma,glow_gamma,glow_gamma));//r2*=r2;
			r3 = texture2D(rubyTexture, pC4 +x3 +y2).xyz; r3=pow(r3,vec3(glow_gamma,glow_gamma,glow_gamma));//r3*=r3;
			
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
	
	#define in_glow_w     1.5            //2.0  Input signal blur/glow width tightness
	#define in_glow_h     1.5            //2.0  Input signal blur/glow height tightness
	#define in_glow_power 1.8            //1.8  Input signal glow strength
	#define in_glow_gamma 5.0            //5.0  The higher,  the less the glow on dark colors	

	// RGB mask:       R     G     B
    #define m1 vec3 ( 1.0 , 0.0 , 0.0 )    //col 1
    #define m2 vec3 ( 0.0 , 1.0 , 0.0 )    //col 2
    #define m3 vec3 ( 0.0 , 0.0 , 1.0  )   //col 3


	#define halo_w     0.5            //1.2  halo width tightness
	#define halo_h     0.5            //1.2  halo height tightness
	#define halo_power 2.0           //1.2   halo strength
	#define halo_gamma 5.0           //2.0   the higher, the less the halo on dark colors	
	

	#define color_correction vec3(0.46 ,0.45 , 0.44)    //(0.46,0.45,0.44) r,g,b, gamma correction.	
	#define GAMMA_COR    1.8                            //1.8   Gamma correction, the higher, the darker.
	
    void main(void) {
        vec3 pixel_in = texture2D(rubyTexture, gl_TexCoord[0].xy).rgb; 
		vec3 pixel_out = pixel_in;
		
		//ora facciamo un gaussian_blur per aggiustare le scanline
		pixel_out = pixel_glow(10.0,3.0,1.0,1.0);
		
		
		//il segnale in ingresso è blurrato e glowa.
		//la quantità di glow rispetto al blur è regolata da glow_gamma1
		//questo permette alla maschera rgb di illuminarsi sulla scanline nera.
		vec3 glowed = pixel_glow(in_glow_w,in_glow_h,in_glow_power,in_glow_gamma);
		pixel_out +=glowed;
        

		
		//applicahiamo la vmask
		pixel_out = pixel_vmask(pixel_out,m1,m2,m3);

		//test tag scanlines via alpha
		//vec4 pixel_in4 = texture2D(rubyTexture, gl_TexCoord[0].xy); 
		//if (pixel_in4.a < 0.5) { pixel_out=vec3(1.0,0.0,0.0); }
		
		//halo
		vec3 haloed = pixel_glow(halo_w,halo_h,halo_power,halo_gamma);
		pixel_out +=haloed;
		
		
		//rgb gamma
		float Gr = GAMMA_COR * color_correction.r;
		float Gg = GAMMA_COR * color_correction.g;
		float Gb = GAMMA_COR * color_correction.b;
		pixel_out = pow(pixel_out,vec3(Gr,Gg,Gb));
		
		gl_FragColor = vec4(pixel_out,1.0);
    }
]]></fragment>
    
    
    
    
    

    


</shader>
