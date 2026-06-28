import 'package:flutter/material.dart';
import 'package:whisk/ui/core/whisk_colors.dart';

class EditorNavbar extends StatelessWidget {
  const EditorNavbar({super.key, required this.onCloseWorkspace});

  final VoidCallback onCloseWorkspace;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: const Color(0xFF181818),
          child: Row(
            children: [
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Back to dashboard',
                onPressed: onCloseWorkspace,
                icon: const Icon(Icons.arrow_back, color: kTextSecondary, size: 22),
              ),
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.5,
                    child: const TextField(
                      style: TextStyle(color: kTextPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Buscar...',
                        hintStyle: TextStyle(color: kTextMuted),
                        prefixIcon:
                            Icon(Icons.search, color: kTextMuted, size: 20),
                        border: InputBorder.none,
                        filled: true,
                        fillColor: Color(0xFF22262E),
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}
