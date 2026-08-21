import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Menu photo with a graceful fallback when there's no image.
class MenuImage extends StatelessWidget {
  final String? url;
  final double width;
  final double height;

  const MenuImage({
    super.key,
    required this.url,
    this.width = double.infinity,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: const Color(0xFFEDE4DA),
      alignment: Alignment.center,
      child: const Icon(Icons.local_cafe_outlined, color: Color(0xFF9C8A78)),
    );
    if (url == null || url!.isEmpty) return placeholder;
    return CachedNetworkImage(
      imageUrl: url!,
      width: width,
      height: height,
      fit: BoxFit.cover,
      placeholder: (_, __) => placeholder,
      errorWidget: (_, __, ___) => placeholder,
    );
  }
}
