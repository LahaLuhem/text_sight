// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'darwin_options.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DarwinOptionsCWProxy {
  DarwinOptions recognitionLevel(RecognitionLevel recognitionLevel);

  DarwinOptions usesLanguageCorrection(bool usesLanguageCorrection);

  DarwinOptions preferredLanguages(Iterable<Locale> preferredLanguages);

  DarwinOptions minimumTextHeight(double minimumTextHeight);

  /// Creates a new instance with the provided field values.
  /// Passing `null` to a nullable field nullifies it, while `null` for a non-nullable field is ignored. To update a single field use `DarwinOptions(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DarwinOptions(...).copyWith(id: 12, name: "My name")
  /// ```
  DarwinOptions call({
    RecognitionLevel recognitionLevel,
    bool usesLanguageCorrection,
    Iterable<Locale> preferredLanguages,
    double minimumTextHeight,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfDarwinOptions.copyWith(...)` or call `instanceOfDarwinOptions.copyWith.fieldName(value)` for a single field.
class _$DarwinOptionsCWProxyImpl implements _$DarwinOptionsCWProxy {
  const _$DarwinOptionsCWProxyImpl(this._value);

  final DarwinOptions _value;

  @override
  DarwinOptions recognitionLevel(RecognitionLevel recognitionLevel) =>
      call(recognitionLevel: recognitionLevel);

  @override
  DarwinOptions usesLanguageCorrection(bool usesLanguageCorrection) =>
      call(usesLanguageCorrection: usesLanguageCorrection);

  @override
  DarwinOptions preferredLanguages(Iterable<Locale> preferredLanguages) =>
      call(preferredLanguages: preferredLanguages);

  @override
  DarwinOptions minimumTextHeight(double minimumTextHeight) =>
      call(minimumTextHeight: minimumTextHeight);

  /// Creates a new instance with the provided field values.
  /// Passing `null` to a nullable field nullifies it, while `null` for a non-nullable field is ignored. To update a single field use `DarwinOptions(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DarwinOptions(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  DarwinOptions call({
    Object? recognitionLevel = const $CopyWithPlaceholder(),
    Object? usesLanguageCorrection = const $CopyWithPlaceholder(),
    Object? preferredLanguages = const $CopyWithPlaceholder(),
    Object? minimumTextHeight = const $CopyWithPlaceholder(),
  }) {
    return DarwinOptions(
      recognitionLevel: recognitionLevel == const $CopyWithPlaceholder() || recognitionLevel == null
          ? _value.recognitionLevel
          // ignore: cast_nullable_to_non_nullable
          : recognitionLevel as RecognitionLevel,
      usesLanguageCorrection:
          usesLanguageCorrection == const $CopyWithPlaceholder() || usesLanguageCorrection == null
          ? _value.usesLanguageCorrection
          // ignore: cast_nullable_to_non_nullable
          : usesLanguageCorrection as bool,
      preferredLanguages:
          preferredLanguages == const $CopyWithPlaceholder() || preferredLanguages == null
          ? _value.preferredLanguages
          // ignore: cast_nullable_to_non_nullable
          : preferredLanguages as Iterable<Locale>,
      minimumTextHeight:
          minimumTextHeight == const $CopyWithPlaceholder() || minimumTextHeight == null
          ? _value.minimumTextHeight
          // ignore: cast_nullable_to_non_nullable
          : minimumTextHeight as double,
    );
  }
}

extension $DarwinOptionsCopyWith on DarwinOptions {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfDarwinOptions.copyWith(...)` or `instanceOfDarwinOptions.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DarwinOptionsCWProxy get copyWith => _$DarwinOptionsCWProxyImpl(this);
}
