#version 300 es

#ifndef BYPASS_PIXEL_SHADER
	in mediump vec4 vcolor;
#endif

precision highp float;

uniform sampler2D TEXTURE_0;
uniform sampler2D TEXTURE_1;
uniform sampler2D TEXTURE_2;

#ifndef BYPASS_PIXEL_SHADER
	in vec3 perchunkpos;
	in vec3 worldpos;
	in vec2 uv0;
	in vec2 uv1;
#endif

#ifdef FOG
	in float fogalpha;
#endif

#ifndef BYPASS_PIXEL_SHADER
#include "util.cs.glsl"

void illummination(inout vec3 albedoot, in posvector posvec, in fmaterials materials)
{

	float lightmapbrightness = texture(TEXTURE_1, vec2(0, 1)).r;

	vec3 ambientcolor = toLinear(FOG_COLOR.rgb) * (0.5 + wrain * 2.0) * uv1.y;

	float adaptivebls = smoothstep(lightmapbrightness * uv1.y, 1.0, uv1.x);
	float blocklightsource;
		blocklightsource = mix(mix(blocklightsource, uv1.x, adaptivebls), uv1.x, wrain);

		ambientcolor += vec3(1.0, 0.5, 0.2) * blocklightsource + pow(blocklightsource * 1.15, 5.0);

	vec3 diffuselightcolor = (vec3(FOG_COLOR.r, FOG_COLOR.g * 0.9, FOG_COLOR.b * 0.8)  + vec3(0.05, 0.1, 0.15) * fnight) * pow(materials.normaldotlight, 0.5) * 3.0;
		ambientcolor += diffuselightcolor * materials.shadowm * (1.0 - wrain);

	albedoot = albedoot * ambientcolor + (saturate(materials.emissive) * posvec.albedolinear * 5.0);
}

void reflection(inout vec4 albedoot, in posvector posvec, in fmaterials materials)
{
	materials.miestrength = 1.5;
	posvec.nworldpos = reflect(posvec.nworldpos, posvec.normal);
	vec3 skyColorReflection = renderSkyColor(posvec, materials);
		skyColorReflection = mix(skyColorReflection, skyColorReflection * posvec.albedolinear, materials.metallic);

	vec3 f0 = vec3(0.04);
		f0 = mix(f0, albedoot.rgb, materials.metallic);
	vec3 viewFresnel = fresnelSchlick(f0, materials);

	albedoot.rgb = mix(albedoot.rgb, albedoot.rgb * vec3(0.03), materials.metallic);

	float reflectionplacement = max(max(materials.metallic, materials.surfacesmooth), wrain * posvec.normalv.y) * materials.shadowm;
	albedoot.rgb = mix(albedoot.rgb, skyColorReflection, viewFresnel * reflectionplacement);

	#ifdef BLEND
		albedoot.a *= max(vcolor.a, length(viewFresnel));
	#endif

	float normaldistribution = ditributionGGX(materials);
	float geometylight = geometrySchlick(materials);
	float attenuation = (1.0 - materials.roughness) * geometylight * normaldistribution;

	albedoot += attenuation * materials.normaldotlight * vec4(vec3(FOG_COLOR.r, FOG_COLOR.g * 0.9, FOG_COLOR.b * 0.8) * 2.0, 1.0) * materials.shadowm * (1.0 - wrain);
}
#endif

out vec4 fragcolor;
void main()
{

#ifdef BYPASS_PIXEL_SHADER
	discard;
#else

	vec2 topleftmcoord = fract(uv0 * 32.0) * (1.0 / 64.0);

	vec2 toprightmcoord = topleftmcoord - vec2(1.0 / 64.0, 0.0);
	vec4 mertexture = textureLod(TEXTURE_0, uv0 - toprightmcoord, 0.0);

	float getopaquesamplernomipmap = textureLod(TEXTURE_0, uv0 - topleftmcoord, 0.0).a;
	if( (mertexture.r > 0.0 ||
		mertexture.g > 0.0 ||
		mertexture.b > 0.0) && getopaquesamplernomipmap > 0.0
	){
		mertexture = mertexture;
	} else {
		mertexture = vec4(0, 0, 0, 0);
	}

	materials.metallic = saturate(mertexture.g);
	materials.emissive = saturate(mertexture.b);
 	materials.roughness = saturate(pow(1.0 - mertexture.r, 2.0));
	materials.surfacesmooth = saturate(1.0 - materials.roughness * 3.0);


	vec2 bottomleftmcoord = topleftmcoord - vec2(0.0, 1.0 / 64.0);
	vec4 normaltexture = textureGrad(TEXTURE_0, uv0 - bottomleftmcoord, dFdx(uv0 * textureDistanceLod), dFdy(uv0 * textureDistanceLod));

	if(normaltexture.r > 0.0 ||
		normaltexture.g > 0.0 ||
		normaltexture.b > 0.0
	){
		normaltexture = normaltexture;
	} else {
		normaltexture = vec4(vec3(0, 0, 1) * 0.5 + 0.5, 1);
	}
		normaltexture.rgb = normaltexture.rgb * 2.0 - 1.0;

	vec3 normalvector = normalize(cross(dFdx(perchunkpos.xyz), dFdy(perchunkpos.xyz)));

	posvec.normalv = normalvector;

	vec3 tangent = getTangentVector(posvec);
		tangent = normalize(tangent);
	vec3 binormal = normalize(cross(tangent, normalvector));

	mat3 tbnmatrix = mat3(tangent.x, binormal.x, normalvector.x,
		tangent.y, binormal.y, normalvector.y,
		tangent.z, binormal.z, normalvector.z);

		normaltexture.rg *= max0(1.5 - wrain * 1.0);

	vec3 normalmap = normaltexture.rgb;
		normalmap = normalize(normalmap * tbnmatrix);


	posvec.normal = normalmap;
	posvec.lightpos = normalize(vec3(cos(sunLightAngle), sin(sunLightAngle), 0.0));
	posvec.upposition = normalize(vec3(0.0, abs(worldpos.y), 0.0));
	posvec.nworldpos = normalize(worldpos);

	vec3 viewdirection = normalize(-worldpos);
	vec3 halfwaydir = normalize(viewdirection + posvec.lightpos);

	materials.normaldotlight = max0(dot(normalmap, posvec.lightpos));
	materials.normaldothalf = max(0.001, dot(normalmap, halfwaydir));
	materials.normaldotview = max(0.001, dot(normalmap, viewdirection));
	materials.shadowm = min(pow(uv1.y * 1.15, 128.0), 1.0);


	vec4 albedo = textureGrad(TEXTURE_0, uv0 - topleftmcoord, dFdx(uv0 * textureDistanceLod), dFdy(uv0 * textureDistanceLod));

	#ifdef SEASONS_FAR
		albedo.a = 1.0;
	#endif

	#ifdef ALPHA_TEST
		#ifdef ALPHA_TO_COVERAGE
			#define ALPHA_THRESHOLD 0.05
		#else
			#define ALPHA_THRESHOLD 0.5
		#endif
		if(albedo.a < ALPHA_THRESHOLD) discard;
	#endif

	#ifndef SEASONS
		#if !defined(ALPHA_TEST) && !defined(BLEND)
			albedo.a = vcolor.a;
		#endif

		vec3 normalizedvcolor = normalize(vcolor.rgb);
		if(normalizedvcolor.g > normalizedvcolor.b && vcolor.a == 1.0){
			albedo.rgb *= mix(normalizedvcolor, vcolor.rgb, 0.5);
		} else {
			albedo.rgb *= vcolor.a == 0.0 ? vcolor.rgb : sqrt(vcolor.rgb);
		}

	#else
		albedo.rgb *= mix(vec3(1.0,1.0,1.0), texture(TEXTURE_2, vcolor.rg).rgb * 2.0, vcolor.b);
		albedo.rgb *= vcolor.aaa;
		albedo.a = 1.0;
	#endif

		albedo.rgb = toLinear(albedo.rgb);

	posvec.albedolinear = albedo.rgb;

	illummination(albedo.rgb, posvec, materials);
	reflection(albedo, posvec, materials);

	materials.miestrength = 1.0;
	vec3 newfogcolor = renderSkyColor(posvec, materials);

	if(FOG_CONTROL.x > 0.5){
		albedo.rgb = mix(albedo.rgb, newfogcolor * vec3(0.4, 0.7, 1.0), max0(length(worldpos) / RENDER_DISTANCE) * 0.5);
	}
		albedo.rgb = mix(albedo.rgb, newfogcolor, max0(length(worldpos) / 100.0) * wrain);

	#ifdef FOG
		albedo.rgb = mix(albedo.rgb, newfogcolor, fogalpha);
	#endif

		albedo.rgb = tonemap(albedo.rgb);

	fragcolor = albedo;
#endif
}
