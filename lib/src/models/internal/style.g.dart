// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'style.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Style _$StyleFromJson(Map<String, dynamic> json) => Style(
  backgroundColor: ParseUtils.parseColor(json['backgroundColor']),
  backgroundImage: json['backgroundImage'] as String?,
  pressColor: ParseUtils.parseColor(json['pressColor']),
  outlineColor: ParseUtils.parseColor(json['outlineColor']),
  cornerRadius: ParseUtils.parseDimension(json['cornerRadius']),
  size: json['size'] == null
      ? null
      : GravitySize.fromJson(json['size'] as Map<String, dynamic>),
  margin: json['margin'] == null
      ? null
      : GravityMargin.fromJson(json['margin'] as Map<String, dynamic>),
  padding: json['padding'] == null
      ? null
      : GravityPadding.fromJson(json['padding'] as Map<String, dynamic>),
  fontSize: ParseUtils.parseFontSize(json['fontSize']),
  fontWeight: ParseUtils.parseFontWeight(json['fontWeight']),
  textColor: ParseUtils.parseColor(json['textColor']),
  textStyle: json['textStyle'] == null
      ? null
      : GravityTextStyle.fromJson(json['textStyle'] as Map<String, dynamic>),
  fit: ParseUtils.parseBoxFit(json['fit']),
  contentAlignment: $enumDecodeNullable(
    _$GravityContentAlignmentEnumMap,
    json['contentAlignment'],
  ),
  layoutWidth: $enumDecodeNullable(
    _$GravityLayoutWidthEnumMap,
    json['layoutWidth'],
  ),
  positioned: json['positioned'] == null
      ? null
      : GravityPositioned.fromJson(json['positioned'] as Map<String, dynamic>),
  gridSettings: json['gridSettings'] == null
      ? null
      : GridSettings.fromJson(json['gridSettings'] as Map<String, dynamic>),
  productContainerType: $enumDecodeNullable(
    _$ProductContainerTypeEnumMap,
    json['productContainerType'],
  ),
);

const _$GravityContentAlignmentEnumMap = {
  GravityContentAlignment.start: 'start',
  GravityContentAlignment.center: 'center',
  GravityContentAlignment.end: 'end',
};

const _$GravityLayoutWidthEnumMap = {
  GravityLayoutWidth.matchParent: 'match_parent',
  GravityLayoutWidth.wrapContent: 'wrap_content',
};

const _$ProductContainerTypeEnumMap = {
  ProductContainerType.row: 'row',
  ProductContainerType.grid: 'grid',
};

GravitySize _$GravitySizeFromJson(Map<String, dynamic> json) => GravitySize(
  width: ParseUtils.parseDimension(json['width']),
  height: ParseUtils.parseDimension(json['height']),
);

GravityMargin _$GravityMarginFromJson(Map<String, dynamic> json) =>
    GravityMargin(
      left: ParseUtils.parseNonNullableDimension(json['left']),
      right: ParseUtils.parseNonNullableDimension(json['right']),
      top: ParseUtils.parseNonNullableDimension(json['top']),
      bottom: ParseUtils.parseNonNullableDimension(json['bottom']),
    );

GravityPadding _$GravityPaddingFromJson(Map<String, dynamic> json) =>
    GravityPadding(
      left: ParseUtils.parseNonNullableDimension(json['left']),
      right: ParseUtils.parseNonNullableDimension(json['right']),
      top: ParseUtils.parseNonNullableDimension(json['top']),
      bottom: ParseUtils.parseNonNullableDimension(json['bottom']),
    );

GravityPositioned _$GravityPositionedFromJson(Map<String, dynamic> json) =>
    GravityPositioned(
      left: ParseUtils.parseDimension(json['left']),
      right: ParseUtils.parseDimension(json['right']),
      top: ParseUtils.parseDimension(json['top']),
      bottom: ParseUtils.parseDimension(json['bottom']),
    );

GravityTextStyle _$GravityTextStyleFromJson(Map<String, dynamic> json) =>
    GravityTextStyle(
      fontSize: ParseUtils.parseNonNullableFontSize(json['fontSize']),
      fontWeight: ParseUtils.parseNonNullableFontWeight(json['fontWeight']),
      color: ParseUtils.parseNonNullableColorBlack(json['color']),
    );

GridSettings _$GridSettingsFromJson(Map<String, dynamic> json) => GridSettings(
  columns: ParseUtils.parseDimension(json['columns']),
  horizontalSpacing: ParseUtils.parseDimension(json['horizontalSpacing']),
  verticalSpacing: ParseUtils.parseDimension(json['verticalSpacing']),
);
