#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

/// 頂点データの構造体を定義します。
typedef struct
{
    float2 Position;            // 頂点位置
    float2 TextureCoordinate;   // テクスチャ座標
} VertexAttribute;

/// 頂点データ以外の構造体を定義します。
typedef struct
{
    int2 ViewportSize;              // ビューポートサイズ
    // 本当はfloat3x3を使用したい
    // ・C#でMatrix3をバイト列に変換すると36byte
    // ・float3x3は48byte
    // 上記理由からメモリ配置が合わなくなってしまう
    // そこでpacked_float3を使用してC#のメモリ配置と合わせている
    // ちなみにfloat3も16byteのため使用できない
    packed_float3 ModelMatrixRow1;  // モデル行列 1行目
    packed_float3 ModelMatrixRow2;  // モデル行列 2行目
    packed_float3 ModelMatrixRow3;  // モデル行列 3行目
} Uniform;

/// 頂点シェーダの出力用(フラグメントシェーダ入力用)の構造体を定義します。
typedef struct {
    float4 position [[position]];   // クリップ空間の頂点座標
    
    float2 textureCoordinate;       // テクスチャ座標
} RasterizerData;

/// バッファ番号を定義します。
typedef enum Buffers
{
    VertexAttributeIndex = 0,   // 頂点データ
    UniformIndex                // ユニフォームデータ
} Buffers;

/// テクスチャ番号を定義します。
typedef enum Textures
{
    DisplayTextureIndex = 0     // 表示するテクスチャ
} Textures;

/// 頂点シェーダ関数
/// - Parameters:
///   - vertexID: 頂点ID
///   - vertices: 頂点データ
///   - uniform: ユニフォームデータ
///
/// - Returns: フラグメントシェーダへの出力
vertex RasterizerData sample_vertex(uint vertexID [[vertex_id]],
                                    constant VertexAttribute* vertices [[buffer(VertexAttributeIndex)]],
                                    constant Uniform& uniform [[buffer(UniformIndex)]])
{
    RasterizerData out;
    
    // 頂点データから頂点座標を取得
    float2 pixelSpacePosition = vertices[vertexID].Position;
    // モデル行列を作成
    float3x3 modelMatrix = float3x3(uniform.ModelMatrixRow1, uniform.ModelMatrixRow2, uniform.ModelMatrixRow3);
    // 平行移動・回転・スケールを適用するためにモデル行列をかける
    pixelSpacePosition = (modelMatrix * float3(pixelSpacePosition, 1.0)).xy;
    
    // float型にキャスト
    float2 viewportSize = float2(uniform.ViewportSize);

    // 頂点座標(ピクセル空間)をビューポートサイズの半分で割って、クリップ空間の座標に変換する
    out.position = float4(0.0, 0.0, 0.0, 1.0);
    out.position.xy = pixelSpacePosition / (viewportSize / 2.0);
    
    // テクスチャ座標を出力に設定
    out.textureCoordinate = vertices[vertexID].TextureCoordinate;
    
    return out;
}

/// フラグメントシェーダ関数
/// - Parameters:
///   - in: 頂点シェーダからの入力
///   - colorTexture: テクスチャ
///
/// - Returns: 色情報
fragment float4 sample_fragment(RasterizerData in [[stage_in]],
                                texture2d<float> colorTexture[[texture(DisplayTextureIndex)]])
{
    // サンプラー作成
    constexpr sampler textureSampler(mag_filter::linear,
                                     min_filter::linear);

    // テクスチャからサンプリング
    const float4 colorSample = colorTexture.sample(textureSampler, in.textureCoordinate);
    
    return colorSample;
}
