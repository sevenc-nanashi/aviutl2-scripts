Texture2D tex0 : register(t0);
SamplerState sampler0 : register(s0);
cbuffer cb0 : register(b0) {
  float currentTime;
  float horizontalBlur;
  float RGBeffect;
  float pixelScale;
  float decayTime;
  float slowmotion;
  float useProgressiveF;
};

float4 crt_display(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
  uint width, height;
  tex0.GetDimensions(width, height);
  bool useProgressive = (useProgressiveF > 0.5);

  // 原点を左上にするよ。
  float2 leftStart = float2(pos.x, pos.y);
  float2 pixelCoord = floor(leftStart / pixelScale);
  // R,G,B単体のサブピクセルのサイズ。
  float2 RGBdotSize = float2(pixelScale / 6, pixelScale);

  // pixelScaleを使ってモザイク。上下反転を直すよ。
  float2 pixelPosition = (pixelCoord + 0.5) * pixelScale;

  float3 output;
  // 横にブラーを掛けるよ。
  if (horizontalBlur > 0.0) {
    float3 blurs = float3(0.0, 0.0, 0.0);
    float w[5] = {0.3, 0.2, 0.1, 0.05, 0.01};  // ニセガウシアン。ちょっと明るい。
    // blurs += IMG_NORM_PIXEL(inputImage, mosaic).rgb * w[0];
    // blurs += tex0.Sample(sampler0, mosaic).rgb * w[0];
    blurs += tex0.Load(int3(pixelPosition.xy, 0)).rgb * w[0];
    for (int i = 1; i < 5; ++i) {
      // float offset = float(i) * (pixelScale / width) * horizontalBlur;
      // blurs += tex0.Sample(sampler0, mosaic + float2(offset, 0.0)).rgb * w[i];
      // blurs += tex0.Sample(sampler0, mosaic - float2(offset, 0.0)).rgb * w[i];
      blurs += tex0.Load(int3(pixelPosition.xy + float2(i * pixelScale * horizontalBlur, 0), 0)).rgb * w[i];
      blurs += tex0.Load(int3(pixelPosition.xy - float2(i * pixelScale * horizontalBlur, 0), 0)).rgb * w[i];
    }
    output = blurs;
  } else {
    output = tex0.Sample(sampler0, uv).rgb;
  }

  // RGB。
  if (RGBeffect > 0.0) {
    float RGBpixels = fmod(floor(leftStart.x / RGBdotSize.x), 6.0);
    float3 RGBMask = float3(1.0, 1.0, 1.0);
    float ratio = 1.0 - clamp(RGBeffect / 100.0, 0.0, 1.0);

    if (fmod(RGBpixels, 3.0) < 1.0) {  // R
      RGBMask = float3(1.0, ratio, ratio);
    } else if (fmod(RGBpixels, 3.0) < 2.0) {  // G
      RGBMask = float3(ratio, 1.0, ratio);
    } else {  // B
      RGBMask = float3(ratio, ratio, 1.0);
    }
    output *= RGBMask;
  }

  // 左上から走査して発光させていくよ。
  // decayTimeを0.0-3.0の範囲にリマップするよ。
  float localDecay = decayTime * 0.3;

  if (localDecay > 0.0) {
    // 1/60秒で全部の走査を終えるのを基本とするよ。
    float durationTime = 1.0 / 60.0;

    // 画面上のピクセル行/列の総数。
    float allLines = ceil(height / pixelScale);
    float allPixels = floor(width / pixelScale);
    // 1ラインあたりの走査時間と、1ピクセルあたりの走査時間を用意するよ。
    float lineTime = durationTime / allLines;
    float pixelTime = lineTime / allPixels;
    durationTime += lineTime;

    // 走査の順番。
    float scanOrder;
    if (useProgressive) {
      // プログレッシブ走査も付けておこう。
      scanOrder = pixelCoord.y;
    } else {
      // インターレース走査。
      float lineNo = floor(pixelCoord.y / 2.0);
      scanOrder = (fmod(pixelCoord.y, 2.0) < 0.5) ? lineNo : ceil(allLines / 2.0) + lineNo;
    }

    // 1サイクル後も残すよ。
    float scanEnd = fmod(currentTime / slowmotion, durationTime) - scanOrder * lineTime;
    if (scanEnd < 0.0) {
      scanEnd += durationTime;
    }
    float pixelScanEnd = scanEnd - (pixelCoord.x * pixelTime);

    // 減衰。
    // 0.0で1ライン分の時間、1.0で1フレーム分の時間で減衰するよ。
    float remapDecayTime = lerp(lineTime, durationTime, clamp(localDecay, 0.0, 1.0));
    float brightness = (pixelScanEnd < 0.0) ? 0.0 : pow(1.0 - smoothstep(0.0, remapDecayTime, pixelScanEnd), 4.0);
    // decayTimeが2.0->3.0になるにつれてラインの暗転をなくすよ。
    float longDecay = lerp(10.0, 0.0, smoothstep(2.0, 3.0, localDecay));
    // 以上の残光効果を適用するよ。
    output *= 1.0 - (1.0 - brightness) * longDecay * 0.1;

    // ピクセルが走査された瞬間に光らせるよ。
    float flash = pixelTime * 5.0;  // 5走査ドット分光るようにしてる。もっと長くても良いかも。

    if (pixelScanEnd >= 0.0 && pixelScanEnd < flash) {
      float flashAfter = pow(1.0 - (pixelScanEnd / flash), 2.0);
      output = lerp(output, float3(1.0, 1.0, 1.0), flashAfter);
    }
  }

  // ドットの質感を作るよ。
  if (pixelScale > 1.0) {
    // 線の周期だよ
    float lineX = fmod(leftStart.x, RGBdotSize.x);
    float lineY = fmod(leftStart.y, pixelScale / 8.0);

    // 縦線と横線の太さだよ
    float lineXweight = pixelScale / 30.0;
    float lineYweight = pixelScale / 200.0;

    bool is_onX = lineX < lineXweight;
    bool is_onY = lineY < lineYweight;

    // pixelScaleを8分割して上下を暗くするよ。
    float RGBdotBit = fmod(floor(leftStart.y / pixelScale * 8.0), 8.0);
    if (RGBdotBit == 0.0 || RGBdotBit == 7.0) {
      output *= 0.4;
    } else if (RGBdotBit == 1.0 || RGBdotBit == 6.0) {
      output *= 0.7;
    }

    if (is_onX || is_onY) {
      output = lerp(output, float3(0.0, 0.0, 0.0), smoothstep(1.0, 8.0, pixelScale));
    }
  }

  return float4(output, 1.0);
}
