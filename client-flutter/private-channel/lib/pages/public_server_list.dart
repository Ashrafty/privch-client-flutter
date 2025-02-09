import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:privch/config.dart' as config;
import 'package:privch/providers/server_provider.dart';
import 'package:privch/widgets/dialog_confirm.dart';
import 'package:provider/provider.dart';
import 'package:xinlake_platform/xinlake_platform.dart' as xp;
import 'package:xinlake_qrcode/xinlake_qrcode.dart' as xq;
import 'package:xinlake_tunnel/xinlake_tunnel.dart' as xt;

class PublicShadowsocksList extends StatefulWidget {
  const PublicShadowsocksList({
    required this.actionBarColor,
    super.key,
  });

  final Color actionBarColor;

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<PublicShadowsocksList> {
  final _sortMenuController = MenuController();

  late AppLocalizations _appLocales;
  late ThemeData _themeData;
  late double _spacing;

  void _onItemDetail(
    BuildContext context,
    xt.Shadowsocks shadowsocks,
  ) async {
    final serverProvider = context.read<ServerTabProvider>();
    final pubServerProvider = context.read<PublicServerProvider>();

    // navigate to shadowsocks details
    final ss = await Navigator.of(context).pushNamed<xt.Shadowsocks>(
      config.AppRoute.shadowsocks,
      arguments: (shadowsocks, false),
    );

    if (ss != null) {
      if (shadowsocks == serverProvider.selected) {
        await xt.stopTunnel();
        // update selection
        await serverProvider.setSelected(ServerGroup.public, ss);
      }

      await pubServerProvider.delete(shadowsocks);
      await pubServerProvider.put(ss);
    }
  }

  Future<void> _onItemRemove(
    BuildContext context,
    PublicServerProvider serverProvider,
    xt.Shadowsocks shadowsocks,
  ) async {
    // remove the server
    await serverProvider.delete(shadowsocks);

    // cancel remove
    if (context.mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text("${shadowsocks.name} ${_appLocales.removed}"),
          action: SnackBarAction(
            label: _appLocales.undo,
            onPressed: () async {
              await serverProvider.put(shadowsocks);
            },
          ),
        ),
      );
    }
  }

  Future<void> _importFromScreenshot() async {
    final codeList = await xq.readScreen();
    if (codeList == null || codeList.isEmpty) {
      return;
    }

    final ssList = <xt.Shadowsocks>[];
    for (final qrcode in codeList) {
      final shadowsocks = xt.Shadowsocks.parserQrCode(qrcode);
      if (shadowsocks != null) {
        ssList.add(shadowsocks);
      }
    }

    if (mounted) {
      final serverProvider = context.read<PublicServerProvider>();
      if (ssList.isNotEmpty) {
        await serverProvider.putAll(ssList);
      }

      // set recent adding method
      await serverProvider.setImportMethod(ServerAddingMethod.scanScreen);
    }
  }

  Future<void> _importFromCamera() async {
    final qrcode = await xq.fromCamera(
      prefix: "ss://",
      playBeep: true,
    );
    if (qrcode == null) {
      return;
    }

    if (mounted) {
      final serverProvider = context.read<PublicServerProvider>();
      final shadowsocks = xt.Shadowsocks.parserQrCode(qrcode);
      if (shadowsocks != null) {
        await context.read<PublicServerProvider>().put(
          shadowsocks,
          onOverWrite: () {
            // snackbar
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
                content: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("${shadowsocks.name} updated"),
                  ],
                ),
              ),
            );

            return true;
          },
        );
      }

      // set recent adding method
      await serverProvider.setImportMethod(ServerAddingMethod.scanQrcode);
    }
  }

  Future<void> _importFromImage() async {
    final images = await xp.pickFile(
      multiSelection: true,
      mimeTypes: "image/*",
      cacheDir: xp.AndroidAppDir.externalFiles,
      typesDescription: "Images",
    );
    if (images == null || images.isEmpty) {
      return;
    }

    final codeList = await xq.readImage(images.map((file) => file.path!).toList());
    if (codeList == null || codeList.isEmpty) {
      return;
    }

    final ssList = <xt.Shadowsocks>[];
    for (final qrcode in codeList) {
      final shadowsocks = xt.Shadowsocks.parserQrCode(qrcode);
      if (shadowsocks != null) {
        ssList.add(shadowsocks);
      }
    }

    if (mounted) {
      final serverProvider = context.read<PublicServerProvider>();
      if (ssList.isNotEmpty) {
        await serverProvider.putAll(ssList);
      }

      // set recent adding method
      await serverProvider.setImportMethod(ServerAddingMethod.importImage);
    }
  }

  Future<void> _createServer() async {
    final shadowsocks = await Navigator.of(context).pushNamed<xt.Shadowsocks>(
      config.AppRoute.shadowsocks,
      arguments: (
        xt.Shadowsocks(
          name: config.dateFormatShort.format(DateTime.now()),
          address: "",
          port: 0,
          password: "",
          encryption: xt.Shadowsocks.encryptDefault,
        ),
        true,
      ),
    );

    if (mounted) {
      final serverProvider = context.read<PublicServerProvider>();
      if (shadowsocks != null &&
          xt.Shadowsocks.validate(
            address: shadowsocks.address,
            port: shadowsocks.port,
            encryption: shadowsocks.encryption,
            password: shadowsocks.password,
          )) {
        serverProvider.put(shadowsocks);
      }

      await serverProvider.setImportMethod(ServerAddingMethod.create);
    }
  }

  Widget _actionBar({EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding,
      color: widget.actionBarColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // add server
          MenuAnchor(
            builder: (context, controller, child) {
              return IconButton(
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
                icon: const Icon(Icons.add_circle),
              );
            },
            menuChildren: [
              Platform.isWindows
                  ? MenuItemButton(
                      onPressed: () async => await _importFromScreenshot(),
                      child: Text(_appLocales.importFromScreenshot),
                    )
                  : MenuItemButton(
                      onPressed: () async => await _importFromCamera(),
                      child: Text(_appLocales.importFromScanner),
                    ),
              MenuItemButton(
                onPressed: () async => await _importFromImage(),
                child: Text(_appLocales.importFromImage),
              ),
              MenuItemButton(
                onPressed: () async => await _createServer(),
                child: Text(_appLocales.createServer),
              ),
            ],
          ),

          // recent server adding method
          Consumer<PublicServerProvider>(
            builder: (context, serverProvider, child) {
              return (serverProvider.importMethod != null)
                  ? IconButton(
                      onPressed: switch (serverProvider.importMethod!) {
                        ServerAddingMethod.scanScreen => () async => await _importFromScreenshot(),
                        ServerAddingMethod.scanQrcode => () async => await _importFromCamera(),
                        ServerAddingMethod.importImage => () async => await _importFromImage(),
                        ServerAddingMethod.create => () async => await _createServer(),
                      },
                      icon: Icon(
                        switch (serverProvider.importMethod!) {
                          ServerAddingMethod.scanScreen => Icons.screenshot_monitor,
                          ServerAddingMethod.scanQrcode => Icons.qr_code_scanner,
                          ServerAddingMethod.importImage => Icons.image,
                          ServerAddingMethod.create => Icons.edit_note,
                        },
                      ),
                    )
                  : const SizedBox();
            },
          ),

          const Spacer(),

          // sort
          MenuAnchor(
            controller: _sortMenuController,
            builder: (context, controller, child) {
              return MaterialButton(
                clipBehavior: Clip.hardEdge,
                padding: EdgeInsets.all(_spacing),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_spacing * 0.5),
                ),
                onPressed: context.select<PublicServerProvider, bool>(
                  (serverProvider) => serverProvider.serverEmpty,
                )
                    ? null
                    : () {
                        if (controller.isOpen) {
                          controller.close();
                        } else {
                          controller.open();
                        }
                      },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.sort),
                    SizedBox(width: _spacing),
                    // selected sort mode
                    Text(
                      _appLocales.sortBy(
                        switch (context.select<PublicServerProvider, ServerSortMode>(
                          (serverProvider) => serverProvider.sortMode,
                        )) {
                          ServerSortMode.name => "name",
                          ServerSortMode.updated => "updated",
                          ServerSortMode.encrypt => "encrypt",
                        },
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
            menuChildren: ServerSortMode.values.map(
              (sortMode) {
                return MenuItemButton(
                  onPressed: () {
                    context.read<PublicServerProvider>().setSortMode(sortMode);
                    _sortMenuController.close();
                  },
                  child: Text(
                    _appLocales.sortBy(switch (sortMode) {
                      ServerSortMode.name => "name",
                      ServerSortMode.updated => "updated",
                      ServerSortMode.encrypt => "encrypt",
                    }),
                  ),
                );
              },
            ).toList(),
          ),

          SizedBox(width: _spacing),

          // more
          MenuAnchor(
            builder: (BuildContext context, MenuController controller, Widget? child) {
              return IconButton(
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
                icon: const Icon(Icons.more_vert),
              );
            },
            menuChildren: <Widget>[
              // clear
              Consumer<PublicServerProvider>(
                builder: (context, serverProvider, child) {
                  return MenuItemButton(
                    onPressed: serverProvider.serverEmpty
                        ? null
                        : () async {
                            final confirm = await showConfirm(
                              context: this.context,
                              title: _appLocales.delAllServers,
                              contentMarkdown: _appLocales.delAllServersBody,
                            );
                            if (confirm == true) {
                              await serverProvider.deleteAll();
                            }
                          },
                    child: Text(_appLocales.delAllServers),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _serverList({EdgeInsetsGeometry? padding}) {
    return Consumer<PublicServerProvider>(
      child: _emptyList(),
      builder: (context, serverProvider, child) {
        if (serverProvider.serverEmpty) {
          return Center(
            child: child!,
          );
        }

        // dismiss
        const startToEndThresholds = 0.5;
        const endToStartThresholds = 0.5;
        const bgIconSize = 36.0;
        final bgColor = _themeData.hoverColor;
        final activeDelete = _themeData.colorScheme.error;
        final activeEdit = _themeData.colorScheme.primary;

        // server
        final serverSelColor = _themeData.colorScheme.primaryContainer;
        final serverTitleText = _themeData.textTheme.titleLarge;
        final serverInfoText = _themeData.textTheme.labelMedium?.copyWith(
          color: _themeData.disabledColor,
        );

        // sort
        final ssList = serverProvider.serverList
          ..sort(
            switch (serverProvider.sortMode) {
              ServerSortMode.updated => (ss1, ss2) => -ss1.modified.compareTo(ss2.modified),
              ServerSortMode.name => (ss1, ss2) => ss1.name.compareTo(ss2.name),
              ServerSortMode.encrypt => (ss1, ss2) => ss1.encryption.compareTo(ss2.encryption),
            },
          );

        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          padding: padding ?? EdgeInsets.all(_spacing),
          child: Column(
            children: ssList.map<Widget>((shadowsocks) {
              return Dismissible(
                key: Key(shadowsocks.hashCode.toString()),

                // Dismiss
                dismissThresholds: const {
                  DismissDirection.startToEnd: startToEndThresholds,
                  DismissDirection.endToStart: endToStartThresholds,
                },
                onUpdate: (details) {
                  if (details.direction == DismissDirection.startToEnd) {
                    serverProvider.dismissToDelete = details.progress > startToEndThresholds;
                  } else if (details.direction == DismissDirection.endToStart) {
                    serverProvider.dismissToEdit = details.progress > endToStartThresholds;
                  }
                },
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.startToEnd) {
                    // delete server
                    return true;
                  } else if (direction == DismissDirection.endToStart) {
                    _onItemDetail(context, shadowsocks);
                    return false;
                  }
                  return false;
                },
                onDismissed: (direction) async {
                  await _onItemRemove(context, serverProvider, shadowsocks);
                },

                // Background-left
                background: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: _spacing),
                      child: const Icon(Icons.arrow_forward),
                    ),
                    SizedBox(
                      width: bgIconSize,
                      height: bgIconSize,
                      child: Center(
                        child: Icon(
                          Icons.delete,
                          color: serverProvider.dismissToDelete ? activeDelete : null,
                          size: serverProvider.dismissToDelete ? bgIconSize : null,
                        ),
                      ),
                    ),
                  ],
                ),

                // Background-right
                secondaryBackground: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: bgIconSize,
                      height: bgIconSize,
                      child: Center(
                        child: Icon(
                          Icons.edit,
                          color: serverProvider.dismissToEdit ? activeEdit : null,
                          size: serverProvider.dismissToEdit ? bgIconSize : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: _spacing),
                      child: const Icon(Icons.arrow_back),
                    ),
                  ],
                ),

                // Server
                child: Container(
                  margin: EdgeInsets.only(bottom: _spacing),
                  decoration: BoxDecoration(
                    color: (shadowsocks == context.read<ServerTabProvider>().selected)
                        ? serverSelColor
                        : bgColor,
                    borderRadius: BorderRadius.circular(_spacing),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(_spacing),
                    onTap: () async {
                      await context
                          .read<ServerTabProvider>()
                          .setSelected(ServerGroup.public, shadowsocks);
                    },
                    child: Padding(
                      padding: EdgeInsets.all(_spacing),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            shadowsocks.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: serverTitleText,
                          ),

                          // spacing
                          SizedBox(height: _spacing),

                          Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                shadowsocks.encryption.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: serverInfoText,
                              ),
                              Text(
                                config.dateFormatDay.format(
                                  DateTime.fromMillisecondsSinceEpoch(shadowsocks.modified),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: serverInfoText,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // the content when the list is empty
  Widget _emptyList() {
    final mqSize = MediaQuery.of(context).size;
    final titleText = _themeData.textTheme.headlineMedium;
    final infoText = TextStyle(
      color: _themeData.disabledColor,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          _appLocales.addServer,
          style: titleText,
        ),
        Padding(
          padding: EdgeInsets.only(
            top: _spacing,
            bottom: _spacing * 2,
          ),
          child: Text(
            _appLocales.noServer,
            style: infoText,
          ),
        ),
        IntrinsicWidth(
          stepWidth: mqSize.width / 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            // action buttons
            children: [
              Platform.isWindows
                  ? ElevatedButton(
                      onPressed: () async => await _importFromScreenshot(),
                      child: Text(_appLocales.importFromScreenshot),
                    )
                  : ElevatedButton(
                      onPressed: () async => await _importFromCamera(),
                      child: Text(_appLocales.importFromScanner),
                    ),

              // spacing
              SizedBox(height: _spacing),

              ElevatedButton(
                onPressed: () async => await _importFromImage(),
                child: Text(_appLocales.importFromImage),
              ),

              // spacing
              SizedBox(height: _spacing),

              ElevatedButton(
                onPressed: () async => await _createServer(),
                child: Text(_appLocales.createServer),
              ),
            ],
          ),
        ),

        // foot padding
        SizedBox(height: mqSize.height / 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    _appLocales = AppLocalizations.of(context);
    _themeData = Theme.of(context);
    _spacing = config.getSpacing(context);

    return Column(
      children: [
        _actionBar(
          padding: EdgeInsets.symmetric(
            horizontal: _spacing,
            vertical: _spacing * 0.5,
          ),
        ),
        Expanded(
          child: _serverList(),
        ),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
