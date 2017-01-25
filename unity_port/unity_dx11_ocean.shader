// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

Shader "Custom/dx_11_ocean" {
	Properties {
		// Unity inputs for shader params
		deepColor 		("Deep Color", 	Color) 			= (1,1,1,1)
		shallowColor 	("Shallow Color", 	Color) 			= (1,1,1,1)
		specIntensity 	("Spec Intensity", 	range(0, 10)) 	= 1.0
		timerScale1 	("Timer Scale 1", 	range(0, 1)) 	= 0.2

		// Wave stuff
		amplitude 		("Amplitude", 		range(0, 10)) 	= 0.4
		waveLength 		("Wavelength", 		range(0, 10)) 	= 2.5
		crestFactor 	("Crest Factor", 	range(0, 10)) 	= 1.0
		speed 			("Speed", 			range(0, 5)) 	= 1.0
		dirX 			("Direction X", 	range(-1, 1)) 	= 1.0
		dirY 			("Direction Y", 	range(-1, 1)) 	= 0.0
		
		// Texture maps
		//diffMap 		("Diffuse Map", 2D) 		= "white" {}
		normalMap		("Normal Map", 	2D) 		= "bump" {}
		normalMap2		("Normal Map 2", 	2D) 		= "bump" {}
		refractionMap		("Refract Map", 2D) 		= "bump" {}
		foamMap			("Foam Map", 	2D) 		= "white" {}
		foamMask		("Foam Mask", 	2D) 		= "white" {}
		//noiseMap		("Noise Map", 	2D) 		= "white" {}
		cubeMap			("Cube Map", 	CUBE) 		= "" {}

		_FoamStrength ("Foam Strength", Range (0, 10)) = 1
		_ShoreFoamStrength ("Shore Foam Strength", Range (0, 10)) = 1
		//_ShoreFoamOpacity ("Shore Foam Opacity", Range (0, 10)) = 1
		//_ShoreFoamTransparency ("Shore Foam Transparency", Range (0, 10)) = 1
		_WaterDepth ("Water Depth",	 Range (0, 15)) = 1
		_DepthFade ("Depth Fade", Range (0, 10)) = 0.5
		_FoamFade ("Foam Fade", Range (0, 10)) = 0.5
		_FoamDepthFade ("Foam Depth Fade", Range (0, 10)) = 0.5
		//_TranslucentStrength ("Overall Translucency", Range (0, 1)) = 1.0
		_DepthColorSwitch ("Depth Colour Switch", Range (0, 10)) = 1.0
		//_ShoreFoamFade ("_ShoreFoamFade", Range (0, 10)) = 1.0
		//diffuseStrength ("Diffuse Strength", Range (0, 1)) = 1.0
		//[IntRange] _Weather ("Weather", Range (0, 1)) = 0
		//[IntRange] _Environ ("Ocean Env", Range (0, 1)) = 0
		////[KeywordEnum(Calm, Stormy)] 		_Weather("Weather", 	Float) = 0
		[KeywordEnum(Carribean, North Sea, User)] _Environ("Ocean Env", 	int) = 0
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
			#pragma debug
			#include "UnityCG.cginc"
			#include "common.cginc"

			uniform sampler2D diffMap;
			uniform sampler2D normalMap;
			uniform sampler2D normalMap2;
			uniform sampler2D foamMap;
			uniform sampler2D foamMask;
			uniform sampler2D refractionMap;
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
			float _FoamDepthFade;
			float _TranslucentStrength;
			float _DepthColorSwitch;
			float diffuseStrength;
			int _Environ;

			uniform float4 diffMap_ST;
			uniform float4 normalMap_ST;
			uniform float4 normalMap2_ST;
			uniform float4 foamMap_ST;
			uniform float4 foamMask_ST;
			uniform float4 refractionMap_ST;
			//uniform float4 noiseMap_ST;

			// Wave, Amplitude & direction now predefined
			static float mulArray[4] 	= {12, 8, 4, 2};
			static float waveArray[4] 	= {0.25, 0.75, 1.15, 1.25};
			static float ampArray[4] 	= {0.75, 0.9, 1.15, 1.25};
			static float2 dirsArray[4] 	= {float2(-1.0, 0), float2(-0.75, 0.5), float2(0.75, -0.25), float2(-0.75, 0.0)};

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
				float4 color 			: COLOR; // Vertex color param. Must be in struct, must be called color
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
				float2 texCoord1		: TEXCOORD8;
				float4 vColor : TEXCOORD9;
			};

			vertex2frag vert(app2vertex In)
			{
				amplitude *= 0.25;
				waveLength *= 0.25;
				vertex2frag Out = (vertex2frag)0;

				float3 sumW = float3(0,0,0);
				float3 sumB = float3(0,0,0);
				float3 sumT = float3(0,0,0);
				float3 sumN = float3(0,0,0);
				float2 dirsXY = float2(dirX, dirY);
				//sumW = gerstnerWave(In.position, 	1, dirsXY, amplitude, waveLength, crestFactor, speed, _Time.y, 0);
				float4 vColor = In.color;
				Out.vColor = vColor;
				float4 red = float4(1,0,0,1);
				amplitude *= 1 - vColor.x; // 


				for(int i=0; i < 3; i++)
				{
					//float2 dirsVal = dirsArray[i]*dirsXY;
					float2 dirsVal = dirsArray[i]*dirsXY;
					float mulVal = mulArray[i]*2-1;//* customNoise(dirsVal);
					//amplitude *= 0.25;
					sumW += gerstnerWave(In.position, 		mulArray[i], dirsArray[i], amplitude, waveLength, crestFactor, speed, _Time.y, 0, waveArray[i], ampArray[i]);
					sumB += gerstnerWave(sumW, 				mulArray[i], dirsArray[i], amplitude, waveLength, crestFactor, speed, _Time.y, 1, waveArray[i], ampArray[i]);
					sumT += gerstnerWave(sumW, 				mulArray[i], dirsArray[i], amplitude, waveLength, crestFactor, speed, _Time.y, 2, waveArray[i], ampArray[i]);
					sumN += gerstnerWave(sumW, 				mulArray[i], dirsArray[i], amplitude, waveLength, crestFactor, speed, _Time.y, 3, waveArray[i], ampArray[i]);
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
				//Out.worldNormal = normalize(mul(unity_WorldToObject, In.normal).xyz);
				Out.worldTangent = normalize(mul(unity_ObjectToWorld, In.tangent).xyz);
				Out.worldBinormal = normalize(cross(Out.worldNormal, Out.worldTangent*In.tangent.w)); // tangent.w is specific to Unity
				Out.worldBinormal += sumB;

				// Final output position & screenposition
				float4 worldSpacePos = mul(unity_ObjectToWorld, In.position);
				Out.posWorld = worldSpacePos;
				Out.position = mul(UNITY_MATRIX_MVP, In.position);
				Out.scrPos = ComputeScreenPos(Out.position);
				//Out.scrPos.y = 1 - Out.scrPos.y;

			    Out.texCoord0 = In.texCoord0;
			    Out.texCoord1 = In.texCoord0;
			    Out.texCoord0.y += _Time.y*timerScale1*0.05;
			    Out.texCoord1.yx += _Time.y*timerScale1*0.05;

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

			// TODO: Try running depth mask in vertex shader. You can change amplitude based on depth which could help with shore waves
			//static float2 texOffset[5] 	= {float2(0.65, 1.0), float2(1.43, 0.5), float2(0.25, 1.0), float2(1.75, 0.25), float2(1.25, 1.0)};
			static float texOffset[5] 	= {1.15, 0.1, 0.25, 0.5, 0.75};
	        fixed4 frag (vertex2frag In) : SV_Target
	        {
    			if (_Environ == 0)
    			{
					deepColor 		= color_to_float(float4(14, 80, 120, 255));
					shallowColor 	= color_to_float(float4(0, 180, 208, 175));
				}
				else if (_Environ == 1)
				{
					deepColor 		= color_to_float(float4(0, 60, 111, 255));
					shallowColor 	= color_to_float(float4(60, 50, 0, 175));
				}

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
	            float4 normal 		= tex2D(normalMap, normalMap_ST.xy * In.texCoord0 + normalMap_ST.zw)*2-1;
	            float4 normal2 		= tex2D(normalMap2, normalMap2_ST.xy * In.texCoord1 + normalMap2_ST.zw)*2-1;
	            normal = normal+normal2;
	            float3 bumpWorld 	= normalize(mul(normal,toWorld));

	            float4 foamTex 		= tex2D(foamMap, foamMap_ST.xy * In.texCoord0 + foamMap_ST.zw);
	            float4 foamMaskTex 	= tex2D(foamMask, foamMask_ST.xy * In.texCoord0 + foamMask_ST.zw);
	            float4 refrMap 		= tex2D(refractionMap, refractionMap_ST.xy * In.texCoord0 + refractionMap_ST.zw)*2-1;
	
	            // Foam scrolling & adding up masking
	            for(int j=0; j<5; j++)
				{
		           	float offset = sin(texOffset[j]*dirX);
		           	offset *= cos(texOffset[j]*dirX);
		           	float2 xyTile = foamMask_ST.xy*texOffset[j];
		           	float2 zwTile = foamMask_ST.zw*texOffset[j];
		           	foamMaskTex += tex2D(foamMask, xyTile * (In.texCoord0+offset)*2-1 + zwTile);
				}


	           	////////// Refraction testing /////////////
            	float distortion = 100.0; // warping just enough to not look blurry
            	float3 refracted = refrMap * abs(refrMap);
	            float4 projA = In.uvRefr;
	            //return projA;
            	refracted.xy *= _RefractPassTex_TexelSize.xy*5;
            	projA.xy = refracted.xy * distortion + In.uvRefr.xy;
            	float4 underWaterRefr = tex2Dproj( _RefractPassTex, projA);
            	shallowColor += underWaterRefr;

            	// Depth calculations
            	float4 depthTex = tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(In.scrPos));
				float sceneZ = LinearEyeDepth (depthTex.r);
				float objectZ = In.scrPos.z;
				//float objectZ = projA.z;
				float waterDepthFactor 		= saturate((sceneZ - projA.z)/_WaterDepth);
				float depthFadeFactor 		= 1 - saturate(_DepthFade - (sceneZ - objectZ));
				float foamFadeFactor 		= 1 - saturate(_FoamFade - (sceneZ - objectZ));
				float foamDepthFadeFactor 	= 1 - saturate(_FoamDepthFade - (sceneZ - objectZ));

				float4 heightMask = generateHeightMask(In.posWorld);

            	float3 V = In.viewVec;
				float3 R = reflect(V, bumpWorld*abs(bumpWorld)); //bumpWorld calculation gives nice clear yet watery reflection
				float3 refraction = refract(V, bumpWorld*abs(bumpWorld), 1.3333);
			    float4 reflectedColor = texCUBE(cubeMap, -R);
    			float4 refractedColor = texCUBE(cubeMap, refraction);

    			// Specular stuff
				float3 reflection = reflect(bumpWorld, -light0Dir);
				float4 specular = dot(normalize(reflection), normalize(V));
				specular = pow(specular, 256);
				specular *= specIntensity * _LightColor0;

				float4 color = deepColor;
				float diffLight = attenuation * _LightColor0 * max(0.5, dot(normalize(normal), normalize(light0Dir)));

				// Initial color calculation
				float reflectionCoefficient = fresnelCalculation(V, In.worldNormal);
    			//float reflectionCoefficient = Fresnel(V, In.worldNormal);
				float4 final = lerp(color, float4(reflectedColor.xyz, 1), reflectionCoefficient);
				final *= abs(final);
				//return final;
				final.a *= waterDepthFactor;
				float4 resultColor = final+color;
				//resultColor.xyz *= diffLight;
				resultColor.a 	*= waterDepthFactor;
				resultColor += specular;

				float fm 		= clamp(pow(foamTex, 1),0,1);
				float4 topFoam = foamTex;
				topFoam.a *= waterDepthFactor;
				resultColor = lerp(resultColor, topFoam*_FoamStrength, heightMask);

				// changing alpha after master foam is added to sea
				float4 shoreFoamTex = foamTex;
				shoreFoamTex.a *= foamDepthFadeFactor;
				shoreFoamTex.a *= foamMaskTex*0.25;
				shoreFoamTex*=_ShoreFoamStrength;

				float depthColorSwitch = 4;
				//shallowColor.a *= depthFadeFactor;
				float4 water = lerp(shallowColor, resultColor, pow(waterDepthFactor, 1.0/_DepthColorSwitch)); // Switching between surface & depth colors
				water = lerp(shoreFoamTex, water, foamFadeFactor);
				water.xyz *= diffLight;
				return water;

				float4 refrWater = lerp(underWaterRefr, water, pow(waterDepthFactor, foamFadeFactor)); // THIS LINE IS VERY VERY CLOSE NEED TO GET THE VALUES & SLIDERS CORRECT
				return refrWater;
	        }
			ENDCG
		}
	}
	FallBack "Diffuse"
}
