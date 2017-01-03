// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

Shader "Custom/dx_11_ocean" {
	Properties {
		// Unity inputs for shader params
		//__deepColor 		("Deep Color", 	Color) 			= (1,1,1,1)
		//__shallowColor 	("Shallow Color", 	Color) 			= (1,1,1,1)
		specIntensity 	("Spec Intensity", 	range(0, 10)) 	= 1.0
		timerScale1 	("Timer Scale 1", 	range(0, 1)) 	= 0.2

		// Wave stuff
		amplitude 		("Amplitude", 		range(0, 10)) 	= 0.4
		waveLength 		("Wavelength", 		range(0, 10)) 	= 2.5
		crestFactor 	("Crest Factor", 	range(0, 10)) 	= 1.0
		speed 			("Speed", 			range(0, 5)) 	= 1.0
		dirX 			("Direction X", 	range(-1, 1)) 	= 1.0
		dirY 			("Direction Y", 	range(-1, 1)) 	= 0.0

		// Fresnel stuff
		fresBias 		("Fresnel Bias", 	float) 			= 0.0
		fresScale 		("Fresnel Scale", 	float) 			= 1.0
		fresPower 		("Fresnel Power", 	float) 			= 5.0
		
		// Texture maps
		//diffMap 		("Diffuse Map", 2D) 		= "white" {}
		normalMap		("Normal Map", 	2D) 		= "bump" {}
		foamMap			("Foam Map", 	2D) 		= "white" {}
		foamMask		("Foam Mask", 	2D) 		= "white" {}
		//noiseMap		("Noise Map", 	2D) 		= "white" {}
		cubeMap			("Cube Map", 	CUBE) 		= "" {}

		_FoamStrength ("Foam Strength", Range (0, 10)) = 1
		_ShoreFoamStrength ("Shore Foam Strength", Range (0, 10)) = 1
		_ShoreFoamOpacity ("Shore Foam Opacity", Range (0, 10)) = 1
		//_ShoreFoamTransparency ("Shore Foam Transparency", Range (0, 10)) = 1
		_WaterDepth ("Water Depth",	 Range (0, 5)) = 1
		//_DepthFade ("Depth Fade", Range (0, 10)) = 0.5
		_FoamFade ("Foam Fade", Range (0, 10)) = 0.5
		//_TranslucentStrength ("Overall Translucency", Range (0, 1)) = 1.0
		_DepthColorSwitch ("Depth Colour Switch", Range (0, 10)) = 1.0
		_ShoreFoamFade ("_ShoreFoamFade", Range (0, 10)) = 1.0
		//diffuseStrength ("Diffuse Strength", Range (0, 1)) = 1.0
		[IntRange] _Weather ("Weather", Range (0, 1)) = 0
		[IntRange] _Environ ("Ocean Env", Range (0, 1)) = 0
		//[KeywordEnum(Calm, Stormy)] 		_Weather("Weather", 	Float) = 0
		[KeywordEnum(Carribean, North Sea)] _EnumEnviron("Ocean Env", 	Float) = 0
	}
	SubShader {
		Tags { "RenderType" = "Transparent" "Queue" = "Transparent" "IgnoreProjector"="True"}	
		//Blend SrcAlpha OneMinusSrcAlpha

		// Pass that renders the scene geometry into a texture
        GrabPass 
        {
        	"_RefractPassTex"
            Tags { "LightMode" = "Always" }
        }
		Pass{
			Blend SrcAlpha OneMinusSrcAlpha  
			//Tags { "RenderType" = "Transparent" "Queue" = "Transparent" }	
            //ZWrite Off
            //Cull Off
			//Tags { "RenderType"="Opaque" }			
					
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma fragmentoption ARB_precision_hint_fastest
			#pragma multi_compile
			#include "UnityCG.cginc"
			#include "common.cginc"

			uniform sampler2D diffMap;
			uniform sampler2D normalMap;
			uniform sampler2D foamMap;
			uniform sampler2D foamMask;
			//uniform sampler2D noiseMap;
			uniform samplerCUBE cubeMap;

			// Grab pass texture outputs
			sampler2D _RefractPassTex;
			float4 _RefractPassTex_TexelSize;

			uniform float specIntensity;
			uniform float timerScale1;
			uniform float amplitude;
			uniform float waveLength;
			uniform float speed=2.1;
			uniform float crestFactor;
			uniform float fresBias;
			uniform float fresScale;
			uniform float fresPower;
			uniform float dirX=1.0;
			uniform float dirY=0.0;

			// Enum variables
			float4 deepColor;
			float4 shallowColor;

			float _FoamStrength;
			float _ShoreFoamStrength;
			float _ShoreFoamOpacity;
			//float _ShoreFoamTransparency;
			float _WaterDepth;
			float _DepthFade= 1.45;
			float _FoamFade;
			float _TranslucentStrength;
			float _DepthColorSwitch;
			float diffuseStrength;

			uniform float4 diffMap_ST;
			uniform float4 normalMap_ST;
			uniform float4 foamMap_ST;
			uniform float4 foamMask_ST;
			//uniform float4 noiseMap_ST;

			// Static for the time being... Need to make them a bit more dynamic
			static float mulArray[3] 	= {0.561, 1.793, 0.697};
			static float2 dirsArray[3] 	= {float2(0, 1.0), float2(1.0, 0.5), float2(0.25, 1.0)};

			// Unity Defined Variables;
			uniform float4 _LightColor0;
			uniform sampler2D _CameraDepthTexture; //the depth texture

			// input from application 
			struct app2vertex
			{ 
				float4 position			: POSITION;
				float2 texCoord0		: TEXCOORD0;
				float4 tangent			: TANGENT;
				float3 normal			: NORMAL;
			}; 

			// output to pixel shader 
			struct vertex2frag
			{ 
			    float4 position    		: SV_POSITION;
			   	float2 texCoord0		: TEXCOORD0;
				float3 viewVec			: TEXCOORD1;
				float3 worldNormal		: TEXCOORD2;
				float3 worldTangent		: TEXCOORD3;
				float3 worldBinormal	: TEXCOORD4;
				float4 posWorld			: TEXCOORD5;
				float4 scrPos			: TEXCOORD6;
				float4 uvRefr			: TEXCOORD7;
			};

			vertex2frag vert(app2vertex In)
			{ 
				vertex2frag Out = (vertex2frag)0;
				float4 worldSpacePos = mul(unity_ObjectToWorld, In.position);
				Out.posWorld = worldSpacePos;

				float3 sumW = float3(0,0,0);
				float3 sumB = float3(0,0,0);
				float3 sumT = float3(0,0,0);
				float3 sumN = float3(0,0,0);
				float2 dirsXY = float2(dirX, dirY);
				//sumW = gerstnerWave(In.position, 	1, dirsXY, amplitude, waveLength, crestFactor, speed, _Time.y, 0);
				for(int i=0; i < 3; i++)
				{
					//float2 dirsVal = dirsArray[i]*dirsXY;
					float2 dirsVal = dirsArray[i]*dirsXY;
					float mulVal = mulArray[i]*2-1;//* customNoise(dirsVal);
					sumW += gerstnerWave(In.position, 		mulArray[i], dirsArray[i], amplitude, waveLength, crestFactor, speed, _Time.y, 0);
					sumB += gerstnerWave(sumW, 				mulArray[i], dirsArray[i], amplitude, waveLength, crestFactor, speed, _Time.y, 1);
					sumT += gerstnerWave(sumW, 				mulArray[i], dirsArray[i], amplitude, waveLength, crestFactor, speed, _Time.y, 2);
					sumN += gerstnerWave(sumW, 				mulArray[i], dirsArray[i], amplitude, waveLength, crestFactor, speed, _Time.y, 3);
				}
				// Calculate final pos, binorm, tangent and normal
				In.position.xyz += sumW;

				sumB.x = 1-sumB.x;
				sumB.z = -sumB.z;

				sumT.x = -sumT.x;
				sumT.y = 1-sumT.y;

				sumN.x = -sumN.x;
				sumN.y = 1-sumN.y;
				sumN.z = -sumN.z;

				// _World2Object is Unity version of WorldInverseTranspose
				Out.worldNormal = normalize(mul(unity_WorldToObject, In.normal+sumN).xyz);
				Out.worldTangent = normalize(mul(unity_ObjectToWorld, In.tangent).xyz);
				Out.worldBinormal = normalize(cross(Out.worldNormal, Out.worldTangent*In.tangent.w)); // tangent.w is specific to Unity
				Out.worldBinormal += sumB;

				// Final output position & screenposition
				Out.position = mul(UNITY_MATRIX_MVP, In.position);
				Out.scrPos = ComputeScreenPos(Out.position);
				//Out.scrPos.y = 1 - Out.scrPos.y;
			    Out.texCoord0 = In.texCoord0;

			    float sumTimer = 0.0;
			    for(int i=0; i < 3; i++)
			    {
			    	sumTimer += (_Time.y);
			    }

			    Out.texCoord0.x += (_Time.y*timerScale1*0.05);

				// From Unity built in function: _WorldSpaceCameraPos.xyz - mul(_Object2World, v).xyz;
				Out.viewVec = WorldSpaceViewDir(In.position);

            	// Calculates the grab screen position
	            #if UNITY_UV_STARTS_AT_TOP
            	float scale = -1.0;
            	#else
            	float scale = 1.0;
            	#endif
            	Out.uvRefr.xy = (float2(Out.position.x, Out.position.y*scale) + Out.position.w) * 0.5;
            	Out.uvRefr.zw = Out.position.zw;

			    return Out;
			}

			//static float2 texOffset[5] 	= {float2(0.65, 1.0), float2(1.43, 0.5), float2(0.25, 1.0), float2(1.75, 0.25), float2(1.25, 1.0)};
			static float texOffset[5] 	= {1.15, 0.1, 0.25, 0.5, 0.75};
	        fixed4 frag (vertex2frag In) : SV_Target
	        {	
	        	// Lighting
	            float attenuation;
	            float3 light0Dir;
				if (0.0 == _WorldSpaceLightPos0.w) // directional light
				{
					attenuation = 1.0;
					light0Dir 	= normalize(_WorldSpaceLightPos0.xyz);
				} 
				else // point or spot light
				{
					float3 pixToLight 	= _WorldSpaceLightPos0.xyz - In.posWorld.xyz;
					float distance 		= length(pixToLight);
					attenuation 		= 1.0 / distance; // linear attenuation 
					light0Dir 			= normalize(pixToLight);
				}

				// Textures
	        	float3x3 toWorld 	= float3x3(In.worldTangent, In.worldBinormal, In.worldNormal);
	            float3 normal 		= tex2D(normalMap, normalMap_ST.xy * In.texCoord0 + normalMap_ST.zw)*2-1;
	            float3 bumpWorld 	= normalize(mul(normal,toWorld));
	            float4 foamTex 		= tex2D(foamMap, foamMap_ST.xy * In.texCoord0 + foamMap_ST.zw);
	            float4 foamMaskTex 	= tex2D(foamMask, foamMask_ST.xy * In.texCoord0 + foamMask_ST.zw);

	            // TODO: FIX THIS, THE SWITCHING DOES NOT WORK!
    			#if _Environ == 0
					deepColor 		= color_to_float(float4(38, 91, 193, 255));
					shallowColor 	= color_to_float(float4(0, 191, 208, 150));
				#elif _Environ == 1
					deepColor 		= color_to_float(float4(255, 0, 0, 255));
					shallowColor 	= color_to_float(float4(255, 0, 0, 255));
				#endif
	
	            // Foam scrolling & adding up masking
	            for(int i=0; i<5; i++)
				{
		           	float offset = sin(texOffset[i]*dirX);
		           	offset *= cos(texOffset[i]*dirX);
		           	float2 xyTile = foamMask_ST.xy*texOffset[i];
		           	float2 zwTile = foamMask_ST.zw*texOffset[i];
		           	foamMaskTex += tex2D(foamMask, xyTile * (In.texCoord0+offset)*2-1 + zwTile);
				}

            	// Depth calculations
            	//In.scrPos.xy += refracted.xy * distortion;
				float sceneZ = LinearEyeDepth (tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(In.scrPos)).r);
				float objectZ = In.scrPos.z;
				//float intensityFactor = 1 - saturate((sceneZ - objectZ)/_WaterDepth);
				float waterDepthFactor = saturate((sceneZ - objectZ)/_WaterDepth);
				float depthFadeFactor = 1 - saturate(_DepthFade - (sceneZ - objectZ));
				float foamFadeFactor = 1 - saturate(_FoamFade - (sceneZ - objectZ));

	           	////////// Refraction testing /////////////
	           	float3 refrNormal 	= tex2D(normalMap, 1.5*In.texCoord0)*2-1;
            	float distortion = 100.0; // warping just enough to not look blurry
            	float3 refracted = refrNormal * abs(refrNormal);
	            float4 projA = In.uvRefr;
	            //return projA;
            	refracted.xy *= _RefractPassTex_TexelSize.xy*5;
            	projA.xy = refracted.xy * distortion + In.uvRefr.xy;
            	float4 underWaterRefr = tex2Dproj( _RefractPassTex, projA);
            	underWaterRefr.a -= pow(waterDepthFactor, underWaterRefr.a);
            	//underWaterRefr = normalize(underWaterRefr);
            	return underWaterRefr;

            	// Reflection Stuff
            	float3 V = In.viewVec;
				float3 R = reflect(V,refracted); // Using refracted instead of bumpworld is much softer
				float3 refraction = refract(V, underWaterRefr, 1.3333);
			    float4 reflectedColor = texCUBE(cubeMap, R);
    			float4 refractedColor = texCUBE(cubeMap, -R);
    			// TODO: Try a different fresnel calculation???
    			float reflectionCoefficient = fresBias + fresScale * pow(1.0 - dot(normalize(V), In.worldNormal), fresPower);

    			// Specular stuff
				float3 reflection = reflect(bumpWorld, -light0Dir);
				float4 specular = dot(normalize(reflection), normalize(V));
				specular = pow(specular, 256);
				specular *= specIntensity * _LightColor0;

				// Lighting & Color
				float4 color = deepColor;
				color.xyz *= _LightColor0; // _LightColor0 comes premultiplied with intensity
				//float diffLight = saturate(dot(bumpWorld, light0Dir));
				//color *= diffLight;
				//color += (diffuse*diffuseStrength);

				// Initial color calculation
				float3 cFinal = lerp(reflectedColor, underWaterRefr+color, reflectionCoefficient);
				float4 final = float4(cFinal, 1);
				//return final;
				float4 resultColor = lerp(color, final, reflectionCoefficient);

				// Surface Color + master foam surface
				float fm 		= clamp(pow(foamTex, 7),0,1);
				resultColor 	= saturate(lerp(resultColor, foamTex*_FoamStrength, fm) + specular);
				resultColor.a 	*= waterDepthFactor;
				//return resultColor+underWaterRefr;
				//return lerp(resultColor, underWaterRefr, -waterDepthFactor);
				//resultColor 	+= underWaterRefr;

				// changing alpha after master foam is added to sea
				foamTex.a *= foamMaskTex*0.25;
				foamTex*=_ShoreFoamStrength;

				// FIX THIS: WATER COLOR B IS BLENDING IN WITH THE SHORLINE FOAM. WE DO NOT WANT THIS
				shallowColor.a *= depthFadeFactor;
				float4 water = lerp(shallowColor, resultColor, pow(waterDepthFactor, 1.0/_DepthColorSwitch)); // Switching between surface & depth colors
				water = lerp(foamTex, water, foamFadeFactor); // FIX THIS. FOAM FADE FACTOR IS NOT ENOUGH. IT GETS RID OF THE NICE FADE AT THE SHORLINE

				//float4 blendW = water;
				float4 refrWater = lerp(water, underWaterRefr,underWaterRefr.a); // THIS LINE IS VERY VERY CLOSE NEED TO GET THE VALUES & SLIDERS CORRECT
				//refrWater.a *= waterDepthFactor;
				//return refrWater;
				//water = lerp(refrWater, water, pow(waterDepthFactor, 5));
				//water = lerp(refrWater, water, pow(waterDepthFactor, 1.0/_DepthColorSwitch));
				//water.xyz *= underWaterRefr.x;
				return water;
	        }
			ENDCG
		}
	}
	FallBack "Diffuse"
}
