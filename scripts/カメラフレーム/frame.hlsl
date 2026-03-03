cbuffer cb0 : register(b0) {
  float line_length;
  float line_thickness;
  float width;
  float height;
  float color_red;
  float color_green;
  float color_blue;
};

float4 frame(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
  float x = pos.x;
  float y = pos.y;

  if (
      // 左上：横
      (x < line_length && y < line_thickness) ||
      // 左上：縦
      (x < line_thickness && y < line_length) ||
      // 右下：横
      (x > width - line_length && y > height - line_thickness) ||
      // 右下：縦
      (x > width - line_thickness && y > height - line_length) ||
      // 右上：横
      (x > width - line_length && y < line_thickness) ||
      // 右上：縦
      (x > width - line_thickness && y < line_length) ||
      // 左下：横
      (x < line_length && y > height - line_thickness) ||
      // 左下：縦
      (x < line_thickness && y > height - line_length)) {
    return float4(color_red, color_green, color_blue, 1);
  } else {
    return float4(0, 0, 0, 0);
  }
}

// vim: set ft=hlsl ts=4 sts=4 sw=4 noet:
