import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'dart:io';

class CameraService {
  Future<CameraController> initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await controller.initialize();
    return controller;
  }

  Future<String> takePicture(CameraController controller) async {
    final image = await controller.takePicture();
    
    // Compress image
    final bytes = await File(image.path).readAsBytes();
    final decodedImage = img.decodeImage(bytes);
    
    if (decodedImage != null) {
      final resized = img.copyResize(decodedImage, width: 1920);
      final compressed = img.encodeJpg(resized, quality: 90);
      
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(path);
      await file.writeAsBytes(compressed);
      
      return path;
    }
    
    return image.path;
  }
}
