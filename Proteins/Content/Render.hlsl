#if 0
$ubershader	DRAW POINT|(LINE +HIGH_LINE)|SELECTION|SPARKS ABSOLUTE_POS|RELATIVE_POS
#endif

struct PARAMS {
	float4x4	View;
	float4x4	Projection;
	int			MaxParticles;
	int			SelectedParticle;
	float		edgeOpacity;
	float		nodeScale;
	float4		nodeColor;
	float4		edgeColor;
	float		numberofTextures;
};

cbuffer CB1 : register(b0) { 
	PARAMS Params; 
};


struct PARTICLE3D {
	float3	Position;
	float3	Velocity;
	float3	Force;
	float	Energy;
	float	Mass;
	float	Charge;

	float4	Color0;
	float	Size0;
	int		LinksPtr;
	int		LinksCount;
};


struct Spark {
	int		Start;
	int		End;
	float	Time;
	float	Parameter;
	float4	Color;
};


struct LinkId {
	int id;
};

struct Link {
	uint par1;
	uint par2;
	float length;
	float strength;
	float4 color;
};

SamplerState					Sampler				: 	register(s0);

Texture2D						Texture 			: 	register(t0);
Texture2D						SelectionTexture	:	register(t1);
StructuredBuffer<PARTICLE3D>	particleReadBuffer	:	register(t2);
StructuredBuffer<Link>			linksBuffer			:	register(t3);
StructuredBuffer<int>			SelectedNodeIndices	:	register(t4);
StructuredBuffer<int>			SelectedLinkIndices	:	register(t5);
StructuredBuffer<Spark>			SparkBuffer			:	register(t6);


#ifdef DRAW


struct VSOutput {
int vertexID : TEXCOORD0;
};

struct GSOutput {
	float4	Position : SV_Position;
	float2	TexCoord : TEXCOORD0;
	float4	Color    : COLOR0;
};



VSOutput VSMain( uint vertexID : SV_VertexID )
{
VSOutput output;
output.vertexID = vertexID;
return output;
}


float Ramp(float f_in, float f_out, float t) 
{
	float y = 1;
	t = saturate(t);
	
	float k_in	=	1 / f_in;
	float k_out	=	-1 / (1-f_out);
	float b_out =	-k_out;	
	
	if (t<f_in)  y = t * k_in;
	if (t>f_out) y = t * k_out + b_out;
	
	
	return y;
}


#ifdef POINT
[maxvertexcount(6)]
void GSMain( point VSOutput inputPoint[1], inout TriangleStream<GSOutput> outputStream )
{

	GSOutput p0, p1, p2, p3;
	int id = inputPoint[0].vertexID;

	PARTICLE3D prt = particleReadBuffer[ id ];
	PARTICLE3D referencePrt = particleReadBuffer[ Params.SelectedParticle ];

	float sz = prt.Size0 * Params.nodeScale;
	float4 color	=	prt.Color0;

// Draw with reference to a selected particle:
#ifdef RELATIVE_POS
	float4 pos		=	float4( prt.Position.xyz - referencePrt.Position.xyz, 1 );
#endif // RELATIVE_POS

// Draw without a reference:
#ifdef ABSOLUTE_POS
	float4 pos		=	float4( prt.Position.xyz, 1 );
#endif // ABSOLUTE_POS

	float texDist = 1.0f / (float) Params.numberofTextures;
	if(id > Params.numberofTextures) id = 1;

	float4 posV		=	mul( pos, Params.View );

	p0.Position = mul( posV + float4( -sz, -sz, 0, 0 ) , Params.Projection );		
	p0.TexCoord = float2(id*texDist, 1);
	p0.Color = color;

	p1.Position = mul( posV + float4(-sz, sz, 0, 0 ) , Params.Projection );
	p1.TexCoord = float2(id*texDist, 0);
	p1.Color = color;

	p2.Position = mul( posV + float4(sz,sz, 0, 0 ) , Params.Projection );
	p2.TexCoord = float2((id+1)*texDist, 0);
	p2.Color = color;

	p3.Position = mul( posV + float4( sz, -sz, 0, 0 ) , Params.Projection );
	p3.TexCoord = float2((id+1)*texDist, 1);
	p3.Color = color;

	outputStream.Append(p0);
	outputStream.Append(p1);
	outputStream.Append(p2);
	outputStream.RestartStrip();
	outputStream.Append(p0);
	outputStream.Append(p2);
	outputStream.Append(p3);
	outputStream.RestartStrip();

}

#endif // POINT



#ifdef SPARKS
[maxvertexcount(6)]
void GSMain( point VSOutput inputPoint[1], inout TriangleStream<GSOutput> outputStream )
{
	GSOutput p0, p1, p2, p3;
	Spark sp = SparkBuffer[inputPoint[0].vertexID];

	float4 startPos	= float4(particleReadBuffer[sp.Start].Position, 1);
	float4 endPos	= float4(particleReadBuffer[sp.End  ].Position, 1);
	float4 refPos	= float4(particleReadBuffer[ Params.SelectedParticle ].Position, 1);
	
	float4 pos = startPos + (endPos - startPos)*sp.Parameter;

	// Draw with reference to a selected particle:
#ifdef RELATIVE_POS
	pos -= refPos;
#endif // RELATIVE_POS

	float4 color	=	sp.Color;
	float sz		=	0.7f * Params.nodeScale;
	float4 posV		=	mul( pos, Params.View );

	p0.Position = mul( posV + float4( sz, sz, 0, 0 ) , Params.Projection );		
	p0.TexCoord = float2(1,1);
	p0.Color = color;

	p1.Position = mul( posV + float4(-sz, sz, 0, 0 ) , Params.Projection );
	p1.TexCoord = float2(0,1);
	p1.Color = color;

	p2.Position = mul( posV + float4(-sz,-sz, 0, 0 ) , Params.Projection );
	p2.TexCoord = float2(0,0);
	p2.Color = color;

	p3.Position = mul( posV + float4( sz,-sz, 0, 0 ) , Params.Projection );
	p3.TexCoord = float2(1,0);
	p3.Color = color;

	outputStream.Append(p0);
	outputStream.Append(p1);
	outputStream.Append(p2);
	outputStream.RestartStrip();
	outputStream.Append(p0);
	outputStream.Append(p2);
	outputStream.Append(p3);
	outputStream.RestartStrip();


}
#endif // SPARKS




#ifdef SELECTION

[maxvertexcount(8)]
void GSMain( point VSOutput inputPoint[1], inout TriangleStream<GSOutput> outputStream )
{
	GSOutput p0, p1, p2, p3;

	PARTICLE3D prt = particleReadBuffer[ SelectedNodeIndices[inputPoint[0].vertexID] ];
	PARTICLE3D referencePrt = particleReadBuffer[ Params.SelectedParticle ];

	float sz = prt.Size0*1.5f*Params.nodeScale;
//	float4 color	=	float4(0, 1, 0, 1);
	float4 color	=	Params.nodeColor;

// Draw with reference to a selected particle:
#ifdef RELATIVE_POS
	float4 pos		=	float4( prt.Position.xyz - referencePrt.Position.xyz, 1 );
#endif // RELATIVE_POS

// Draw without a reference:
#ifdef ABSOLUTE_POS
	float4 pos		=	float4( prt.Position.xyz, 1 );
#endif // ABSOLUTE_POS

	float4 posV		=	mul( pos, Params.View );

	p0.Position = mul( posV + float4( sz, sz, 0, 0 ) , Params.Projection );	
	p0.TexCoord = float2(1,1);
	p0.Color = color;

	p1.Position = mul( posV + float4(-sz, sz, 0, 0 ) , Params.Projection );
	p1.TexCoord = float2(0,1);
	p1.Color = color;

	p2.Position = mul( posV + float4(-sz,-sz, 0, 0 ) , Params.Projection );
	p2.TexCoord = float2(0,0);
	p2.Color = color;

	p3.Position = mul( posV + float4( sz,-sz, 0, 0 ) , Params.Projection );
	p3.TexCoord = float2(1,0);
	p3.Color = color;

	outputStream.Append(p0);
	outputStream.Append(p1);
	outputStream.Append(p2);
	outputStream.RestartStrip();
	outputStream.Append(p0);
	outputStream.Append(p2);
	outputStream.Append(p3);
	outputStream.RestartStrip();

}

#endif // SELECTION



// draw lines: ------------------------------------------------------------------------------------
#ifdef LINE
[maxvertexcount(40)]
void GSMain( point VSOutput inputLine[1], inout TriangleStream<GSOutput> outputStream )
{
	Link lk = linksBuffer[ inputLine[0].vertexID ];
	PARTICLE3D end1 = particleReadBuffer[ lk.par1 ];
	PARTICLE3D end2 = particleReadBuffer[ lk.par2 ];
	PARTICLE3D referencePrt = particleReadBuffer[ Params.SelectedParticle ];
	// Draw with reference to a selected particle:
			#ifdef RELATIVE_POS
				float4 pos1 = float4( end1.Position.xyz - referencePrt.Position.xyz, 1 );
				float4 pos2 = float4( end2.Position.xyz - referencePrt.Position.xyz, 1 );
			#endif // RELATIVE_POS

			// Draw without a reference:
			#ifdef ABSOLUTE_POS
				float4 pos1 = float4( end1.Position.xyz, 1 );
				float4 pos2 = float4( end2.Position.xyz, 1 );
			#endif // ABSOLUTE_POS

	if (Params.edgeOpacity > 1.0f){
	
			GSOutput p1, p2, p3, p4, p5, p6, p7, p8;
			
			float weight		=	Params.edgeOpacity / 2;
			
			pos1 = mul(pos1 , Params.View);
			pos2 = mul(pos2 , Params.View);

			float3 dir = normalize(pos2 - pos1);
			if (length(dir) == 0 ) return;

			float3 side = normalize(cross(dir, float3(0,0,-1)));

					


			p1.TexCoord		=	float2(0, 1);
			p2.TexCoord		=	float2(0, 0);
			p3.TexCoord		=	float2(0, 1);
			p4.TexCoord		=	float2(0, 0);

			p5.TexCoord		=	float2(1, 1);
			p6.TexCoord		=	float2(1, 0);
			p7.TexCoord		=	float2(1, 1);
			p8.TexCoord		=	float2(1, 0);
						
			p1.Color		=	lk.color;
			p2.Color		=	lk.color;
			p3.Color		=	lk.color;
			p4.Color		=	lk.color;
								   
			p5.Color		=	lk.color;
			p6.Color		=	lk.color;
			p7.Color		=	lk.color;
			p8.Color		=	lk.color;


			
			p1.Position = mul( pos1 + float4(side*weight, 0)  + float4(dir * end1.Size0 *  Params.nodeScale * 1.5f , 0), Params.Projection ) ;	
			p2.Position = mul( pos1 - float4(side*weight, 0)  + float4(dir * end1.Size0 *  Params.nodeScale * 1.5f , 0), Params.Projection ) ;	
			p3.Position = mul( pos2 + float4(side*weight, 0)  - float4(dir * end2.Size0 *  Params.nodeScale * 1.5f , 0), Params.Projection ) ;	
			p4.Position = mul( pos2 - float4(side*weight, 0)  - float4(dir * end2.Size0 *  Params.nodeScale * 1.5f , 0), Params.Projection ) ;	

			outputStream.Append(p1);
			outputStream.Append(p2);
			outputStream.Append(p3);
			outputStream.Append(p4);
			outputStream.RestartStrip();
		
	}
	else {
	
		GSOutput p1, p2;

		float4 posV1	=	mul( pos1, Params.View );
		float4 posV2	=	mul( pos2, Params.View );


		p1.Position		=	mul( posV1, Params.Projection );
		p2.Position		=	mul( posV2, Params.Projection );

		p1.TexCoord		=	float2(0, 0);
		p2.TexCoord		=	float2(0, 0);

		float opac		=	Params.edgeOpacity;

	// if line is highlighted, draw at full opacity:
	#ifdef HIGH_LINE
		opac			=	1.0f;
	#endif

		float4 color	=	mul(lk.color, opac);

		p1.Color		=	color;
		p2.Color		=	color;

		outputStream.Append(p1);
		outputStream.Append(p2);
		outputStream.RestartStrip(); 
	}

}

#endif // LINE
// ------------------------------------------------------------------------------------------------




//#ifdef HIGH_LINE
//[maxvertexcount(2)]
//void GSMain( point VSOutput inputLine[1], inout LineStream<GSOutput> outputStream )
//{
//	GSOutput p1, p2;
//
//	Link lk = linksBuffer[ SelectedLinkIndices[inputLine[0].vertexID] ];
//	PARTICLE3D end1 = particleReadBuffer[ lk.par1 ];
//	PARTICLE3D end2 = particleReadBuffer[ lk.par2 ];
//	PARTICLE3D referencePrt = particleReadBuffer[ Params.SelectedParticle ];
//
//// Draw with reference to a selected particle:
//#ifdef RELATIVE_POS
//	float4 pos1 = float4( end1.Position.xyz - referencePrt.Position.xyz, 1 );
//	float4 pos2 = float4( end2.Position.xyz - referencePrt.Position.xyz, 1 );
//#endif // RELATIVE_POS
//
//// Draw without a reference:
//#ifdef ABSOLUTE_POS
//	float4 pos1 = float4( end1.Position.xyz, 1 );
//	float4 pos2 = float4( end2.Position.xyz, 1 );
//#endif // ABSOLUTE_POS
//
//
//
//	float4 posV1	=	mul( pos1, Params.View );
//	float4 posV2	=	mul( pos2, Params.View );
//
//	p1.Position		=	mul( posV1, Params.Projection );
//	p2.Position		=	mul( posV2, Params.Projection );
//
//	p1.TexCoord		=	float2(0, 0);
//	p2.TexCoord		=	float2(0, 0);
//
//	p1.Color		=	Params.edgeColor;
//	p2.Color		=	Params.edgeColor;
//
//	outputStream.Append(p1);
//	outputStream.Append(p2);
//	outputStream.RestartStrip(); 
//
//}
//
//#endif // HIGH_LINE


#ifdef LINE
float4 PSMain( GSOutput input ) : SV_Target
{
	return float4(input.Color.rgb, 1.0f);
}
#endif // LINE



#if defined (POINT) || defined (SPARKS) || defined(SELECTION)
float4 PSMain( GSOutput input ) : SV_Target
{
	clip( Texture.Sample( Sampler, input.TexCoord ).a < 0.5f ? -1:1 );
	return Texture.Sample( Sampler, input.TexCoord ) * float4(input.Color.rgb,1);
}
#endif // POINT or SPARK or SELECTION


#endif //DRAW