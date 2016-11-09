// Header file for dx11 HLSL

static const float PI = 3.1415926535897932384626433832795;

bool IsTextureAssigned( Texture2D tex )
{
	uint w, h;
	tex.GetDimensions( w, h );
	return w != 0;
}

bool IsTextureCubeAssigned( TextureCube tex )
{
	uint w, h;
	tex.GetDimensions( w, h );
	return w != 0;
}

float3 SampleTexture( Texture2D tex, SamplerState state, float2 uv )
{
	// dx11 style texture sampling
	return tex.Sample( state, uv );
}

float3 SampleTexture(Texture2D tex, SamplerState state, float2 uv, float3 returnColor)
{
	if( !IsTextureAssigned( tex ) )
		return returnColor;
	return tex.Sample( state, uv );
}

float4 SampleTexture( Texture2D tex, SamplerState state, float2 uv, float4 returnColor )
{
	// If Texture is not assigned return input color instead of dx11 default black
	if( !IsTextureAssigned( tex ) )
		return returnColor;
	return tex.Sample( state, uv );
}

float3 DecodeNormalTexture( float2 tex )
{
    float2 xy = tex.xy * 2 - 1;
    return float3( xy, sqrt ( max( 0, 1 - dot( xy, xy ) ) ) );
}

//------------------------------------
// Light parameters
//------------------------------------
// dx11 autmatically binds and accepts up to 3 lights in the Maya scene
cbuffer UpdateLights : register(b2)
{
	// ---------------------------------------------
	// Light 0 GROUP
	// ---------------------------------------------
	// This value is controlled by Maya to tell us if a light should be calculated
	// For example the artist may disable a light in the scene, or choose to see only the selected light
	// This flag allows Maya to tell our shader not to contribute this light into the lighting
	bool light0Enable : LIGHTENABLE
	<
		string Object = "Light 0";	// UI Group for lights, auto-closed
		string UIName = "Enable Light 0";
		int UIOrder = 1020;
	> = false;	// maya manages lights itself and defaults to no lights

	// follows LightParameterInfo::ELightType
	// spot = 2, point = 3, directional = 4, ambient = 5,
	int light0Type : LIGHTTYPE
	<
		string Object = "Light 0";
		string UIName = "Light 0 Type";
		string UIFieldNames ="None:Default:Spot:Point:Directional:Ambient";
		int UIOrder = 1021;
		float UIMin = 0;
		float UIMax = 5;
		float UIStep = 1;
	> = 2;	// default to spot so the cone angle etc work when "Use Shader Settings" option is used

	float3 light0Pos : POSITION 
	< 
		string Object = "Light 0";
		string UIName = "Light 0 Position"; 
		string Space = "World"; 
		int UIOrder = 1022;
	> = {100.0f, 100.0f, 100.0f}; 

	float3 light0Color : LIGHTCOLOR 
	<
		string Object = "Light 0";
		string UIName = "Light 0 Color"; 
		string UIWidget = "Color"; 
		int UIOrder = 1023;
	> = { 1.0f, 1.0f, 1.0f};

	float light0Intensity : LIGHTINTENSITY 
	<
		string Object = "Light 0";
		string UIName = "Light 0 Intensity"; 
		float UIMin = 0.0;
		float UIMax = 1000;
		float UIStep = 0.01;
		int UIOrder = 1024;
	> = { 1.0f };

	float3 light0Dir : DIRECTION 
	< 
		string Object = "Light 0";
		string UIName = "Light 0 Direction"; 
		string Space = "World"; 
		int UIOrder = 1025;
	> = {100.0f, 100.0f, 100.0f}; 

	float light0ConeAngle : HOTSPOT // In radians
	<
		string Object = "Light 0";
		string UIName = "Light 0 Cone Angle"; 
		float UIMin = 0;
		float UIMax = PI/2;
		int UIOrder = 1026;
	> = { 0.46f };

	float light0FallOff : FALLOFF // In radians. Sould be HIGHER then cone angle or lighted area will invert
	<
		string Object = "Light 0";
		string UIName = "Light 0 Penumbra Angle"; 
		float UIMin = 0;
		float UIMax = PI/2;
		int UIOrder = 1027;
	> = { 0.7f };

	float light0AttenScale : DECAYRATE
	<
		string Object = "Light 0";
		string UIName = "Light 0 Decay";
		float UIMin = 0.0;
		float UIMax = 1000;
		float UIStep = 0.01;
		int UIOrder = 1028;
	> = {0.0};

	bool light0ShadowOn : SHADOWFLAG
	<
		string Object = "Light 0";
		string UIName = "Light 0 Casts Shadow";
		string UIWidget = "None";
		int UIOrder = 1029;
	> = true;

	float4x4 light0Matrix : SHADOWMAPMATRIX		
	< 
		string Object = "Light 0";
		string UIWidget = "None"; 
		int UIOrder = 1129;
	>;



	// ---------------------------------------------
	// Light 1 GROUP
	// ---------------------------------------------
	bool light1Enable : LIGHTENABLE
	<
		string Object = "Light 1";
		string UIName = "Enable Light 1";
		int UIOrder = 1030;
	> = false;

	int light1Type : LIGHTTYPE
	<
		string Object = "Light 1";
		string UIName = "Light 1 Type";
		string UIFieldNames ="None:Default:Spot:Point:Directional:Ambient";
		float UIMin = 0;
		float UIMax = 5;
		int UIOrder = 1031;
	> = 2;

	float3 light1Pos : POSITION 
	< 
		string Object = "Light 1";
		string UIName = "Light 1 Position"; 
		string Space = "World"; 
		int UIOrder = 1032;
	> = {-100.0f, 100.0f, 100.0f}; 

	float3 light1Color : LIGHTCOLOR 
	<
		string Object = "Light 1";
		string UIName = "Light 1 Color"; 
		string UIWidget = "Color"; 
		int UIOrder = 1033;
	> = { 1.0f, 1.0f, 1.0f};

	float light1Intensity : LIGHTINTENSITY 
	<
		string Object = "Light 1";
		string UIName = "Light 1 Intensity"; 
		float UIMin = 0.0;
		float UIMax = 1000;
		float UIStep = 0.01;
		int UIOrder = 1034;
	> = { 1.0f };

	float3 light1Dir : DIRECTION 
	< 
		string Object = "Light 1";
		string UIName = "Light 1 Direction"; 
		string Space = "World"; 
		int UIOrder = 1035;
	> = {100.0f, 100.0f, 100.0f}; 

	float light1ConeAngle : HOTSPOT // In radians
	<
		string Object = "Light 1";
		string UIName = "Light 1 Cone Angle"; 
		float UIMin = 0;
		float UIMax = PI/2;
		int UIOrder = 1036;
	> = { 45.0f };

	float light1FallOff : FALLOFF // In radians. Sould be HIGHER then cone angle or lighted area will invert
	<
		string Object = "Light 1";
		string UIName = "Light 1 Penumbra Angle"; 
		float UIMin = 0;
		float UIMax = PI/2;
		int UIOrder = 1037;
	> = { 0.0f };

	float light1AttenScale : DECAYRATE
	<
		string Object = "Light 1";
		string UIName = "Light 1 Decay";
		float UIMin = 0.0;
		float UIMax = 1000;
		float UIStep = 0.01;
		int UIOrder = 1038;
	> = {0.0};

	bool light1ShadowOn : SHADOWFLAG
	<
		string Object = "Light 1";
		string UIName = "Light 1 Casts Shadow";
		string UIWidget = "None";
		int UIOrder = 1039;
	> = true;

	float4x4 light1Matrix : SHADOWMAPMATRIX		
	< 
		string Object = "Light 1";
		string UIWidget = "None"; 
		int UIOrder = 1139;
	>;



	// ---------------------------------------------
	// Light 2 GROUP
	// ---------------------------------------------
	bool light2Enable : LIGHTENABLE
	<
		string Object = "Light 2";
		string UIName = "Enable Light 2";
		int UIOrder = 1040;
	> = false;

	int light2Type : LIGHTTYPE
	<
		string Object = "Light 2";
		string UIName = "Light 2 Type";
		string UIFieldNames ="None:Default:Spot:Point:Directional:Ambient";
		float UIMin = 0;
		float UIMax = 5;
		int UIOrder = 1041;
	> = 2;

	float3 light2Pos : POSITION 
	< 
		string Object = "Light 2";
		string UIName = "Light 2 Position"; 
		string Space = "World"; 
		int UIOrder = 1042;
	> = {100.0f, 100.0f, -100.0f}; 

	float3 light2Color : LIGHTCOLOR 
	<
		string Object = "Light 2";
		string UIName = "Light 2 Color"; 
		string UIWidget = "Color"; 
		int UIOrder = 1043;
	> = { 1.0f, 1.0f, 1.0f};

	float light2Intensity : LIGHTINTENSITY 
	<
		string Object = "Light 2";
		string UIName = "Light 2 Intensity"; 
		float UIMin = 0.0;
		float UIMax = 1000;
		float UIStep = 0.01;
		int UIOrder = 1044;
	> = { 1.0f };

	float3 light2Dir : DIRECTION 
	< 
		string Object = "Light 2";
		string UIName = "Light 2 Direction"; 
		string Space = "World"; 
		int UIOrder = 1045;
	> = {100.0f, 100.0f, 100.0f}; 

	float light2ConeAngle : HOTSPOT // In radians
	<
		string Object = "Light 2";
		string UIName = "Light 2 Cone Angle"; 
		float UIMin = 0;
		float UIMax = PI/2;
		int UIOrder = 1046;
	> = { 45.0f };

	float light2FallOff : FALLOFF // In radians. Sould be HIGHER then cone angle or lighted area will invert
	<
		string Object = "Light 2";
		string UIName = "Light 2 Penumbra Angle"; 
		float UIMin = 0;
		float UIMax = PI/2;
		int UIOrder = 1047;
	> = { 0.0f };

	float light2AttenScale : DECAYRATE
	<
		string Object = "Light 2";
		string UIName = "Light 2 Decay";
		float UIMin = 0.0;
		float UIMax = 1000;
		float UIStep = 0.01;
		int UIOrder = 1048;
	> = {0.0};

	bool light2ShadowOn : SHADOWFLAG
	<
		string Object = "Light 2";
		string UIName = "Light 2 Casts Shadow";
		string UIWidget = "None";
		int UIOrder = 1049;
	> = true;

	float4x4 light2Matrix : SHADOWMAPMATRIX		
	< 
		string Object = "Light 2";
		string UIWidget = "None"; 
		int UIOrder = 1149;
	>;
} //end lights cbuffer

// Spot light cone
float LightConeangle(float coneAngle, float coneFalloff, float3 lightVec, float3 lightDir) 
{ 
	// the cone falloff should be equal or bigger then the coneAngle or the light inverts
	// this is added to make manually tweaking the spot settings easier.
	if (coneFalloff < coneAngle)
		coneFalloff = coneAngle;

	float LdotDir = dot(normalize(lightVec), lightDir); 

	// cheaper cone, no fall-off control would be:
	// float cone = pow(saturate(LdotDir), 1 / coneAngle); 

	// higher quality cone (more expensive):
	float cone = smoothstep( cos(coneFalloff), cos(coneAngle), LdotDir);

	return cone; 
}

// Calculate a light:
struct LightData
{
	float3 dir;
	float3 color;
	float3 lightVec;
};

LightData CalculateLight (	int lightType, float lightAtten, float3 lightPos, float3 vertWorldPos, 
							float3 lightColor, float lightIntensity, float3 lightDir, float lightConeAngle, float lightFallOff )
{
	// For Maya, flip the lightDir:
	lightDir = -lightDir;

	// directional light has no position, so we use lightDir instead
	bool isDirectionalLight = (lightType == 4);
	float3 lightVec = lerp(lightPos - vertWorldPos, lightDir, isDirectionalLight);

	float3 L = normalize(lightVec);	

	// Light Attenuation:
	float attenuation = 1.0f;
	if (!isDirectionalLight)	// directional lights do not support attenuation, skip calculation
	{
		bool enableAttenuation = lightAtten > 0.0001f;
		attenuation = lerp(1.0, 1 / pow(length(lightVec), lightAtten), enableAttenuation);
	}

	// Spot light Cone Angle:
	if (lightType == 2)
	{
		float angle = LightConeangle(lightConeAngle, lightFallOff, lightVec, lightDir);
		attenuation *= angle;
	}

	LightData ld;
	ld.dir = L;
	ld.color = lightColor * lightIntensity * attenuation;
	ld.lightVec = lightVec;
	return ld;
}

float3 ToLinear(float3 c)
{
    return pow(c,float3(2.2,2.2,2.2));
}