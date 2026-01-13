import 'package:flutter/material.dart';

class EmojiPickerContent extends StatelessWidget {
  final dynamic controller;
  final Function(String emoji) onSelected;
  final double? height;
  final double? width;
  final VoidCallback? onDismiss;

  const EmojiPickerContent({
    super.key,
    required this.controller,
    required this.onSelected,
    this.height,
    this.width,
    this.onDismiss,
  });

  static const List<String> emojis = [
    '😀',
    '😂',
    '😍',
    '🥳',
    '😎',
    '🤩',
    '😡',
    '😭',
    '😱',
    '👻',
    '🌈',
    '🍎',
    '⚽️',
    '🏎️',
    '🔥',
    '❤️',
    '💪',
    '👍',
    '👏',
    '🙌',
    '✨',
    '🎉',
    '🎁',
    '🎂',
    '🍭',
    '🥂',
    '🎀',
    '🎈',
    '⭐',
    '🌙',
    '🌊',
    '🍀',
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {}, // Absorb taps
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: width ?? 280,
        height: height ?? 220,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                '选择表情',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: emojis.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      onSelected(emojis[index]);
                      onDismiss?.call();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          emojis[index],
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HorizontalEmojiPicker extends StatelessWidget
    implements PreferredSizeWidget {
  final Function(String emoji) onSelected;

  const HorizontalEmojiPicker({super.key, required this.onSelected});

  static const List<String> commonEmojis = [
    '❤️',
    '🙌',
    '🔥',
    '😂',
    '👍',
    '👏',
    '✨',
    '🎉',
    '🌹',
    '🍦',
    '🍩',
    '🎈',
    '❤️',
    '🙌',
    '🔥',
    '😂',
    '👍',
    '👏',
  ];

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: Colors.transparent,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: commonEmojis.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => onSelected(commonEmojis[index]),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                child: Text(
                  commonEmojis[index],
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class Gift {
  final String name;
  final String emoji;
  final int price;

  const Gift({required this.name, required this.emoji, required this.price});
}

class GiftPickerContent extends StatelessWidget {
  final dynamic controller;
  final Function(Gift gift) onSelected;
  final VoidCallback? onDismiss;

  const GiftPickerContent({
    super.key,
    required this.controller,
    required this.onSelected,
    this.onDismiss,
  });

  static const List<Gift> gifts = [
    Gift(name: '比心', emoji: '❤️', price: 1),
    Gift(name: '鲜花', emoji: '🌹', price: 10),
    Gift(name: '奶茶', emoji: '🧋', price: 20),
    Gift(name: '冰淇淋', emoji: '🍦', price: 50),
    Gift(name: '甜甜圈', emoji: '🍩', price: 66),
    Gift(name: '跑车', emoji: '🏎️', price: 520),
    Gift(name: '游艇', emoji: '🚢', price: 1314),
    Gift(name: '火箭', emoji: '🚀', price: 9999),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 380,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // 顶部切换条
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildTab('热门', active: true),
                const SizedBox(width: 16),
                _buildTab('豪华'),
                const SizedBox(width: 16),
                _buildTab('特效'),
                const Spacer(),
                const Text(
                  '充值 >',
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = (constraints.maxWidth - 24) / 4;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: gifts.map((gift) {
                      return GestureDetector(
                        onTap: () {
                          onSelected(gift);
                          onDismiss?.call();
                        },
                        child: Container(
                          width: itemWidth,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.05),
                                ),
                                child: Text(
                                  gift.emoji,
                                  style: const TextStyle(fontSize: 28),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                gift.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.stars,
                                    color: Colors.orangeAccent,
                                    size: 10,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${gift.price}',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
          // 底部发送区域
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white54,
                  size: 16,
                ),
                const SizedBox(width: 4),
                const Text(
                  '12,450',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF4D4D), Color(0xFFFF8E53)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Text(
                    '赠送',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title, {bool active = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            color: active ? Colors.white : Colors.white54,
            fontSize: 14,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        if (active)
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 12,
            height: 2,
            decoration: BoxDecoration(
              color: Colors.orangeAccent,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
      ],
    );
  }
}
