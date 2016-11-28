﻿// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

Shader "Custom/dx_11_ocean" {
	Properties {
		// Unity inputs for shader params
		waterColorA 	("waterColorA", Color) = (1,1,1,1)
		tile 			("Tile", float) = 1.0
		specIntensity 	("Spec Intensity", range(0, 10)) = 1.0
		timerScale1 	("Timer Scale 1", range(0, 1)) = 0.2
		amplitude 		("Amplitude", float) = 0.4
		waveLength 		("Wavelength", float) = 2.5
		speed 			("Speed", float) = 2.1
		crestFactor 	("Crest Factor", float) = 1.0
		fresBias 		("Fresnel Bias", float) = 0.0
		fresScale 		("Fresnel Scale", float) = 1.0
		fresPower 		("Fresnel Power", float) = 5.0

		diffMap 		("Diffuse Map", 2D) 	= "white" {}
		normalMap		("Normal Map", 2D) 		= "bump" {}
		foamMap			("Foam Map", 2D) 		= "white" {}
		noiseMap		("Noise Map", 2D) 		= "white" {}
		cubeMap			("Cube Map", CUBE) 		= "" {}
	}
	SubShader {
		Pass{
			Tags { "RenderType"="Opaque" }
			
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"
			//#include "Lighting.cginc"

			uniform sampler2D diffMap; 
			uniform sampler2D normalMap;
			uniform sampler2D foamMap;	
			uniform sampler2D noiseMap;
			uniform samplerCUBE cubeMap;

			uniform fixed4 waterColorA;
			uniform float tile;
			uniform float specIntensity;
			uniform float timerScale1;
			uniform float amplitude;
			uniform float waveLength;
			uniform float speed=2.1;
			uniform float crestFactor;
			uniform float fresBias;
			uniform float fresScale;
			uniform float fresPower;

			uniform float4 diffMap_ST;
			uniform float4 normalMap_ST;
			uniform float4 foamMap_ST;
			uniform float4 noiseMap_ST;

			// Unity Defined Variables;
			uniform float4 _LightColor0;

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
			};

			vertex2frag vert(app2vertex In)
			{ 
				vertex2frag Out = (vertex2frag)0;
				// _World2Object is Unity version of WorldInverseTranspose
				Out.worldNormal = normalize(mul(unity_WorldToObject, In.normal).xyz);
				//Out.worldTangent = mul(float4(In.tangent.xyz, 0.0), unity_WorldToObject ).xyz;
				Out.worldTangent = normalize(mul(unity_ObjectToWorld, In.tangent ).xyz);
				Out.worldBinormal = normalize(cross(Out.worldNormal, Out.worldTangent*In.tangent.w)); // tangent.w is specific to Unity

			    float4 worldSpacePos = mul(unity_ObjectToWorld, In.position);
    			Out.posWorld = worldSpacePos;
				Out.position = mul(UNITY_MATRIX_MVP, In.position);
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
				float4 finalFoam = float4(withFoam, 1);
				//return saturate(color * finalFoam + specular);
				return saturate(resultColor + specular);
	            //return saturate(diffuse);
	        }
			ENDCG
		}
	}
	FallBack "Diffuse"
}
