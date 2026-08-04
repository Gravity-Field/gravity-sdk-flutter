# 📦 GravitySDK for Flutter

`GravitySDK` — инструмент для интеграции персонализированного контента, отслеживания взаимодействий пользователей и показа кампаний в мобильных Flutter-приложениях. SDK сам загружает и показывает in-app контент (модальное окно, bottom sheet, полноэкранный режим, tooltip), а также поддерживает inline-виджеты и headless-режим для полностью кастомной отрисовки.

## 📚 Оглавление

- [✨ Возможности](#возможности)
- [🚀 Установка](#установка)
- [⚙️ Инициализация](#инициализация)
- [🪵 Логирование](#логирование)
- [🧑 Пользователь и настройки](#пользователь-и-настройки)
- [📄 Отслеживание и события](#отслеживание-и-события)
- [🔔 Обработка колбэков](#обработка-колбэков)
- [🔒 Блокировка показа (presentation lock)](#блокировка-показа-presentation-lock)
- [🧩 Получение контента](#получение-контента)
- [🖼️ Отображение контента](#отображение-контента)
- [🎨 ProductWidgetBuilder — кастомизация продуктов](#productwidgetbuilder--кастомизация-отображения-продуктов)
- [📈 Взаимодействия (engagement)](#взаимодействия-engagement)
- [❗ Обработка ошибок](#обработка-ошибок)

## Возможности

- Инициализация SDK с ключом API и параметрами секции
- Отслеживание просмотров экранов и пользовательских событий с автопоказом in-app кампаний
- Получение контента по селектору, ID кампании или группе
- Автоматический батчинг и дедупликация конкурентных choose-запросов
- Inline-виджеты и tooltip-кампании (`GravityAnchor`)
- Headless-режим: сырые данные кампаний без встроенного UI
- Многошаговые (multi-step) кампании
- Отправка взаимодействий с контентом и продуктами
- Временная блокировка автопоказа in-app контента (presentation lock)

## Установка

Добавь пакет в файл `pubspec.yaml`:

```yaml
dependencies:
  gravity_sdk: ^0.20.0
```

Затем выполни команду:

```bash
flutter pub get
```

И импортируй пакет в своём коде:

```dart
import 'package:gravity_sdk/gravity_sdk.dart';
```

Требуется Dart SDK `^3.10.0`.

Для iOS добавь в `ios/Runner/Info.plist` описание App Tracking Transparency (SDK читает статус трекинга):

```xml
<key>NSUserTrackingUsageDescription</key>
<string>This identifier will be used to deliver personalized ads to you.</string>
```

## Инициализация

Для работы SDK необходимо провести базовую инициализацию, передав параметры `apiKey` и `section`. Их можно найти в личном кабинете.

```dart
await GravitySDK.instance.initialize(
  apiKey: 'api-key',
  section: 'section',
);
```

Полная сигнатура:

```dart
Future<void> initialize({
  required String apiKey,
  required String section,
  ProductWidgetBuilder? productWidgetBuilder,
  GravityEventCallback? gravityEventCallback,
  GravityContentCallback? gravityContentCallback,
  LogLevel logLevel = LogLevel.info,
});
```

- `productWidgetBuilder` — кастомная отрисовка карточек продуктов ([подробнее](#productwidgetbuilder--кастомизация-отображения-продуктов))
- `gravityEventCallback` — колбэк событий SDK и действий пользователя ([подробнее](#обработка-колбэков))
- `gravityContentCallback` — колбэк с сырым контентом кампании для headless-сценариев
- `logLevel` — уровень логирования

## Логирование

```dart
await GravitySDK.instance.initialize(
  apiKey: 'api-key',
  section: 'section',
  logLevel: LogLevel.debug,
);
```

Уровни: `none` (отключено), `error`, `warn`, `info` (по умолчанию), `debug`.

## Пользователь и настройки

```dart
// Ручная идентификация пользователя
GravitySDK.instance.setUser('user-id', 'session-id');

// Сброс пользователя и сессии (например, при logout)
await GravitySDK.instance.resetUser();

// Глобальные настройки
GravitySDK.instance.setOptions(
  options: Options(
    isReturnUserInfo: true,
    isImplicitImpression: true,
  ),
  contentSettings: ContentSettings(
    skusOnly: false,
    fields: ['name', 'price', 'imageUrl'],
  ),
  proxyUrl: 'https://your-proxy.com',
  isFetchContentOnTrack: true,
);

// Статус разрешения на push-уведомления
GravitySDK.instance.setNotificationPermissionStatus(NotificationPermissionStatus.granted);
```

- `proxyUrl` — маршрутизация запросов через прокси
- `isFetchContentOnTrack` — автоматическая загрузка контента после `trackViewNoShow()` / `triggerEventNoShow()` (по умолчанию `true`)
- `NotificationPermissionStatus`: `granted` / `denied` / `unknown`

## Отслеживание и события

Оба метода принимают `BuildContext` — если событие триггерит кампанию, SDK сам покажет её контент.

```dart
await GravitySDK.instance.trackView(
  context: context,
  pageContext: PageContext(
    type: ContextType.homepage,
    data: [],
    location: 'app://homepage',
  ),
);

await GravitySDK.instance.triggerEvent(
  context: context,
  events: [
    AddToCartEvent(value: 99.99, productId: 'sku-123', quantity: 1, currency: 'RUB'),
  ],
  pageContext: PageContext(
    type: ContextType.product,
    data: ['sku-123'],
    location: 'app://product/sku-123',
  ),
);
```

Доступные события (`TriggerEvent`): `AddToCartEvent`, `RemoveFromCartEvent`, `SyncCartEvent`, `PurchaseEvent`, `AddToWishlistEvent`, `SignUpEvent`, `LoginEvent`, `CustomEvent`.

```dart
final purchase = PurchaseEvent(
  uniqueTransactionId: 'ORDER-12345',
  value: 2550.75,
  currency: 'RUB',
  cart: [
    CartItem(productId: 'sku-123', quantity: 1, itemPrice: 100.50),
  ],
);

final custom = CustomEvent(
  type: 'survey-completed-v1',
  name: 'Survey completed',
  customProps: {'surveyId': 'summer-2025', 'rating': '5'},
);
```

## Обработка колбэков

`gravityEventCallback` получает события жизненного цикла контента и действий пользователя (`TrackingEvent`). Большинство — информационные; обязательной обработки на стороне приложения требуют `FollowUrlEvent`, `FollowDeeplinkEvent` и `RequestPushEvent`. `FollowUrlEvent.type` (`FollowUrlType.browser` / `FollowUrlType.webview`) подсказывает, где кампания просит открыть ссылку; если в кампании тип не задан, используется `browser`:

```dart
await GravitySDK.instance.initialize(
  apiKey: 'api-key',
  section: 'section',
  gravityEventCallback: (event) {
    if (event is FollowUrlEvent) {
      if (event.type == FollowUrlType.webview) {
        // открыть event.url во внутреннем webview приложения
      } else {
        launchUrl(Uri.parse(event.url), mode: LaunchMode.externalApplication);
      }
    }
    if (event is FollowDeeplinkEvent) {
      // навигация по диплинку приложения
    }
    if (event is RequestPushEvent) {
      // запрос разрешения на push-уведомления
    }
  },
);
```

Информационные события: `ContentLoadEvent`, `ContentImpressionEvent`, `ContentVisibleImpressionEvent`, `ContentCloseEvent`, `CopyEvent`, `CancelEvent`, `ProductImpressionEvent`.

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

## Получение контента

Контент можно запросить напрямую, без автопоказа:

```dart
final bySelector = await GravitySDK.instance.getContentBySelector(
  selector: 'homepage-recommendations',
  pageContext: pageContext,
  rules: rules, // опционально, List<RtRule>
);

final byCampaign = await GravitySDK.instance.getContentByCampaignId(
  campaignId: 'campaign-id',
  pageContext: pageContext,
);

final byGroup = await GravitySDK.instance.getContentByGroup(
  group: 'homepage-group',
  pageContext: pageContext,
);
```

Ответ — `ContentResponse` с кампаниями (`data`), их вариациями (`payload`) и контентом (`contents`):

```dart
final campaign = bySelector.data.firstOrNull;
final variation = campaign?.payload.firstOrNull;
final content = variation?.contents.firstOrNull;
```

### Батчинг и дедупликация

Конкурентные вызовы `getContentBySelector` / `getContentByCampaignId` автоматически оптимизируются в пределах короткого окна (10 мс):

- полностью идентичные запросы **дедуплицируются** — уходит один сетевой вызов, вызывающие делят один ответ;
- разные запросы с одинаковым окружением (пользователь, `PageContext`, `Options`) **объединяются в один POST /choose** с несколькими элементами `data[]`.

Это прозрачно для вызывающего кода и не требует настройки. `getContentByGroup` в батчинге не участвует.

### Пример: фильтрация рекомендаций правилами

```dart
final rules = [
  RtRule(
    type: 'filter',
    conditions: [
      RtRuleCondition(
        field: 'category',
        arguments: [RtRuleArgument(action: 'in', value: ['shoes'])],
      ),
    ],
  ),
];
```

### Headless-режим

Для полностью кастомной отрисовки есть методы с сырым JSON и «беззвучные» аналоги трекинга (контент возвращается, но не показывается):

```dart
// модель + сырой JSON
final GravityDataResponse<ContentResponse> details =
    await GravitySDK.instance.getContentBySelectorWithDetails(
  selector: 'homepage-banner',
  pageContext: pageContext,
);

// трекинг без показа: null, если кампания не сработала
final GravityDataResponse<ContentResponse>? triggered =
    await GravitySDK.instance.trackViewNoShow(pageContext: pageContext);

final GravityDataResponse<ContentResponse>? byEvent =
    await GravitySDK.instance.triggerEventNoShow(
  events: [event],
  pageContext: pageContext,
);
```

`trackViewNoShow` / `triggerEventNoShow` дополнительно вызывают `gravityContentCallback` и подчиняются флагу `isFetchContentOnTrack`.

## Отображение контента

In-app контент (модальное окно, bottom sheet, полноэкранный режим, tooltip) SDK показывает **автоматически** из `trackView` / `triggerEvent` — формат задаётся настройками кампании на стороне Gravity. Многошаговые кампании (переходы между шагами по кнопкам) обрабатываются встроенным рендерером.

In-app формы (например, опрос с оценкой приложения) тоже рендерятся автоматически: выбор оценки, текстовый ввод с ограничениями длины, условная видимость элементов в зависимости от ответов. Кнопка отправки неактивна, пока обязательные поля не заполнены; результат отправляется в Gravity без участия приложения. Отдельной обработки не требуется — кроме `FollowUrlEvent`, если кампания после отправки ведёт на внешнюю ссылку (например, в магазин приложений).

### Inline-виджеты

Встраивание кампании в вёрстку экрана:

```dart
GravityInlineWidget(
  selector: 'homepage-recommendations',
  height: 250,
  pageContext: pageContext,
);

GravityInlineListWidget(
  group: 'homepage-group',
  height: 250,
  pageContext: pageContext,
);
```

`GravityInlineWidget` дополнительно принимает `placeholderId`, `width`, `showLoading`, `loadingWidget`, `backgroundColor`, `onLoaded`, `rules`; `GravityInlineListWidget` — `showLoading`, `loadingWidget`, `showIndicator`, `indicatorActiveColor`, `indicatorInactiveColor`.

### Tooltip-кампании: GravityAnchor

`GravityAnchor` помечает виджет как якорь для tooltip-кампании и сам загружает её контент:

```dart
GravityAnchor(
  selector: 'profile_tooltip',
  pageContext: pageContext,
  builder: (context, onReady) {
    return GravityInlineWidget(
      selector: 'profile_inline',
      height: 120,
      pageContext: pageContext,
      onLoaded: onReady,
    );
  },
);
```

Загрузить якорный контент можно и вручную:

```dart
await GravitySDK.instance.fetchAnchorContent(
  context: context,
  selector: 'profile_tooltip',
  pageContext: pageContext, // опционально
);
```

## ProductWidgetBuilder — кастомизация отображения продуктов

Некоторые кампании содержат продукты (рекомендации, акции). Чтобы карточки товаров вписывались в стиль приложения, передайте свою реализацию `ProductWidgetBuilder` при инициализации; иначе используется `DefaultProductWidgetBuilder`.

```dart
class MyProductWidgetBuilder extends ProductWidgetBuilder {
  @override
  Widget build({
    required BuildContext context,
    required Slot product,
    required CampaignContent content,
    required Campaign campaign,
  }) {
    final item = product.item; // Map<String, dynamic> — атрибуты товара из фида
    final imageUrl = item['imageUrl'] as String?;

    return GestureDetector(
      onTap: () {
        GravitySDK.instance.sendProductEngagement(
          ProductClickEngagement(product, content, campaign),
        );
      },
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null) Image.network(imageUrl, height: 160, fit: BoxFit.cover),
            Text(item['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${item['price'] ?? ''}'),
          ],
        ),
      ),
    );
  }
}

await GravitySDK.instance.initialize(
  apiKey: 'api-key',
  section: 'section',
  productWidgetBuilder: MyProductWidgetBuilder(),
);
```

## Взаимодействия (engagement)

При кастомной отрисовке контента отправляйте взаимодействия вручную:

```dart
// контент
GravitySDK.instance.sendContentEngagement(ContentImpressionEngagement(content, campaign));
GravitySDK.instance.sendContentEngagement(ContentVisibleImpressionEngagement(content, campaign));
GravitySDK.instance.sendContentEngagement(ContentCloseEngagement(content, campaign));

// продукты
GravitySDK.instance.sendProductEngagement(ProductClickEngagement(slot, content, campaign));
GravitySDK.instance.sendProductEngagement(ProductVisibleImpressionEngagement(slot, content, campaign));
```

## Обработка ошибок

Перед вызовами SDK необходимо убедиться, что он инициализирован. В противном случае будет выброшено исключение:

```
GravitySDK is not initialized. Call initialize() first.
```

Сетевые ошибки `getContentBy*` пробрасываются вызывающему коду (`DioException`); `trackView` / `triggerEvent` и inline-виджеты обрабатывают свои ошибки самостоятельно и не роняют приложение.
