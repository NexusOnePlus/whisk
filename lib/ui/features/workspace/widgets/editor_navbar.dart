import 'package:flutter/material.dart';
import 'package:whisk/ui/core/whisk_colors.dart';

class EditorNavbar extends StatelessWidget {
  const EditorNavbar({
    super.key,
    required this.onCloseWorkspace,
    this.projectTitle,
    this.collectionName,
    this.tags = const [],
    this.onCreateInvite,
    this.onJoinInvite,
    this.onImportFile,
    this.onExportPdf,
    this.onAbout,
    this.onShowLogs,
    this.canExportPdf = false,
  });

  final VoidCallback onCloseWorkspace;
  final String? projectTitle;
  final String? collectionName;
  final List<String> tags;
  final VoidCallback? onCreateInvite;
  final VoidCallback? onJoinInvite;
  final VoidCallback? onImportFile;
  final VoidCallback? onExportPdf;
  final VoidCallback? onAbout;
  final VoidCallback? onShowLogs;
  final bool canExportPdf;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to dashboard',
            onPressed: onCloseWorkspace,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: kTextSecondary,
              size: 20,
            ),
          ),
          _NavBarDropdown(
            label: 'File',
            items: [
              _NavBarMenuItem(
                icon: Icons.file_open_outlined,
                label: 'Import file',
                onTap: onImportFile,
              ),
              if (canExportPdf)
                _NavBarMenuItem(
                  icon: Icons.picture_as_pdf_outlined,
                  label: 'Export to PDF',
                  onTap: onExportPdf,
                ),
            ],
          ),
          _NavBarDropdown(
            label: 'About',
            items: [
              _NavBarMenuItem(
                icon: Icons.info_outline,
                label: 'About Whisk',
                onTap: onAbout,
              ),
            ],
          ),
          _NavBarDropdown(
            label: 'Help',
            items: [
              _NavBarMenuItem(
                icon: Icons.terminal,
                label: 'Logs',
                onTap: onShowLogs,
              ),
            ],
          ),
          if (projectTitle != null)
            Expanded(
              child: Align(
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (collectionName != null)
                      Text(
                        '$collectionName > $projectTitle',
                        style: const TextStyle(
                          color: kTextPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      Text(
                        projectTitle!,
                        style: const TextStyle(
                          color: kTextPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          tags.join(' · '),
                          style: TextStyle(
                            color: kTextMuted,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          IconButton(
            tooltip: 'Create collaboration invite',
            onPressed: onCreateInvite,
            icon: const Icon(Icons.ios_share, size: 18),
            color: kTextSecondary,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            tooltip: 'Join collaboration invite',
            onPressed: onJoinInvite,
            icon: const Icon(Icons.link, size: 18),
            color: kTextSecondary,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class _NavBarDropdown extends StatelessWidget {
  const _NavBarDropdown({required this.label, required this.items});

  final String label;
  final List<_NavBarMenuItem> items;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_NavBarMenuItem>(
      onSelected: (item) => item.onTap?.call(),
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: kBorder),
      ),
      color: const Color(0xFF22262E),
      itemBuilder: (context) => items
          .map(
            (item) => PopupMenuItem<_NavBarMenuItem>(
              value: item,
              height: 36,
              child: Row(
                children: [
                  Icon(item.icon, size: 16, color: kTextSecondary),
                  const SizedBox(width: 8),
                  Text(
                    item.label,
                    style: const TextStyle(color: kTextPrimary, fontSize: 13),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: kTextSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.expand_more, size: 16, color: kTextMuted),
          ],
        ),
      ),
    );
  }
}

class _NavBarMenuItem {
  const _NavBarMenuItem({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
}
