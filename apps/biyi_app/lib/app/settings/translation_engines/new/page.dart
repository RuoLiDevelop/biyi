import 'package:biyi_advanced_features/biyi_advanced_features.dart';
import 'package:biyi_app/app/router_config.dart';
import 'package:biyi_app/generated/locale_keys.g.dart';
import 'package:biyi_app/services/translate_client/translate_client.dart';
import 'package:biyi_app/states/settings.dart';
import 'package:biyi_app/widgets/customized_app_bar/customized_app_bar.dart';
import 'package:biyi_app/widgets/translation_engine_icon/translation_engine_icon.dart';
import 'package:biyi_app/widgets/translation_engine_name/translation_engine_name.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:influxui/influxui.dart';
import 'package:preference_list/preference_list.dart';
import 'package:provider/provider.dart';
import 'package:shortid/shortid.dart';
import 'package:uni_translate_client/uni_translate_client.dart';

class TranslationEnginesNewOrEditPage extends StatefulWidget {
  const TranslationEnginesNewOrEditPage({
    super.key,
    this.editable = true,
    this.engineType,
    this.engineConfig,
  });

  final bool editable;
  final String? engineType;
  final TranslationEngineConfig? engineConfig;

  @override
  State<TranslationEnginesNewOrEditPage> createState() =>
      _TranslationEnginesNewOrEditPageState();
}

class _TranslationEnginesNewOrEditPageState
    extends State<TranslationEnginesNewOrEditPage> {
  final Map<String, TextEditingController> _textEditingControllerMap = {};

  String? _id;
  String? _type;
  Map<String, dynamic> _option = {};

  List<String> get _engineOptionKeys {
    return kKnownSupportedEngineOptionKeys[_type] ?? [];
  }

  TranslationEngine? get translationEngine {
    if (_type != null) {
      var engineConfig = TranslationEngineConfig(
        id: '',
        type: _type!,
        option: _option,
      );
      if (widget.engineConfig != null && widget.engineConfig?.option == null) {
        engineConfig = TranslationEngineConfig(
          id: '',
          type: _type!,
          option: {},
        );
      }
      return createTranslationEngine(engineConfig)!;
    }
    return null;
  }

  @override
  void initState() {
    if (widget.engineConfig != null) {
      _id = widget.engineConfig?.id;
      _type = widget.engineConfig?.type;
      _option = widget.engineConfig?.option ?? {};

      for (var optionKey in _engineOptionKeys) {
        var textEditingController = TextEditingController(
          text: _option[optionKey] ?? '',
        );
        _textEditingControllerMap[optionKey] = textEditingController;
      }
    } else {
      _id = shortid.generate();
      _type = widget.engineType;
    }

    super.initState();
  }

  void _handleClickOk() {
    final settings = context.read<Settings>();
    if (settings.getTranslationEngine(_id!) != null) {
      settings.updateTranslationEngine(
        _id!,
        type: _type!,
        option: _option,
      );
    } else {
      settings.createTranslationEngine(
        id: _id!,
        type: _type!,
        option: _option,
      );
    }

    (translateClient.adapter as AutoloadTranslateClientAdapter).renew(_id!);

    Navigator.of(context).pop();
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return CustomizedAppBar(
      title: widget.engineConfig != null
          ? TranslationEngineName(widget.engineConfig!)
          : Text(LocaleKeys.app_translation_engines_new_title.tr()),
      actions: [
        if (widget.editable)
          Button(
            label: LocaleKeys.ok.tr(),
            variant: ButtonVariant.subtle,
            onPressed: _handleClickOk,
          ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        PreferenceListSection(
          header: Text(
            LocaleKeys.app_translation_engines_new_engine_type_title.tr(),
          ),
          children: [
            PreferenceListTile(
              leading: _type == null ? null : TranslationEngineIcon(_type!),
              title: _type == null
                  ? Text(LocaleKeys.please_choose.tr())
                  : Text('engine.$_type'.tr()),
              trailing: const PreferenceListTileChevron(),
              onTap: widget.editable
                  ? () async {
                      final newEngineType = await context.push<String?>(
                        PageId.settingsTranslationEngineTypes,
                        extra: {
                          'selectedEngineType': _type,
                        },
                      );
                      if (newEngineType != null) {
                        setState(() {
                          _type = newEngineType;
                        });
                      }
                    }
                  : null,
            ),
          ],
        ),
        if (translationEngine != null)
          PreferenceListSection(
            header: Text(
              LocaleKeys.app_translation_engines_new_support_interface_title
                  .tr(),
            ),
            children: [
              for (var scope in TranslationEngineScope.values)
                PreferenceListTile(
                  padding: const EdgeInsets.only(
                    top: 10,
                    bottom: 10,
                    left: 12,
                    right: 12,
                  ),
                  title: Text(
                    'engine_scope.${scope.name.toLowerCase()}'.tr(),
                  ),
                  subtitle: Text(scope.name),
                  additionalInfo: Container(
                    margin: EdgeInsets.zero,
                    child: Builder(
                      builder: (_) {
                        if (!(translationEngine?.supportedScopes ?? [])
                            .contains(scope)) {
                          return const Icon(
                            FluentIcons.dismiss_circle_20_filled,
                            color: ExtendedColors.red,
                          );
                        }
                        return const Icon(
                          FluentIcons.checkmark_circle_16_filled,
                          color: ExtendedColors.green,
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        if (widget.editable && _type != null)
          PreferenceListSection(
            header: Text(
              LocaleKeys.app_translation_engines_new_option_title.tr(),
            ),
            children: [
              for (var optionKey in _engineOptionKeys)
                PreferenceListTile(
                  title: CupertinoTextField(
                    controller: _textEditingControllerMap[optionKey],
                    placeholder: optionKey,
                    onChanged: (value) {
                      _option[optionKey] = value;
                      setState(() {});
                    },
                  ),
                ),
              if (_engineOptionKeys.isEmpty)
                const PreferenceListTile(
                  title: Text('No options'),
                ),
            ],
          ),
        if (widget.editable && widget.engineConfig != null)
          PreferenceListSection(
            header: const Text(''),
            children: [
              PreferenceListTile(
                title: Center(
                  child: Text(
                    LocaleKeys.delete.tr(),
                    style: const TextStyle(color: ExtendedColors.red),
                  ),
                ),
                onTap: () async {
                  context.read<Settings>().deleteTranslationEngine(_id!);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: _buildBody(context),
    );
  }
}
