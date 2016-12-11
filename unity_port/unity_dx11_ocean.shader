// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

Shader "Custom/dx_11_ocean" {
	Properties {
		// Unity inputs for shader params
		waterColorA 	("Surface Color", 	Color) 			= (1,1,1,1)
		waterColorB 	("Under Color", 	Color) 			= (1,1,1,1)
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
		diffMap 		("Diffuse Map", 2D) 		= "white" {}
		normalMap		("Normal Map", 	2D) 		= "bump" {}
		foamMap			("Foam Map", 	2D) 		= "white" {}
		foamMask		("Foam Mask", 	2D) 		= "white" {}
		noiseMap		("Noise Map", 	2D) 		= "white" {}
		cubeMap			("Cube Map", 	CUBE) 		= "" {}

		_FoamStrength ("Foam Strength", Range (0, 10)) = 1
		_ShoreFoamStrength ("Shore Foam Strength", Range (0, 10)) = 1
		_ShoreFoamOpacity ("Shore Foam Opacity", Range (0, 10)) = 1
		//_ShoreFoamTransparency ("Shore Foam Transparency", Range (0, 10)) = 1
		_WaterDepth ("Water Depth",	 Range (0, 5)) = 1
		_DepthFade ("Depth Fade", Range (0, 10)) = 0.5
		_FoamFade ("Foam Fade", Range (0, 10)) = 0.5
		_TranslucentStrength ("Overall Translucency", Range (0, 1)) = 1.0
		_DepthColorSwitch ("Depth Colour Switch", Range (0, 10)) = 1.0
		diffuseStrength ("Diffuse Strength", Range (0, 1)) = 1.0
	}
	SubShader {
		Tags { "RenderType" = "Transparent" "Queue" = "Transparent" }	
		//Blend SrcAlpha OneMinusSrcAlpha
		Pass{
			Blend SrcAlpha OneMinusSrcAlpha
			Tags { "RenderType" = "Transparent" "Queue" = "Transparent" }	
            //ZWrite Off
            //Cull Off
			//Tags { "RenderType"="Opaque" }			
					
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma fragmentoption ARB_precision_hint_fastest
			#include "UnityCG.cginc"
			#include "common.cginc"
			//#include "Lighting.cginc"

			uniform sampler2D diffMap;
			uniform sampler2D normalMap;
			uniform sampler2D foamMap;
			uniform sampler2D foamMask;
			uniform sampler2D noiseMap;
			uniform samplerCUBE cubeMap;

			uniform float4 waterColorA;
			uniform float4 waterColorB;
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
			float _FoamStrength;
			float _ShoreFoamStrength;
			float _ShoreFoamOpacity;
			//float _ShoreFoamTransparency;
			float _WaterDepth;
			float _DepthFade;
			float _FoamFade;
			float _TranslucentStrength;
			float _DepthColorSwitch;
			float diffuseStrength;

			uniform float4 diffMap_ST;
			uniform float4 normalMap_ST;
			uniform float4 foamMap_ST;
			uniform float4 foamMask_ST;
			uniform float4 noiseMap_ST;

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
				float2 texCoord1		: TEXCOORD1;
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

				Out.position = mul(UNITY_MATRIX_MVP, In.position);
				Out.scrPos=ComputeScreenPos(Out.position);
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
			    return Out;
			}

			//static float2 texOffset[5] 	= {float2(0.65, 1.0), float2(1.43, 0.5), float2(0.25, 1.0), float2(1.75, 0.25), float2(1.25, 1.0)};
			static float texOffset[5] 	= {1.15, 0.1, 0.25, 0.5, 0.75};
	        fixed4 frag (vertex2frag In) : SV_Target
	        {
	            float attenuation;
	            float3 light0Dir;
				if (0.0 == _WorldSpaceLightPos0.w) // directional light?
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

				float sceneZ = LinearEyeDepth (tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(In.scrPos)).r);
				float objectZ = In.scrPos.z;
				float intensityFactor = 1 - saturate((sceneZ - objectZ)/_WaterDepth);
				float depthFadeFactor = 1 - saturate(_DepthFade - (sceneZ - objectZ));
				float foamFadeFactor = 1 - saturate(_FoamFade - (sceneZ - objectZ));

				// Textures
	        	float3x3 toWorld 	= float3x3(In.worldTangent, In.worldBinormal, In.worldNormal);
	            float4 diffuse 		= tex2D(diffMap, diffMap_ST.xy * In.texCoord0 + diffMap_ST.zw);
	            float3 normal 		= tex2D(normalMap, normalMap_ST.xy * In.texCoord0+normalMap_ST.zw)*2-1;
	            float3 bumpWorld 	= normalize(mul(normal,toWorld));
	            float4 noiseM 		= tex2D(noiseMap, noiseMap_ST.xy * In.texCoord0 + noiseMap_ST.zw);
	            float4 foamTex 		= tex2D(foamMap, foamMap_ST.xy * In.texCoord0 + foamMap_ST.zw);
	            float4 foamMaskTex 	= tex2D(foamMask, foamMask_ST.xy * In.texCoord0 + foamMask_ST.zw);
	            
	            // TODO: Experiment with cos & sin to get rolling scroll
	            for(int i=0; i<5; i++)
				{
		           	//tc = sin(In.texCoord0);
		           	//float2 offset = sin(In.texCoord0 + texOffset[i] * float2(dirX, dirY));
		           	float offset = sin(texOffset[i]*dirX);
		           	offset *= cos(texOffset[i]*dirX);
		           	//float2 offset = sin(In.texCoord0 + texOffset[i]* float2(dirX, dirY));
		           	//offset += cos(In.texCoord0 + texOffset[i]* float2(dirX, dirY));
		           	float2 xyTile = foamMask_ST.xy*texOffset[i];
		           	float2 zwTile = foamMask_ST.zw*texOffset[i];
		           	foamMaskTex += tex2D(foamMask, xyTile * (In.texCoord0+offset)*2-1 + zwTile);
				}
	            //foamMaskTex += foamMaskTex*0.75;
	            //foamMaskTex += foamMaskTex*0.48;
	            //noiseM.a *= pow(foamMaskTex, depthFadeFactor);
	            //foamMaskTex += noiseM;

            	// Reflection Stuff
            	float3 V = In.viewVec;
				float3 R = reflect(V, bumpWorld);
				float3 refraction = refract(V, bumpWorld, 1.3333);
			    float4 reflectedColor = texCUBE(cubeMap, -R);
    			float4 refractedColor = texCUBE(cubeMap, -refraction);
    			//refractedColor = lerp(waterColorA, refractedColor, intensityFactor);
    			float reflectionCoefficient = fresBias + fresScale * pow(1.0 - dot(normalize(V), In.worldNormal), fresPower);

    			// Specular stuff
				float3 reflection = reflect(bumpWorld, -light0Dir);
				float4 specular = dot(normalize(reflection), normalize(V));
				specular = pow(specular, 256);
				specular *= specIntensity * _LightColor0;

				// Lighting & Color
				float4 color = waterColorA;
				color.xyz *= _LightColor0; // _LightColor0 comes premultiplied with intensity
				float diffLight = saturate(dot(bumpWorld, light0Dir));
				//color *= diffLight;
				//color += (diffuse*diffuseStrength);

				float3 cFinal = lerp(reflectedColor, refractedColor, reflectionCoefficient);
				float4 final = float4(cFinal, 1);
				float4 resultColor = lerp(color, final, reflectionCoefficient);

				// Surface Color
				float waterDepthFactor = saturate((sceneZ - objectZ)/_WaterDepth);
				float fm 		= clamp(pow(foamTex, 7),0,1);
				resultColor 	= saturate(lerp(resultColor, foamTex*_FoamStrength, fm) + specular);
				resultColor.a 	*= waterDepthFactor;

				foamTex.a *= foamMaskTex*_ShoreFoamOpacity;
				foamTex*=_ShoreFoamStrength;

				waterColorB.a *= depthFadeFactor;

				float4 water = lerp(waterColorB, resultColor, pow(waterDepthFactor, 1.0/_DepthColorSwitch)); // Switching between surface & depth colors
				water = lerp(foamTex, water, pow(waterDepthFactor, foamFadeFactor));
				return water;
	        }
			ENDCG
		}
	}
	FallBack "Diffuse"
}
