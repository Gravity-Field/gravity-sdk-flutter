// abstract class TrackingEvent {
//   final Campaign campaign;
//
//   const TrackingEvent({required this.campaign});
// }
//
// // Общие события
//
// class LoadEvent extends TrackingEvent {
//
//   const LoadEvent({
//     required super.campaign,
//   });
// }
//
// class ImpressionEvent extends TrackingEvent {
//   final Content content;
//
//   const ImpressionEvent({
//     required super.campaign,
//     required this.content,
//   });
// }
//
// class VisibleImpressionEvent extends TrackingEvent {
//   final Content content;
//
//   const VisibleImpressionEvent({
//     required super.campaign,
//     required this.content,
//   });
// }
//
// class CloseEvent extends TrackingEvent {
//   final Content content;
//   final String source;
//
//   const CloseEvent({
//     required super.campaign,
//     required this.content,
//     required this.source,
//   });
// }
//
// class CopyEvent extends TrackingEvent {
//   final Content content;
//   final String copiedValue;
//
//   const CopyEvent({
//     required super.campaign,
//     required this.content,
//     required this.copiedValue,
//   });
// }
//
// class CancelEvent extends TrackingEvent {
//   final Content content;
//
//   const CancelEvent({
//     required super.campaign,
//     required this.content,
//   });
// }
//
// class SubmitEvent extends TrackingEvent {
//   final Content content;
//   final Map<String, dynamic> formData;
//
//   const SubmitEvent({
//     required super.campaign,
//     required this.content,
//     required this.formData,
//   });
// }
//
// class NextStepEvent extends TrackingEvent {
//   final Content content;
//   final int step;
//
//   const NextStepEvent({
//     required super.campaign,
//     required this.content,
//     required this.step,
//   });
// }
//
// class FollowUrlEvent extends TrackingEvent {
//   final Content content;
//   final Uri url;
//
//   const FollowUrlEvent({
//     required super.campaign,
//     required this.content,
//     required this.url,
//   });
// }
//
// class FollowDeeplinkEvent extends TrackingEvent {
//   final Content content;
//   final Uri deeplink;
//
//   const FollowDeeplinkEvent({
//     required super.campaign,
//     required this.content,
//     required this.deeplink,
//   });
// }
//
// class RequestPushEvent extends TrackingEvent {
//   final Content content;
//
//   const RequestPushEvent({
//     required super.campaign,
//     required this.content,
//   });
// }
//
// class RequestTrackingEvent extends TrackingEvent {
//   final Content content;
//
//   const RequestTrackingEvent({
//     required super.campaign,
//     required this.content,
//   });
// }
//
// // товарные
//
// class ProductImpressionEvent extends TrackingEvent {
//   final Slot slot;
//   final Content content;
//
//   const ProductImpressionEvent({
//     required super.campaign,
//     required this.slot,
//     required this.content,
//   });
// }
//
// class ProductClickEvent extends TrackingEvent {
//   final Slot slot;
//   final Content content;
//
//   const ProductClickEvent({
//     required super.campaign,
//     required this.slot,
//     required this.content
//   });
// }
//
// class AddToCartEvent extends TrackingEvent {
//   final Slot slot;
//   final Content content;
//
//   const AddToCartEvent({
//     required super.campaign,
//     required this.slot,
//     required this.content
//   });
// }
//
// class RemoveFromCartEvent extends TrackingEvent {
//   final Slot slot;
//   final Content content;
//
//   const RemoveFromCartEvent({
//     required super.campaign,
//     required this.slot,
//     required this.content,
//   });
// }
//
// class AddToFavoritesEvent extends TrackingEvent {
//   final Slot slot;
//   final Content content;
//
//   const AddToFavoritesEvent({
//     required super.campaign,
//     required this.slot,
//     required this.content,
//   });
// }