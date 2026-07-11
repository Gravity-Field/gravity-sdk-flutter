# Presentation Lock для in-app показа — дизайн

Дата: 2026-07-03

## Цель

Паритет с iOS/Android SDK: публичный presentation lock, которым хостовое
приложение временно запрещает автопоказ in-app кампаний Gravity (например, пока
показывает свой диалог, онбординг или paywall).

Референсы семантики (проверено по исходникам нативных SDK):

- iOS `GravitySDK.swift`: `lockPresentation()` / `unlockPresentation()` /
  `setPresentationLockListener(_:)`; проверка в `handleCampaignIdsResponse`
  после delay и валидации view controller, перед `showBackendContent`.
- Android `GravitySDK.kt`: то же; `@Volatile private var isPresentationLocked`;
  listener вызывается при **каждом** вызове lock/unlock (не только при смене
  состояния).
- Строки логов (совпадают в обоих SDK):
  - `Presentation lock called, presentation is now locked`
  - `Presentation unlock called, presentation is now unlocked`
  - `Presentation is locked, skipped content for campaign <campaignId>`

## API (lib/src/gravity_sdk.dart)

```dart
bool _isPresentationLocked = false;
void Function(bool locked)? _presentationLockListener;

bool get isPresentationLocked;                 // read-only getter
void lockPresentation();
void unlockPresentation();
void setPresentationLockListener(void Function(bool locked)? listener);
```

Решения:

1. **Без требования initialize()**. Android не проверяет инициализацию; для
   Flutter требование ломало бы сценарий «залочить до/во время async
   initialize». Ограничение: `talker` бросает `StateError` до `initialize()`,
   поэтому логирование в lock/unlock защищено проверкой
   `LoggerManager.instance.isInitialized`.
2. **Listener вызывается при каждом вызове** lock/unlock, включая повторные
   (точный паритет с Android/iOS). Вызов синхронный: Dart однопоточный,
   аналог `MainActor.run` из iOS не нужен.
3. **Идемпотентность**: повторный lock/unlock безопасен — состояние просто
   перезаписывается тем же значением.
4. Публичный read-only геттер `isPresentationLocked` — идиоматично для Dart,
   семантику не меняет (в нативных SDK поле приватное, но состояние можно
   наблюдать через listener).

## Проверка перед автопоказом

Вариант из задачи «внутри `_showBackendContent`» отклонён: он задел бы ручные
(`fetchAnchorContent`) и step-навигацию (`openStep` — взаимодействие с уже
открытым контентом, которое lock не должен ломать). Выбран вариант «в
`trackView` и `triggerEvent`», точно как в нативных SDK (только auto-show
flow).

Место проверки — после delay и проверки `context.mounted`, перед
`resolveRootContent`/`_showBackendContent`:

```dart
if (!context.mounted) return;

if (_isPresentationLocked) {
  talker.info('Presentation is locked, skipped content for campaign ${campaignIdObj.campaignId}');
  return;
}
```

Не гейтятся (ручные/headless сценарии, как в нативных SDK):
`fetchAnchorContent`, `openStep`, `trackViewNoShow`, `triggerEventNoShow`,
`getContentBy*`. Уже открытый контент не закрывается — lock влияет только на
новые автопоказы. Пропущенная кампания не показывается ретроактивно после
unlock (следующий trigger/trackView отработает как обычно).

## Тесты

`test/gravity_sdk_presentation_lock_test.dart` — контракт публичного API:
lock/unlock, идемпотентность, listener (каждый вызов, замена, сброс null),
безопасность вызова до initialize().
`test/gravity_sdk_presentation_lock_default_test.dart` — отдельный файл
(свежий изолят) для проверки дефолта unlocked: в основном файле setUp
сбрасывает синглтон, и такой тест был бы вакуумным. Полный flow
trackView→skip не покрывается юнит-тестами: `GravityRepo` — жёсткий синглтон
на dio без DI, gate — две идентичные трёхстрочные проверки; осознанный
descope до появления DI-шва в сетевом слое.

## Документация

README: новый раздел «Блокировка показа (presentation lock)» + пункт в
оглавлении и в «Возможности»: примеры lock/unlock и listener, явное описание
семантики (контент грузится, но не показывается; открытый контент не
закрывается; без ретроактивного показа). CHANGELOG/pubspec/version.dart не
трогаем — обновляются отдельным релизным коммитом «Version X».
