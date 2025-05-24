# 📦 GravitySDK for Flutter

`GravitySDK` — это мощный инструмент для интеграции персонализированного контента, отслеживания взаимодействия пользователей и отображения кампаний в мобильных Flutter-приложениях. Он позволяет получать контент по шаблонам, отслеживать события и отображать контент в различных форматах (модальное окно, полноэкранный режим, bottom sheet).

## ✨ Возможности

- Инициализация SDK с ключом API и параметрами секции
- Настройка контента и прокси
- Отслеживание посещений страниц и пользовательских событий
- Получение контента по шаблону
- Отображение контента в:
    - Модальном окне
    - Bottom sheet
    - Полноэкранном режиме
    - Bottom sheet с рядом товаров
- Отправка взаимодействий с контентом и продуктами

## 🚀 Установка

Добавь пакет в файл `pubspec.yaml`:

```yaml
dependencies:
  gravity_sdk: ^0.8.0
```

Затем выполни команду:

```bash
flutter pub get
```

И импортируй пакет в своём коде:

```dart
import 'package:gravity_sdk/gravity_sdk.dart';
```

## ⚙️ Инициализация

```dart
await GravitySDK.instance.initialize(
apiKey: 'your-api-key',
section: 'your-section-id',
productWidgetBuilder: CustomProductWidgetBuilder(), // необязательно
gravityEventCallback: (event) {
// обработка событий
},
useAdvertisingId: true, // если нужен рекламный ID
);
```

## 🧑 Пользователь и настройки

```dart
GravitySDK.instance.setUser('user-id', 'session-id');

GravitySDK.instance.setOptions(
options: Options(...),
contentSettings: ContentSettings(...),
proxyUrl: 'https://your-proxy.com', // если используется прокси
);
```

## 📄 Отслеживание и события

```dart
await GravitySDK.instance.trackView(
pageContext: PageContext(...),
);

await GravitySDK.instance.triggerEvent(
events: [TriggerEvent(...)],
pageContext: PageContext(...),
);
```

## 📈 Взаимодействие

```dart
GravitySDK.instance.sendContentEngagement(ContentImpressionEngagement(...));
GravitySDK.instance.sendProductEngagement(ProductClickEngagement(...));
```

## 🧩 Получение контента

```dart
final content = await GravitySDK.instance.getContent('template-id');
```

## 🖼️ Отображение контента

### Модальное окно

```dart
GravitySDK.instance.showModalContent(context, content);
```

### Bottom Sheet

```dart
GravitySDK.instance.showBottomSheetContent(context, content);
```

### Bottom Sheet: Ряд товаров

```dart
GravitySDK.instance.showBottomSheetProductsRow(context, content);
```

### Полноэкранное окно

```dart
GravitySDK.instance.showFullScreenContent(context, content);
```

## ❗ Обработка ошибок

Перед вызовами SDK необходимо убедиться, что он инициализирован. В противном случае будет выброшено исключение:

```
GravitySDK is not initialized. Call initialize() first.
```

## 📌 Требования

- Flutter 3.0+
- Dart 2.17+


