// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

Shader "Custom/dx_11_ocean" {
	Properties {
		// Unity inputs for shader params
		waterColorA 	("waterColorA", 	Color) 			= (1,1,1,1)
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
		noiseMap		("Noise Map", 	2D) 		= "white" {}
		cubeMap			("Cube Map", 	CUBE) 		= "" {}

		_FoamStrength ("Water Depth", Range (0, 10)) = 1
		_DepthFade ("Depth Fade", Range (0, 10)) = 1
	}
	SubShader {
		Pass{
			Blend SrcAlpha OneMinusSrcAlpha
            //ZWrite Off
            //Cull Off
			//Tags { "RenderType"="Opaque" }			
			Tags { "RenderType" = "Transparent" "Queue" = "Transparent" }			
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
			uniform sampler2D noiseMap;
			uniform samplerCUBE cubeMap;

			uniform float4 waterColorA;
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
			float _DepthFade;

			uniform float4 diffMap_ST;
			uniform float4 normalMap_ST;
			uniform float4 foamMap_ST;
			uniform float4 noiseMap_ST;

			// Static for the time being... Need to make them a bit more dynamic
			static float mulArray[3] 	= {0.561, 1.793, 0.697};
			static float2 dirsArray[3] 	= {float2(0.0, 1.0), float2(1.0, 0.5), float2(0.25, 1.0)};

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
				for(int i=0; i < 3; i++)
				{
					float2 dirsXY = float2(dirX, dirY);
					float2 dirsVal = dirsArray[i]*dirsXY;
					float mulVal = mulArray[i];//* customNoise(dirsVal);
					sumW += gerstnerWave(In.position.xyz, 	mulArray[i], dirsArray[i], amplitude, waveLength, crestFactor, speed, _Time.y, 0);
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

				// From Unity built in function: _WorldSpaceCameraPos.xyz - mul(_Object2World, v).xyz;
				Out.viewVec = WorldSpaceViewDir(In.position);
			    return Out;
			}

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

	        	float3x3 toWorld 	= float3x3(In.worldTangent, In.worldBinormal, In.worldNormal);
	            float4 diffuse 		= tex2D(diffMap, diffMap_ST.xy * In.texCoord0 + diffMap_ST.zw);
	            float3 normal 		= tex2D(normalMap, normalMap_ST.xy * In.texCoord0+normalMap_ST.zw)*2-1;
	            float3 bumpWorld 	= normalize(mul(normal,toWorld));
	            float3 noiseM 		= tex2D(noiseMap, noiseMap_ST.xy * In.texCoord0 + noiseMap_ST.zw);

            	float3 V = In.viewVec;
				float3 R = reflect(V, bumpWorld);
				float3 refraction = refract(V, bumpWorld, 1.3333);

			    float4 reflectedColor = texCUBE(cubeMap, -R);
    			float4 refractedColor = texCUBE(cubeMap, -refraction);
    			float reflectionCoefficient = fresBias + fresScale * pow(1.0 - dot(normalize(V), In.worldNormal), fresPower);

				//pow(max(0.0, dot(reflect(-lightDirection, normalDirection), viewDirection)), _Shininess);
				float3 reflection = reflect(bumpWorld, -light0Dir);
				//float3 reflection = reflect(light0Dir, bumpWorld);
				float4 specular = dot(normalize(reflection), normalize(V));
				specular = pow(specular, 256);
				specular *= specIntensity * _LightColor0;

				float4 color = waterColorA;
				float4 red = float4(255, 0, 0, 0);
				//color.xyz = lerp(diffuse.xyz, color, reflectionCoefficient);
				color.xyz *= _LightColor0; // _LightColor0 comes premultiplied with intensity
				float diffLight = saturate(dot(bumpWorld, light0Dir));
				color *= diffLight;
				color += diffuse;

				float3 cFinal = lerp(reflectedColor, refractedColor, reflectionCoefficient);
				float4 final = float4(cFinal, 1);
				//float4 resultColor = lerp(color, reflectedColor, reflectionCoefficient);
				float4 resultColor = lerp(color, final, reflectionCoefficient);

				float fm = clamp(pow(noiseM, 7),0,1);
				float3 white = float3(255, 255, 255);
				float3 withFoam = lerp(resultColor.xyz, white, fm);
				float4 finalFoam = float4(withFoam, 0);
				//return saturate(color * finalFoam + specular);

            	// .... accidentally got foam ontop of my wave peaks almost
            	// Experimented with the depth ranges, Turns out this has both of what I need in it.
            	// TODO: Get this working like the other script
            	float4 white2 = float4(255, 255, 255, 0);
				float sceneZ = LinearEyeDepth (tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(In.scrPos)).r);
				float objectZ = In.scrPos.z;
				float intensityFactor = 1 - saturate((sceneZ - objectZ)/_FoamStrength);
				float depthFadeFactor = 1 - saturate(_DepthFade - (sceneZ - objectZ));
				//diffuse.a   	*= intensityFactor;
				//white2.a        *= depthFadeFactor;
				finalFoam.a        *= depthFadeFactor;
				//return result;
				//return saturate(resultColor + specular);
				float4 res =  saturate(resultColor + specular);
				res.a *= depthFadeFactor;
				return res;
				return lerp(res, white2, intensityFactor);

	            //return saturate(diffuse);
	        }
			ENDCG
		}
	}
	FallBack "Diffuse"
}
