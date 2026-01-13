import 'dart:math';
import 'package:flutter/material.dart';
import '../models/stock_model.dart';
import '../services/stock_service.dart';
import 'stock_kline_page.dart';

class MiniKLinePainter extends CustomPainter {
  final StockInfo stock;
  final int? selectedIndex;

  static const Color upColor = Color(0xFFEB4436);
  static const Color downColor = Color(0xFF4CAF50);
  static const Color gridColor = Color(0x1FDDDDDD);

  final bool showVolume;

  MiniKLinePainter(this.stock, {this.selectedIndex, this.showVolume = false});

  @override
  void paint(Canvas canvas, Size size) {
    final points = stock.kLines;
    if (points.isEmpty && stock.current == 0) return;

    List<KLinePoint> displayPoints = points.length > 50
        ? points.sublist(points.length - 50)
        : List.from(points);

    final todayStr = DateTime.now().toString().split(' ')[0].replaceAll('-', '');
    bool hasToday = displayPoints.isNotEmpty &&
        (displayPoints.last.time.replaceAll('-', '') == todayStr || displayPoints.last.time == stock.date);

    if (!hasToday && stock.current > 0) {
      displayPoints.add(KLinePoint(
        time: "今日",
        open: stock.open > 0 ? stock.open : stock.yesterdayClose,
        close: stock.current,
        high: stock.high > 0 ? stock.high : max(stock.current, stock.yesterdayClose),
        low: stock.low > 0 ? stock.low : min(stock.current, stock.yesterdayClose),
        volume: stock.volume,
      ));
    }

    if (displayPoints.isEmpty) return;

    double maxVal = displayPoints.map((p) => p.high).reduce(max);
    double minVal = displayPoints.map((p) => p.low).reduce(min);
    maxVal *= 1.01;
    minVal *= 0.99;
    final double range = maxVal - minVal;
    if (range == 0) return;

    final double widthPerPoint = size.width / displayPoints.length;
    final double candleWidth = widthPerPoint * 0.7;

    final ma5List = _calculateMA(points, 5);
    final ma10List = _calculateMA(points, 10);
    final ma20List = _calculateMA(points, 20);
    final startIndex = points.length > 50 ? points.length - 50 : 0;

    _drawGrid(canvas, size);

    for (int i = 0; i < displayPoints.length; i++) {
      final p = displayPoints[i];
      final x = i * widthPerPoint + widthPerPoint / 2;
      final double openY = size.height - ((p.open - minVal) / range * size.height);
      final double closeY = size.height - ((p.close - minVal) / range * size.height);
      final double highY = size.height - ((p.high - minVal) / range * size.height);
      final double lowY = size.height - ((p.low - minVal) / range * size.height);

      double prevClose;
      if (i > 0) {
        prevClose = displayPoints[i - 1].close;
      } else if (points.isNotEmpty && startIndex > 0) {
        prevClose = points[startIndex - 1].close;
      } else {
        prevClose = p.open;
      }
      if (p.time == "今日") {
        prevClose = stock.yesterdayClose > 0 ? stock.yesterdayClose : prevClose;
      }

      final color = p.close >= prevClose ? upColor : downColor;
      final paint = Paint()..color = color..strokeWidth = 1.2;

      final bodyTop = min(openY, closeY);
      final bodyBottom = max(openY, closeY);
      canvas.drawLine(Offset(x, highY), Offset(x, bodyTop), paint);
      canvas.drawLine(Offset(x, bodyBottom), Offset(x, lowY), paint);

      final bodyRect = Rect.fromLTRB(x - candleWidth / 2, bodyTop, x + candleWidth / 2, bodyBottom);
      if (bodyRect.height < 1.0) {
        canvas.drawLine(Offset(x - candleWidth / 2, openY), Offset(x + candleWidth / 2, openY), paint);
      } else {
        if (p.close >= p.open) {
          paint.style = PaintingStyle.stroke;
          paint.strokeWidth = 1.0;
          canvas.drawRect(bodyRect, paint);
        } else {
          paint.style = PaintingStyle.fill;
          canvas.drawRect(bodyRect, paint);
        }
      }

      if (showVolume) {
        _drawVolumeItem(canvas, size, p, i, displayPoints.length, widthPerPoint, prevClose);
      }
    }

    _drawMALine(canvas, ma5List, startIndex, displayPoints.length, widthPerPoint, size, minVal, range, Colors.yellow);
    _drawMALine(canvas, ma10List, startIndex, displayPoints.length, widthPerPoint, size, minVal, range, Colors.orange);
    _drawMALine(canvas, ma20List, startIndex, displayPoints.length, widthPerPoint, size, minVal, range, Colors.purpleAccent);

    final double latestY = size.height - ((stock.current - minVal) / range * size.height);
    final dashedPaint = Paint()..color = (stock.isUp ? upColor : downColor).withOpacity(0.5)..strokeWidth = 0.8;
    for (double i = 0; i < size.width; i += 5) {
      canvas.drawLine(Offset(i, latestY), Offset(i + 2, latestY), dashedPaint);
    }

    if (selectedIndex != null && selectedIndex! < displayPoints.length) {
      _drawCrosshair(canvas, size, displayPoints[selectedIndex!], selectedIndex!, widthPerPoint, minVal, range);
    }
  }

  void _drawCrosshair(Canvas canvas, Size size, KLinePoint p, int index, double widthPerPoint, double minVal, double range) {
    final x = index * widthPerPoint + widthPerPoint / 2;
    final y = size.height - ((p.close - minVal) / range * size.height);
    final paint = Paint()..color = Colors.white54..strokeWidth = 0.5;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    canvas.drawCircle(Offset(x, y), 3, Paint()..color = Colors.white);

    final textStyle = const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'Courier');
    final changeVal = p.close - p.open;
    final changePercent = p.open == 0 ? 0.0 : (changeVal / p.open) * 100;
    final color = changeVal >= 0 ? upColor : downColor;

    final textPainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(text: \"${p.time.length > 8 ? p.time.substring(4) : p.time}\\n\", style: textStyle.copyWith(color: Colors.white38)),
          TextSpan(text: \"收: ${p.close.toStringAsFixed(2)} \", style: textStyle.copyWith(fontWeight: FontWeight.bold)),
          TextSpan(text: \"${changeVal >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%\\n\", style: textStyle.copyWith(color: color, fontWeight: FontWeight.bold)),
          TextSpan(text: \"高: ${p.high.toStringAsFixed(2)}  低: ${p.low.toStringAsFixed(2)}\", style: textStyle.copyWith(color: Colors.white70, fontSize: 9)),
        ],
        style: textStyle,
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    double tooltipX = x + 10;
    if (tooltipX + textPainter.width > size.width) tooltipX = x - textPainter.width - 10;
    double tooltipY = y - textPainter.height - 10;
    if (tooltipY < 0) tooltipY = y + 10;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(tooltipX - 8, tooltipY - 8, textPainter.width + 16, textPainter.height + 16), const Radius.circular(8)),
      Paint()..color = const Color(0xCC1A1A1A)..style = PaintingStyle.fill,
    );
    textPainter.paint(canvas, Offset(tooltipX, tooltipY));
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()..color = gridColor..strokeWidth = 0.5;
    for (int i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      final x = size.width * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  void _drawMALine(Canvas canvas, List<double?> maList, int startIndex, int count, double widthPerPoint, Size size, double minVal, double range, Color color) {
    final paint = Paint()..color = color..strokeWidth = 1.0..style = PaintingStyle.stroke;
    final path = Path();
    bool started = false;
    for (int i = 0; i < count; i++) {
      final index = startIndex + i;
      if (index >= maList.length) break;
      final val = maList[index];
      if (val == null) continue;
      final x = i * widthPerPoint + widthPerPoint / 2;
      final y = size.height - ((val - minVal) / range * size.height);
      if (!started) { path.moveTo(x, y); started = true; } else { path.lineTo(x, y); }
    }
    if (started) canvas.drawPath(path, paint);
  }

  List<double?> _calculateMA(List<KLinePoint> points, int period) {
    if (points.isEmpty) return [];
    final List<double?> result = List.filled(points.length, null);
    for (int i = 0; i < points.length; i++) {
      if (i < period - 1) continue;
      double sum = 0;
      for (int j = 0; j < period; j++) sum += points[i - j].close;
      result[i] = sum / period;
    }
    return result;
  }

  @override
  bool shouldRepaint(covariant MiniKLinePainter oldDelegate) => oldDelegate.selectedIndex != selectedIndex || oldDelegate.stock != stock;

  void _drawVolumeItem(Canvas canvas, Size size, KLinePoint p, int index, int totalCount, double widthPerPoint, double prevClose) {
    final double volHeight = size.height * 0.15;
    final double volBase = size.height;
    final paint = Paint()..color = (p.close >= prevClose ? upColor : downColor).withOpacity(0.6)..style = PaintingStyle.fill;
    final double barWidth = widthPerPoint * 0.7;
    final double x = index * widthPerPoint + widthPerPoint / 2;
    final double barHeight = (p.volume / 1000000).clamp(2.0, volHeight);
    canvas.drawRect(Rect.fromLTRB(x - barWidth / 2, volBase - barHeight, x + barWidth / 2, volBase), paint);
  }
}

class KLineInteractiveContainer extends StatefulWidget {
  final StockInfo stock;
  final bool isFullScreen;

  const KLineInteractiveContainer({super.key, required this.stock, this.isFullScreen = false});

  @override
  State<KLineInteractiveContainer> createState() => _KLineInteractiveContainerState();
}

class _KLineInteractiveContainerState extends State<KLineInteractiveContainer> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerSize = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (details) => _handleTouch(details.localPosition, containerSize),
          onPanUpdate: (details) => _handleTouch(details.localPosition, containerSize),
          onTapDown: (details) => _handleTouch(details.localPosition, containerSize),
          onDoubleTap: () => setState(() => _selectedIndex = null),
          child: Stack(
            children: [
              CustomPaint(painter: MiniKLinePainter(widget.stock, selectedIndex: _selectedIndex, showVolume: widget.isFullScreen), size: Size.infinite),
              if (!widget.isFullScreen)
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => StockKLineFullScreenPage(stock: widget.stock)));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.fullscreen_rounded, color: Colors.white.withOpacity(0.6), size: 22),
                    ),
                  ),
                ),
              if (_selectedIndex != null)
                Positioned(
                  bottom: 5,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10)),
                      child: const Text(\"双击图表清除准星\", style: TextStyle(color: Colors.white54, fontSize: 10)),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _handleTouch(Offset localPosition, Size size) {
    final points = widget.stock.kLines;
    List<KLinePoint> displayPoints = points.length > 50 ? points.sublist(points.length - 50) : List.from(points);
    final todayStr = DateTime.now().toString().split(' ')[0].replaceAll('-', '');
    bool hasToday = displayPoints.isNotEmpty && (displayPoints.last.time.replaceAll('-', '') == todayStr || displayPoints.last.time == widget.stock.date);
    if (!hasToday && widget.stock.current > 0) displayPoints.add(KLinePoint(time: \"今日\", open: 0, close: 0, high: 0, low: 0, volume: 0));
    if (displayPoints.isEmpty) return;
    final widthPerPoint = size.width / displayPoints.length;
    int index = (localPosition.dx / widthPerPoint).floor().clamp(0, displayPoints.length - 1);
    if (_selectedIndex != index) setState(() => _selectedIndex = index);
  }
}
