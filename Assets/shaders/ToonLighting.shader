// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/ToonLighting"
{
    Properties
    {
        [Header(Base Parameters)]
        _Color ("Tint", Color) = (0,0,0,1)
        _MainTex ("Texture", 2D) = "white" {}
        _Specular ("Specular Color", Color) = (1,1,1,1)
        [HDR] _Emission("Emission", color) = (0,0,0)

        [Header(Lighting Parameters)]
        _ShadowTint("Shadow Color", Color) = (0.5,0.5,0.5,1)
        [IntRange]_StepAmount("Shadow Steps", Range(1,16)) = 2
        _StepWidth("Step Size", Range(0.05, 1))=0.25
        _SpecularSize ("Specular Size", Range(0, 1)) = 0.1
        _SpecularFalloff ("Specular Falloff", Range(0, 2)) = 1

        [Header(Outline Parameters)]
        _OutlineColor ("Outline Color", Color) = (0,0,0,1)
        _NormalMult ("Normal Outline Multiplier", Range(0,4)) = 1
        _NormalBias ("Normal Outline Bias", Range(1,4)) = 1
        _DepthMult ("Depth Outline Multiplier", Range(0,4)) = 1
        _DepthBias ("Depth Outline Bias", Range(1,4)) = 1
    }

    SubShader
    {

        Tags {"RenderType"="Transparent" "Queue"="Transparent+0"}

        Pass{
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"


            //the rendered screen so far
            sampler2D _MainTex;
            //the depth normals texture
            sampler2D _CameraDepthNormalsTexture;
            //texelsize of the depthnormals texture
            float4 _CameraDepthNormalsTexture_TexelSize;

            //variables for customising the effect
            float4 _OutlineColor;
            float _NormalMult;
            float _NormalBias;
            float _DepthMult;
            float _DepthBias;

            //the object data that's put into the vertex shader
            struct appdata{
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            //the data that's used to generate fragments and can be read by the fragment shader
            struct v2f{
                float4 position : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            //the vertex shader
            v2f vert(appdata v){
                v2f o;
                //convert the vertex positions from object space to clip space so they can be rendered
                o.position = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            void Compare(inout float depthOutline, inout float normalOutline, 
                    float baseDepth, float3 baseNormal, float2 uv, float2 offset){
                //read neighbor pixel
                float4 neighborDepthnormal = tex2D(_CameraDepthNormalsTexture, 
                        uv + _CameraDepthNormalsTexture_TexelSize.xy * offset);
                float3 neighborNormal;
                float neighborDepth;
                DecodeDepthNormal(neighborDepthnormal, neighborDepth, neighborNormal);
                neighborDepth = neighborDepth * _ProjectionParams.z;

                float depthDifference = baseDepth - neighborDepth;
                depthOutline = depthOutline + depthDifference;

                float3 normalDifference = baseNormal - neighborNormal;
                normalDifference = normalDifference.r + normalDifference.g + normalDifference.b;
                normalOutline = normalOutline + normalDifference;
            }

            //the fragment shader
            fixed4 frag(v2f i) : SV_TARGET{
                //read depthnormal
                float4 depthnormal = tex2D(_CameraDepthNormalsTexture, i.uv);

                //decode depthnormal
                float3 normal;
                float depth;
                DecodeDepthNormal(depthnormal, depth, normal);

                //get depth as distance from camera in units 
                depth = depth * _ProjectionParams.z;

                float depthDifference = 0;
                float normalDifference = 0;

                Compare(depthDifference, normalDifference, depth, normal, i.uv, float2(1, 0));
                Compare(depthDifference, normalDifference, depth, normal, i.uv, float2(0, 1));
                Compare(depthDifference, normalDifference, depth, normal, i.uv, float2(0, -1));
                Compare(depthDifference, normalDifference, depth, normal, i.uv, float2(-1, 0));

                depthDifference = depthDifference * _DepthMult;
                depthDifference = saturate(depthDifference);
                depthDifference = pow(depthDifference, _DepthBias);

                normalDifference = normalDifference * _NormalMult;
                normalDifference = saturate(normalDifference);
                normalDifference = pow(normalDifference, _NormalBias);

                float outline = normalDifference + depthDifference;
                float4 sourceColor = tex2D(_MainTex, i.uv);
                float4 color = lerp(sourceColor, _OutlineColor, outline);
                return color;
            }
            ENDCG
        }
        
        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Stepped fullforwardshadows

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        sampler2D _MainTex;
        fixed4 _Color;
        half3 _Emission;
        fixed4 _Specular;

        float3 _ShadowTint;
        float _StepWidth;
        float _StepAmount;
        float _SpecularSize;
        float _SpecularFalloff;

        struct ToonSurfaceOutput{
            fixed3 Albedo;
            half3 Emission;
            fixed3 Specular;
            fixed Alpha;
            fixed3 Normal;
        };

        //our lighting function. Will be called once per light
        float4 LightingStepped(ToonSurfaceOutput s, float3 lightDir, half3 viewDir, float shadowAttenuation){
            //how much does the normal point towards the light?
            float towardsLight = dot(s.Normal, lightDir);

            //stretch values so each whole value is one step
            towardsLight = towardsLight / _StepWidth;
            //make steps harder
            float lightIntensity = floor(towardsLight);

            // calculate smoothing in first pixels of the steps and add smoothing to step, raising it by one step
            // (that's fine because we used floor previously and we want everything to be the value above the floor value, 
            // for example 0 to 1 should be 1, 1 to 2 should be 2 etc...)
            float change = fwidth(towardsLight);
            float smoothing = smoothstep(0, change, frac(towardsLight));
            lightIntensity = lightIntensity + smoothing;

            // bring the light intensity back into a range where we can use it for color
            // and clamp it so it doesn't do weird stuff below 0 / above one
            lightIntensity = lightIntensity / _StepAmount;
            lightIntensity = saturate(lightIntensity);

        #ifdef USING_DIRECTIONAL_LIGHT
            //for directional lights, get a hard vut in the middle of the shadow attenuation
            float attenuationChange = fwidth(shadowAttenuation) * 0.5;
            float shadow = smoothstep(0.5 - attenuationChange, 0.5 + attenuationChange, shadowAttenuation);
        #else
            //for other light types (point, spot), put the cutoff near black, so the falloff doesn't affect the range
            float attenuationChange = fwidth(shadowAttenuation);
            float shadow = smoothstep(0, attenuationChange, shadowAttenuation);
        #endif
            lightIntensity = lightIntensity * shadow;

            //calculate how much the surface points points towards the reflection direction
            float3 reflectionDirection = reflect(lightDir, s.Normal);
            float towardsReflection = dot(viewDir, -reflectionDirection);

            //make specular highlight all off towards outside of model
            float specularFalloff = dot(viewDir, s.Normal);
            specularFalloff = pow(specularFalloff, _SpecularFalloff);
            towardsReflection = towardsReflection * specularFalloff;

            //make specular intensity with a hard corner
            float specularChange = fwidth(towardsReflection);
            float specularIntensity = smoothstep(1 - _SpecularSize, 1 - _SpecularSize + specularChange, towardsReflection);
            //factor inshadows
            specularIntensity = specularIntensity * shadow;

            float4 color;
            //calculate final color
            color.rgb = s.Albedo * lightIntensity * _LightColor0.rgb;
            color.rgb = lerp(color.rgb, s.Specular * _LightColor0.rgb, saturate(specularIntensity));

            color.a = s.Alpha;
            return color;
        }

        struct Input
        {
            float2 uv_MainTex;
        };

        void surf (Input IN, inout ToonSurfaceOutput o)
        {
            // Albedo comes from a texture tinted by color
            fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
            o.Albedo = c.rgb;

            o.Specular = _Specular;

            float3 shadowColor = c.rgb * _ShadowTint;
            o.Emission = _Emission + shadowColor;
        }
        ENDCG
    }
    FallBack "Standard"
}
