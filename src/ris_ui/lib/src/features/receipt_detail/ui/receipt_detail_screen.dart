import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ris_core/ris_core.dart';

import '../../../core/widgets/app_async_view.dart';
import '../../../core/widgets/app_shell.dart';
import '../data/receipt_detail_repository.dart';
import '../logic/receipt_detail_controller.dart';
import 'widgets/receipt_metadata_card.dart';

class ReceiptDetailScreen extends StatelessWidget {
  const ReceiptDetailScreen({super.key, required this.receiptId});

  final String receiptId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReceiptDetailController>(
      create: (context) => ReceiptDetailController(
        receiptId: ReceiptId(receiptId),
        repository: context.read<ReceiptDetailRepository>(),
      )..load(),
      child: const _ReceiptDetailView(),
    );
  }
}

class _ReceiptDetailView extends StatelessWidget {
  const _ReceiptDetailView();

  @override
  Widget build(BuildContext context) {
    return Consumer<ReceiptDetailController>(
      builder: (context, controller, child) {
        final receipt = controller.receipt;
        final isExtractionInProgress = receipt?.status == 'pending' ||
            receipt?.status == 'processing';

        return AppShell(
          title: 'Receipt details',
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: controller.load,
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 8),
          ],
          body: AppAsyncView(
            isLoading: controller.isLoading,
            errorMessage: controller.errorMessage,
            onRetry: controller.load,
            child: receipt == null || controller.image == null
                ? const SizedBox.shrink()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 900;
                      final imageColumn = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _OcrOverlayControls(controller: controller),
                          const SizedBox(height: 16),
                          Expanded(
                            child: _WideImagePanel(
                              bytes: controller.image!.bytes,
                              overlayElements: controller.activeOverlayElements,
                              overlayMode: controller.ocrOverlayMode,
                            ),
                          ),
                        ],
                      );
                      final metadataColumn = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              FilledButton.icon(
                                onPressed: controller.isRestarting ||
                                        isExtractionInProgress
                                    ? null
                                    : controller.restartExtraction,
                                icon: controller.isRestarting ||
                                        isExtractionInProgress
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.restart_alt),
                                label: Text(
                                  controller.isRestarting
                                      ? 'Restarting...'
                                      : isExtractionInProgress
                                          ? 'Extraction in progress...'
                                          : 'Restart extraction',
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: controller.isDeleting
                                    ? null
                                    : () async {
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Delete receipt?'),
                                            content: const Text(
                                              'This removes the receipt, its image, and all extraction data.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(context).pop(false),
                                                child: const Text('Cancel'),
                                              ),
                                              FilledButton(
                                                onPressed: () => Navigator.of(context).pop(true),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirmed == true && context.mounted) {
                                          await controller.deleteReceipt();
                                          if (context.mounted) {
                                            Navigator.of(context).pop();
                                          }
                                        }
                                      },
                                icon: const Icon(Icons.delete_outline),
                                label: Text(
                                  controller.isDeleting ? 'Deleting...' : 'Delete',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (isExtractionInProgress && !controller.isRestarting) ...[
                            Text(
                              'Restart is disabled while the current extraction is still running.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 16),
                          ],
                          ReceiptMetadataCard(receipt: controller.receipt!),
                        ],
                      );

                      if (isWide) {
                        return SizedBox(
                          height: constraints.maxHeight,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: imageColumn,
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 4,
                                child: _ScrollablePane(child: metadataColumn),
                              ),
                            ],
                          ),
                        );
                      }

                      final imageViewportHeight = (constraints.maxHeight * 0.6)
                          .clamp(280.0, 520.0)
                          .toDouble();
                      final imageCard = Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _OcrOverlayControls(controller: controller),
                              const SizedBox(height: 20),
                              SizedBox(
                                height: imageViewportHeight,
                                child: _ScrollableReceiptImage(
                                  bytes: controller.image!.bytes,
                                  overlayElements: controller.activeOverlayElements,
                                  overlayMode: controller.ocrOverlayMode,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );

                      return ListView(
                        children: [
                          imageCard,
                          const SizedBox(height: 16),
                          metadataColumn,
                        ],
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}

class _WideImagePanel extends StatelessWidget {
  const _WideImagePanel({
    required this.bytes,
    required this.overlayElements,
    required this.overlayMode,
  });

  final List<int> bytes;
  final List<OcrElement> overlayElements;
  final OcrOverlayMode overlayMode;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Original image',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _ScrollableReceiptImage(
                bytes: bytes,
                overlayElements: overlayElements,
                overlayMode: overlayMode,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScrollablePane extends StatefulWidget {
  const _ScrollablePane({required this.child});

  final Widget child;

  @override
  State<_ScrollablePane> createState() => _ScrollablePaneState();
}

class _ScrollablePaneState extends State<_ScrollablePane> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: widget.child,
      ),
    );
  }
}

class _ScrollableReceiptImage extends StatefulWidget {
  const _ScrollableReceiptImage({
    required this.bytes,
    required this.overlayElements,
    required this.overlayMode,
  });

  final List<int> bytes;
  final List<OcrElement> overlayElements;
  final OcrOverlayMode overlayMode;

  @override
  State<_ScrollableReceiptImage> createState() => _ScrollableReceiptImageState();
}

class _ScrollableReceiptImageState extends State<_ScrollableReceiptImage> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
      ),
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.only(right: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: _ReceiptImageWithOverlay(
              bytes: widget.bytes,
              overlayElements: widget.overlayElements,
              overlayMode: widget.overlayMode,
            ),
          ),
        ),
      ),
    );
  }
}

class _OcrOverlayControls extends StatelessWidget {
  const _OcrOverlayControls({required this.controller});

  final ReceiptDetailController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.hasAnyOverlays) {
      return Row(
        children: [
          Text(
            'Original image',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Original image',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SegmentedButton<OcrOverlayMode>(
          segments: [
            const ButtonSegment<OcrOverlayMode>(
              value: OcrOverlayMode.none,
              label: Text('No overlay'),
            ),
            ButtonSegment<OcrOverlayMode>(
              value: OcrOverlayMode.lines,
              label: const Text('Lines'),
              enabled: controller.hasLineOverlays,
            ),
            ButtonSegment<OcrOverlayMode>(
              value: OcrOverlayMode.blocks,
              label: const Text('Blocks'),
              enabled: controller.hasBlockOverlays,
            ),
          ],
          selected: {controller.ocrOverlayMode},
          onSelectionChanged: (selection) {
            controller.setOverlayMode(selection.first);
          },
        ),
      ],
    );
  }
}

class _ReceiptImageWithOverlay extends StatefulWidget {
  const _ReceiptImageWithOverlay({
    required this.bytes,
    required this.overlayElements,
    required this.overlayMode,
  });

  final List<int> bytes;
  final List<OcrElement> overlayElements;
  final OcrOverlayMode overlayMode;

  @override
  State<_ReceiptImageWithOverlay> createState() =>
      _ReceiptImageWithOverlayState();
}

class _ReceiptImageWithOverlayState extends State<_ReceiptImageWithOverlay> {
  ui.Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _decodeImageSize();
  }

  @override
  void didUpdateWidget(covariant _ReceiptImageWithOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameBytes(oldWidget.bytes, widget.bytes)) {
      _decodeImageSize();
    }
  }

  Future<void> _decodeImageSize() async {
    final bytes = Uint8List.fromList(widget.bytes);
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final imageSize = ui.Size(
      frame.image.width.toDouble(),
      frame.image.height.toDouble(),
    );

    if (!mounted) {
      frame.image.dispose();
      codec.dispose();
      return;
    }

    setState(() {
      _imageSize = imageSize;
    });

    frame.image.dispose();
    codec.dispose();
  }

  bool _sameBytes(List<int> a, List<int> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final imageBytes = Uint8List.fromList(widget.bytes);

    return LayoutBuilder(
      builder: (context, constraints) {
        final imageSize = _imageSize;
        if (imageSize == null) {
          return Image.memory(
            imageBytes,
            fit: BoxFit.contain,
            alignment: Alignment.topCenter,
          );
        }

        final targetWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : imageSize.width;
        final targetHeight = targetWidth * (imageSize.height / imageSize.width);
        final imageRect = Offset.zero & Size(targetWidth, targetHeight);

        return SizedBox(
          width: targetWidth,
          height: targetHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.fill,
                  alignment: Alignment.topCenter,
                ),
              ),
              if (widget.overlayMode != OcrOverlayMode.none &&
                  widget.overlayElements.isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _OcrOverlayPainter(
                        elements: widget.overlayElements,
                        mode: widget.overlayMode,
                        imageRect: imageRect,
                        imageSize: imageSize,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _OcrOverlayPainter extends CustomPainter {
  const _OcrOverlayPainter({
    required this.elements,
    required this.mode,
    required this.imageRect,
    required this.imageSize,
  });

  final List<OcrElement> elements;
  final OcrOverlayMode mode;
  final Rect imageRect;
  final ui.Size? imageSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (elements.isEmpty || size.isEmpty || imageSize == null || imageRect.isEmpty) {
      return;
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = mode == OcrOverlayMode.lines ? 2.5 : 1.5
      ..color = mode == OcrOverlayMode.lines
          ? const Color(0xFF2E7DFF)
          : const Color(0xFFFF6F00);

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = paint.color.withValues(alpha: 0.12);

    final scaleX = imageRect.width / imageSize!.width;
    final scaleY = imageRect.height / imageSize!.height;

    for (final element in elements) {
      final rect = Rect.fromLTWH(
        imageRect.left + (element.boundingBox.x * scaleX),
        imageRect.top + (element.boundingBox.y * scaleY),
        element.boundingBox.width * scaleX,
        element.boundingBox.height * scaleY,
      );
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OcrOverlayPainter oldDelegate) {
    return oldDelegate.elements != elements ||
        oldDelegate.mode != mode ||
        oldDelegate.imageRect != imageRect ||
        oldDelegate.imageSize != imageSize;
  }
}
