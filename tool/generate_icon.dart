import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  print('Generating Resumind app icon PNGs...');

  final whiteColor = img.ColorRgb8(255, 255, 255);

  // 1. Create app_icon.png (gradient background)
  final iconImg = img.Image(width: 1024, height: 1024);
  for (int y = 0; y < 1024; y++) {
    for (int x = 0; x < 1024; x++) {
      double t = (x + y) / 2048.0;
      int r = ((1 - t) * 108 + t * 3).toInt();
      int g = ((1 - t) * 99 + t * 218).toInt();
      int b = ((1 - t) * 255 + t * 198).toInt();
      iconImg.setPixel(x, y, img.ColorRgb8(r, g, b));
    }
  }

  // Draw white shapes on iconImg
  _drawRAndLines(iconImg, whiteColor);

  // Save app_icon.png
  final iconFile = File('assets/icons/app_icon.png');
  iconFile.parent.createSync(recursive: true);
  iconFile.writeAsBytesSync(img.encodePng(iconImg));
  print('Saved assets/icons/app_icon.png');

  // 2. Create app_icon_foreground.png (transparent background)
  final fgImg = img.Image(width: 1024, height: 1024, numChannels: 4);
  // Clear transparent
  for (int y = 0; y < 1024; y++) {
    for (int x = 0; x < 1024; x++) {
      fgImg.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
    }
  }

  // Draw white shapes on fgImg
  _drawRAndLines(fgImg, whiteColor);

  // Save app_icon_foreground.png
  final fgFile = File('assets/icons/app_icon_foreground.png');
  fgFile.writeAsBytesSync(img.encodePng(fgImg));
  print('Saved assets/icons/app_icon_foreground.png');
}

void _drawRect(img.Image img, int x1, int y1, int x2, int y2, img.Color color) {
  for (int y = y1; y <= y2; y++) {
    for (int x = x1; x <= x2; x++) {
      if (x >= 0 && x < img.width && y >= 0 && y < img.height) {
        img.setPixel(x, y, color);
      }
    }
  }
}

void _drawRAndLines(img.Image image, img.Color whiteColor) {
  // Stem: 320 to 400, y: 280 to 740
  _drawRect(image, 320, 280, 400, 740, whiteColor);

  // Loop top bar: 400 to 640, y: 280 to 360
  _drawRect(image, 400, 280, 640, 360, whiteColor);

  // Loop bottom bar: 400 to 640, y: 500 to 580
  _drawRect(image, 400, 500, 640, 580, whiteColor);

  // Loop right bar: 600 to 680, y: 360 to 500
  _drawRect(image, 600, 360, 680, 500, whiteColor);

  // Diagonal leg: from x=500/580 at y=580 to x=660/740 at y=740
  for (int y = 580; y <= 740; y++) {
    double t = (y - 580) / 160.0;
    int xStart = (500 + t * 160).toInt();
    int xEnd = xStart + 80;
    for (int x = xStart; x <= xEnd; x++) {
      if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
        image.setPixel(x, y, whiteColor);
      }
    }
  }

  // Document lines:
  // Line 1: x: 760 to 860, y: 340 to 356
  _drawRect(image, 760, 340, 860, 356, whiteColor);
  // Line 2: x: 760 to 900, y: 440 to 456
  _drawRect(image, 760, 440, 900, 456, whiteColor);
  // Line 3: x: 760 to 880, y: 540 to 556
  _drawRect(image, 760, 540, 880, 556, whiteColor);
}
