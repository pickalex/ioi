// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'presence_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PresenceModel)
const presenceModelProvider = PresenceModelProvider._();

final class PresenceModelProvider
    extends $NotifierProvider<PresenceModel, List<Friend>> {
  const PresenceModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'presenceModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$presenceModelHash();

  @$internal
  @override
  PresenceModel create() => PresenceModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Friend> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Friend>>(value),
    );
  }
}

String _$presenceModelHash() => r'ce569808c0d64c6c110e59bf547e264dfeb74026';

abstract class _$PresenceModel extends $Notifier<List<Friend>> {
  List<Friend> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<List<Friend>, List<Friend>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<Friend>, List<Friend>>,
              List<Friend>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
