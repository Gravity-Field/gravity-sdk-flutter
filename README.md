# 📦 GravitySDK for Flutter

`GravitySDK` — это мощный инструмент для интеграции персонализированного контента, отслеживания взаимодействия пользователей и отображения кампаний в мобильных Flutter-приложениях. Он позволяет получать контент по шаблонам, отслеживать события и отображать контент в различных форматах (модальное окно, полноэкранный режим, bottom sheet).

## 📚 Оглавление

- [✨ Возможности](#возможности)
- [🚀 Установка](#установка)
- [⚙️ Инициализация](#инициализация)
- [🔧 Дополнительные параметры initialize](#дополнительные-параметры-initialize)
- [🎨 ProductWidgetBuilder — кастомизация продуктов](#productwidgetbuilder--кастомизация-отображения-продуктов)
- [🧑 Пользователь и настройки](#пользователь-и-настройки)
- [📄 Отслеживание и события](#отслеживание-и-события)
- [🔒 Блокировка показа (presentation lock)](#блокировка-показа-presentation-lock)
- [📈 Взаимодействие](#взаимодействие)
- [🧩 Получение контента](#получение-контента)
- [🖼️ Отображение контента](#отображение-контента)
- [❗ Обработка ошибок](#обработка-ошибок)

## Возможности

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
- Временная блокировка автопоказа in-app контента (presentation lock)

## Установка

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

## Инициализация

Для работы SDK необходимо провести базовую инициализацию, передав параметры `apiKey` и `section`. Их можно найти в личном кабинете.

```dart
await GravitySDK.instance.initialize(
  apiKey: 'api-key',
  section: 'section',
);
```

## Дополнительные параметры initialize

```dart
Future<void> initialize({
  required String apiKey,
  required String section,
  ProductWidgetBuilder? productWidgetBuilder,
  GravityEventCallback? gravityEventCallback,
  bool useAdvertisingId = false,
});
```

- `productWidgetBuilder` — кастомная отрисовка карточек продуктов
- `gravityEventCallback` — колбэк, вызываемый при трекинге событий
- `useAdvertisingId` — использовать рекламный идентификатор устройства

## ProductWidgetBuilder — кастомизация отображения продуктов

ProductWidgetBuilder — это интерфейс, предназначенный для кастомной отрисовки карточек продуктов в рамках кампаний. Он предоставляет гибкость, позволяя разработчику контролировать внешний вид товаров, интегрированных в кампанию, чтобы они соответствовали стилю приложения.

**Зачем это нужно?**

Некоторые кампании, возвращаемые SDK, содержат продукты (например, рекомендованные товары, акции, предложения). Чтобы эти карточки визуально вписывались в интерфейс приложения, SDK предоставляет возможность передать свою реализацию ProductWidgetBuilder.

Если не указать productWidgetBuilder, будет использоваться реализация по умолчанию: DefaultProductWidgetBuilder.

📦 Пример использования

```dart
class MyCustomProductWidgetBuilder extends ProductWidgetBuilder {
  @override
  Widget build(Slot slot) {
    final item = slot.item;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                item.imageUrl!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.isNew == 'true')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      '🔥 Новинка',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
                Text(
                  item.name,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  '${item.price}',
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
                if (item.oldPrice != null)
                  Text(
                    '${item.oldPrice}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                SizedBox(height: 8),
                if (item.inStock != null)
                  Text(
                    item.inStock! ? 'В наличии' : 'Нет в наличии',
                    style: TextStyle(
                      fontSize: 12,
                      color: item.inStock! ? Colors.green : Colors.red,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

Передача кастомного builder’а при инициализации SDK:

```dart
await GravitySDK.instance.initialize(
  apiKey: 'your-api-key',
  section: 'your-section-id',
  productWidgetBuilder: MyCustomProductWidgetBuilder(),
);
```

## Пользователь и настройки

```dart
GravitySDK.instance.setUser('user-id', 'session-id');

GravitySDK.instance.setOptions(
  options: Options(...),
  contentSettings: ContentSettings(...),
  proxyUrl: 'https://your-proxy.com',
);
```

## Отслеживание и события

```dart
await GravitySDK.instance.trackView(
  pageContext: PageContext(...),
);

await GravitySDK.instance.triggerEvent(
  events: [TriggerEvent(...)],
  pageContext: PageContext(...),
);
```

## Блокировка показа (presentation lock)

Приложение может временно запретить автопоказ in-app кампаний Gravity — например, пока показывает собственный диалог, онбординг или paywall:

```dart
GravitySDK.instance.lockPresentation();

// ... приоритетный UI приложения ...

GravitySDK.instance.unlockPresentation();
```

Подписка на изменение состояния блокировки:

```dart
GravitySDK.instance.setPresentationLockListener((locked) {
  debugPrint('Gravity presentation locked: $locked');
});

// отписка
GravitySDK.instance.setPresentationLockListener(null);
```

Семантика (совпадает с iOS/Android SDK):

- пока блокировка активна, `trackView` и `triggerEvent` загружают и резолвят контент, но не показывают in-app UI — в лог пишется `Presentation is locked, skipped content for campaign <campaignId>`;
- так как контент под блокировкой всё равно загружается (уходят запрос choose и события contentLoaded), серверные лимиты показов кампании (frequency cap, one-shot) расходуются даже без показа;
- блокируется только автопоказ: `fetchAnchorContent` (в том числе автозагрузка через `GravityAnchor`), step-навигация уже открытого контента, `trackViewNoShow`/`triggerEventNoShow` и `getContentBy*` под блокировку не попадают;
- уже открытый in-app контент при `lockPresentation()` не закрывается;
- после `unlockPresentation()` показы снова разрешены для следующих `trackView`/`triggerEvent`; кампания, пропущенная во время блокировки, ретроактивно не показывается;
- повторные вызовы lock/unlock безопасны; listener вызывается при каждом вызове;
- состояние блокировки живёт в памяти и сбрасывается при перезапуске приложения — если оно должно переживать рестарт, сохраняйте и восстанавливайте его на стороне приложения (пример — `PresentationLockPrefs` в `example/`);
- текущее состояние доступно через `GravitySDK.instance.isPresentationLocked`.

## Взаимодействие

```dart
GravitySDK.instance.sendContentEngagement(ContentImpressionEngagement(...));
GravitySDK.instance.sendProductEngagement(ProductClickEngagement(...));
```

## Получение контента

```dart
final content = await GravitySDK.instance.getContent('template-id');
```

## Отображение контента

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

## Обработка ошибок

Перед вызовами SDK необходимо убедиться, что он инициализирован. В противном случае будет выброшено исключение:

```
GravitySDK is not initialized. Call initialize() first.
```

