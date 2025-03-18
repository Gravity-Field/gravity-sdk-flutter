enum DeliveryMethod {
  snackBar,
  modal,
  bottomSheet,
  fullScreen,
  inline,
  unknown;

  static DeliveryMethod fromString(String value) {
    switch (value) {
      case 'snackBar':
        return DeliveryMethod.snackBar;
      case 'modal':
        return DeliveryMethod.modal;
      case 'bottomSheet':
        return DeliveryMethod.bottomSheet;
      case 'fullScreen':
        return DeliveryMethod.fullScreen;
      case 'inline':
        return DeliveryMethod.inline;
      default:
        return DeliveryMethod.unknown;
    }
  }
}