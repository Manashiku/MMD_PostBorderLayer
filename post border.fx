#define BLUR_SAMPLE 15

#define CONTROLLER "controller.pmx"
float x_pos_add : CONTROLOBJECT < string name = CONTROLLER; string item = "x pos +";>;
float y_pos_add : CONTROLOBJECT < string name = CONTROLLER; string item = "y pos +";>;
float x_pos_sub : CONTROLOBJECT < string name = CONTROLLER; string item = "x pos -";>;
float y_pos_sub : CONTROLOBJECT < string name = CONTROLLER; string item = "y pos -";>;

float x_width : CONTROLOBJECT < string name = CONTROLLER; string item = "x width";>;
float y_width : CONTROLOBJECT < string name = CONTROLLER; string item = "y width";>;
float c_width : CONTROLOBJECT < string name = CONTROLLER; string item = "circle width";>;
float shape_circular : CONTROLOBJECT < string name = CONTROLLER; string item = "shape=circle";>;
float x_soft : CONTROLOBJECT < string name = CONTROLLER; string item = "x soft";>;
float y_soft : CONTROLOBJECT < string name = CONTROLLER; string item = "y soft";>;
float c_soft : CONTROLOBJECT < string name = CONTROLLER; string item = "circle soft";>;

float border_step : CONTROLOBJECT < string name = CONTROLLER; string item = "border step";>;

float color_r : CONTROLOBJECT < string name = CONTROLLER; string item = "color r";>;
float color_g : CONTROLOBJECT < string name = CONTROLLER; string item = "color g";>;
float color_b : CONTROLOBJECT < string name = CONTROLLER; string item = "color b";>;
float color_a : CONTROLOBJECT < string name = CONTROLLER; string item = "color a";>;

float mul_blend : CONTROLOBJECT < string name = CONTROLLER; string item = "mul_blend";>;
float add_blend : CONTROLOBJECT < string name = CONTROLLER; string item = "add blend";>;
float sub_blend : CONTROLOBJECT < string name = CONTROLLER; string item = "sub blend";>;

float in_front   : CONTROLOBJECT < string name = CONTROLLER; string item = "layering on";>;
float screenblur : CONTROLOBJECT < string name = CONTROLLER; string item = "screenblur border";>;
float screen_zoom : CONTROLOBJECT < string name = CONTROLLER; string item = "blur zoom";>;


float script : STANDARDSGLOBAL < 
    string ScriptOutput = "color"; 
    string ScriptClass = "scene"; 
    string ScriptOrder = "postprocess"; 
> = 0.8;

float2 screen_size : VIEWPORTPIXELSIZE; 
static float2 screen_offset = ((float2)0.5f / screen_size);
float4 clear_color = {1.0f, 1.0f, 1.0f, 0.0f};
float clear_depth = 1.0;

static float pi = 3.1415926;
static int samples = BLUR_SAMPLE;
static float sigma = (float)samples * 0.25;
static float s = 2 * sigma * sigma; 

// ==========================================================
// TEXTURES 
texture2D screen_texture : RENDERCOLORTARGET < float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 0;
>;
texture2D depthstencil_texture : RENDERDEPTHSTENCILTARGET <
    // float2 ViewPortRatio = {1.0, 1.0};
    // string Format = "D3DFMT_D24S8";
>;

texture2D depth_texture : OFFSCREENRENDERTARGET
<
    string Description = "camera depth texture";
    float4 ClearColor = {10.0f, 10.0f, 10.0f, 1.0f};
    float ClearDepth = 1.0f;
  	bool AntiAlias = true;
	string Format = "R32F";
    string DefaultEffect = "*=depth_render_bg.fx;"
    "controller.pmx=hide;";
>;

// ==========================================================
// SAMPLERS
sampler screen_sampler = sampler_state
{
    texture = <screen_texture>;
    FILTER = ANISOTROPIC;
    ADDRESSV = CLAMP;
    ADDRESSU = CLAMP;
};

sampler gauss_sampler = sampler_state
{
    texture = <screen_texture>;
    FILTER = ANISOTROPIC;
    ADDRESSV = CLAMP;
    ADDRESSU = CLAMP;
};

sampler2D depth_sampler = sampler_state
{
	texture = <depth_texture>;
	MinFilter = NONE;
	MagFilter = NONE;
	MipFilter = NONE;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

// ==========================================================
// gaussian blur
float gauss(float2 i)
{
    
    return exp(-(i.x * i.x + i.y * i.y) / s) / (pi * s);
}

float3 gaussianBlur(sampler sp, float2 uv, float2 scale)
{
    float3 pixel = (float3)0.0f;
    float weightSum = 0.0f;
    float weight;
    float2 offset;

    for(int i = -samples / 2; i < samples / 2; i++)
    {
        for(int j = -samples / 2; j < samples / 2; j++)
        {
            offset = float2(i, j);
            weight = gauss(offset);
            pixel += tex2Dlod(sp, float4(uv + scale * offset, 0.0f, 1.0f)).rgb * weight;
            weightSum += weight;
        }
    }
    return pixel / weightSum;
}


// ==========================================================
// STRUCTURE  
struct vs_out
{
    float4 pos : POSITION;
    float2 uv : TEXCOORD0;
};

// ==========================================================
// VERTEX AND PIXEL SHADER
vs_out vs_0(float4 pos : POSITION, float2 uv : TEXCOORD0)
{
    vs_out o;
    o.pos = pos;
    // half pixel offset to fix a centering issue
    o.uv = uv + screen_offset;
    return o;
}

float4 ps_0(vs_out i) : COLOR
{
    // initialize inputs
    float4 color  = (float4)1.0f;
    float2 uv     = i.uv;

    float2 screen_blur_uv = (uv - (float2)0.5f) * (1.0f + screen_zoom) + (float2)0.5f;

    // sample textures
    float depth   = 1.0f - tex2D(depth_sampler, uv).x;
    float4 screen = tex2D(screen_sampler, uv);
    float3 screen_zoom = tex2D(screen_sampler, screen_blur_uv);
    screen_zoom = gaussianBlur(gauss_sampler, screen_blur_uv, (float2)1.0f / screen_size.xy);

    // get gaussian blurred image

    // depth step for a harsh transition
    // this will keep the foreground objects from appearing half blended into the border
    float depth_step = step(0.5f, depth);

    // move screen into color component
    color.xyz = screen.xyz;
    
    // create the x and y offset values using the pmx sliders
    float2 border_offset = float2(x_pos_add - x_pos_sub, y_pos_add - y_pos_sub);

    // create the border mask using the distance from the center to the edge of the uvs 
    float ud_border = distance(0.5f + border_offset.y, uv.y);
    float lr_border = distance(0.5f + border_offset.x, uv.x);
    float c_border = distance((float2)0.5f + border_offset, uv.xy);

    // adjust the width and softness using a smoothstep function
    ud_border = smoothstep(y_soft+0.001, 0.0f, saturate(ud_border - (y_width)));
    lr_border = smoothstep(x_soft+0.001, 0.0f, saturate(lr_border - (x_width)));
    c_border = smoothstep(c_soft+0.001, 0.0f, saturate(c_border - (c_width)));
    
    float box_border = ud_border * lr_border;
    float circle_border = c_border;

    // toggle between the circular shape and the box
    float border = (shape_circular) ?  circle_border : box_border;
    border = (border_step > 0.0f) ? step(border_step, border) : border; // if border step is greater than 0.0 then treat it as on

    // put together the border color from the sliders
    float4 border_color = float4(color_r, color_g, color_b, color_a);
    // if the screen blur as border slider is pushed to 1, set border_color to the screenblur texture
    float3 border_behind = (screenblur) ? screen_zoom : screen.xyz;

    // create s input for lerp function using the border and the border color transparency value
    float border_blend = saturate(1.0f - (border + (1.0f - border_color.a)));

    // initialize the various blending kinds
    float3 border_lerp = lerp(color.xyz, border_color.xyz, border_blend);
    float3 border_mul  = lerp(color.xyz, border_behind.xyz * border_color.xyz, border_blend);
    float3 border_add  = lerp(color.xyz,  border_behind.xyz + border_color.xyz, border_blend);
    float3 border_sub  = lerp(color.xyz, border_behind.xyz - border_color.xyz, border_blend);

    // create the final output borderered image and toggle on or off the various blending modes
    float3 border_out = border_lerp;
    border_out = (mul_blend) ? border_mul : border_out;
    border_out = (sub_blend) ? border_sub : border_out;
    border_out = (add_blend) ? border_add : border_out;
    
    // initialize the output color
    float4 out_color = color;

    // now finally lerp between the foreground object and the backtround using either the scene depth or a mask.
    // and check if the in_front variable is in use
    out_color.xyz = (in_front) ? lerp(border_out, out_color.xyz, depth_step) : border_out;
    return out_color;
}

technique post_test <
   string Script =
        "RenderColorTarget0=screen_texture;"
		"RenderDepthStencilTarget=depthstencil_texture;"
		"ClearSetColor=clear_color;"
		"ClearSetDepth=clear_depth;"
		"Clear=Color;"
		"Clear=Depth;"
		"ScriptExternal=Color;"
    
        //final pass
        "RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"ClearSetColor=clear_color;"
		"ClearSetDepth=clear_depth;"
		"Clear=Color;"
		"Clear=Depth;"
		"Pass=drawFinal;"
    ;
>
{
    pass drawFinal <string Script = "RenderColorTarget0=;"
    "RenderDepthStencilTarget=;""Draw=Buffer;";>
    {
       
        VertexShader = compile vs_3_0 vs_0();
        ZEnable = false;
		ZWriteEnable = false;
		AlphaBlendEnable = true;
		CullMode = None;
        PixelShader = compile ps_3_0 ps_0();
    }
}
