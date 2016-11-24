Shader "Custom/ocean" {
	Properties {
		// Unity inputs for shader params
		waterColorA 	("Color", Color) = (1,1,1,1)
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

		diffMap 		("Diffuse Map", 2D) 	= white {}
		normalMap		("Normal Map", 2D) 		= white {}
		foamMap			("Foam Map", 2D) 		= white {}
		noiseMap		("Noise Map", 2D) 		= white {}
		cubeTexture		("Cube Map", CUBE) 		= white {}
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		
		CGPROGRAM
		#pragma vertex vert
		#pragma fragment frag
		#include "UnityCG.cginc"

		sampler2D diffMap; 
		sampler2D normalMap;
		sampler2D foamMap;	
		sampler2D noiseMap;
		samplerCUBE cubeTexture;

		// input from application 
		struct app2vertex
		{ 
			float4 position			: POSITION;
			float2 texCoord0		: TEXCOORD0;
			float2 texCoord1		: TEXCOORD1;
			float3 tangent			: TANGENT;
			float3 binormal			: BINORMAL;
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
			float3 positionW		: TEXCOORD5;
			float3 heightW	 		: TEXCOORD6;
			float depth 			: TEXCOORD7;
		};

		vertex2frag vert(app2vertex In)
		{ 
			vertex2frag Out = (vertex2frag)0;
			Out.worldNormal = UnityObjectToWorldNormal(In.normal);
			Out.worldBinormal = mul(In.binormal, WorldInverseTranspose).xyz;
			Out.worldTangent = mul(In.tangent, WorldInverseTranspose).xyz;
			Out.position = mul(UNITY_MATRIX_MVP, In.position);

		    //float3 worldSpacePos = mul(In.position, World);
		    //Out.positionW = worldSpacePos;
		    Out.texCoord0 = In.texCoord0;
		   	//Out.texCoord0.xy -= (globalTimer*timerScale1);
		    //Out.cubeCoord = In.texCoord1;
			// From Unity built in function: _WorldSpaceCameraPos.xyz - mul(_Object2World, v).xyz;
			Out.viewVec = WorldSpaceViewDir(In.position);
		    return Out; 
		}

		ENDCG
	}
	FallBack "Diffuse"
}
